(** Exhaustiveness pin for the {b cancel-reason closed list} (R2 on the
    trade-audit track, filed by qc-behavioral on PR #2357).

    {b The claim under test.} Three docstrings —
    [Trade_audit.record_transitions], [Ticket_lifecycle.cancel_reason], and
    [Cancel_handler.portfolio_rejection_reason] — each assert a {e closed} list:
    exactly three reason tokens can ever land in
    [Ticket_lifecycle.cancel_reason]. Two are strategy {e decisions} built by
    [Weinstein_strategy.Entry_ticket_ttl]; the third is the simulator's
    capital-timing {e accident}, [Cancel_handler.portfolio_rejection_reason].
    The distinction is load-bearing: a cancel-age column averaged without
    splitting on the token mixes a policy with a failure
    ([dev/notes/ticket-death-on-cash-2026-08-16.md]).

    {b Why a hand-written list of three literals would pin nothing.} Comparing
    three string constants against three string constants passes forever. So the
    {e reachable} side of the equality below is never written down — it is
    {b derived} by driving the two production producers over an input grid,
    pushing every [CancelEntry] they emit through
    [Trade_audit.record_transitions], and reading back what the audit persisted.
    Only the {e documented} side is written down. Rename a token, delete a
    producer arm, or stop the audit persisting one, and the two sets diverge.

    {b What this does NOT catch — stated plainly.} The grid drives the two
    producer modules that exist today. A {e fourth} producer added in some third
    module would not be reached, and this test would stay green while the
    docstrings went stale. Closing that requires a source-level census of
    [CancelEntry] construction sites, which is a linter's job, not a unit test's
    — filed as R5 on [dev/status/trade-audit.md]. Within the two modules driven
    here the grid is genuinely a sweep (every armed/disarmed combination of both
    [Entry_ticket_ttl] gates, across three position states and three ages), so a
    new arm added to either producer is very likely to be reached. *)

open OUnit2
open Core
open Matchers
module TA = Backtest.Trade_audit
module TL = Backtest.Ticket_lifecycle
module Position = Trading_strategy.Position
module Cancel_handler = Trading_simulation.Cancel_handler
module Entry_ticket_ttl = Weinstein_strategy.Entry_ticket_ttl

(* The documented side of the equality: the closed list exactly as the three
   docstrings name it. [Cancel_handler]'s token is referenced symbolically
   because it is exported; the two [Entry_ticket_ttl] tokens are private to that
   module, so they appear here as literals — which is the point, since the
   reachable side derives them by running the producer. *)
let _documented_cancel_reasons =
  String.Set.of_list
    [
      "entry_ticket_ttl_expired";
      "entry_ticket_requalification_failed";
      Cancel_handler.portfolio_rejection_reason;
    ]

(* Fixtures ---------------------------------------------------------------- *)

let _date d = Date.of_string d
let _placement_date = _date "2024-01-05"
let _target_quantity = 100.0
let _entry_price = 50.0

let _position ~id ~symbol ~state : Position.t =
  {
    id;
    symbol;
    side = Position.Long;
    entry_reasoning = Position.ManualDecision { description = "test fixture" };
    exit_reason = None;
    state;
    last_updated = _placement_date;
    portfolio_lot_ids = [];
  }

let _entering ~id ~symbol ~filled_quantity =
  _position ~id ~symbol
    ~state:
      (Position.Entering
         {
           target_quantity = _target_quantity;
           entry_price = _entry_price;
           filled_quantity;
           created_date = _placement_date;
         })

let _holding ~id ~symbol =
  _position ~id ~symbol
    ~state:
      (Position.Holding
         {
           quantity = _target_quantity;
           entry_price = _entry_price;
           entry_date = _placement_date;
           risk_params =
             {
               stop_loss_price = None;
               take_profit_price = None;
               max_hold_days = None;
             };
         })

let _positions_of positions =
  List.fold positions ~init:String.Map.empty ~f:(fun acc (pos : Position.t) ->
      Map.set acc ~key:pos.id ~data:pos)

let _rejected_trade ~symbol : Trading_base.Types.trade =
  {
    id = symbol ^ "-trade-1";
    order_id = symbol ^ "-order-1";
    symbol;
    side = Trading_base.Types.Buy;
    quantity = _target_quantity;
    price = _entry_price;
    commission = 0.0;
    timestamp = Time_ns_unix.epoch;
  }

(* Trade-audit plumbing ---------------------------------------------------- *)

let _triple : TL.triple_confirmation =
  {
    breakout_volume_multiple = None;
    rs_zero_cross = false;
    in_base_advance_pct = None;
  }

let _lifecycle : TL.t =
  {
    placement_date = _placement_date;
    ticket_age_weeks_at_cancel = None;
    cancel_reason = None;
    ticket_age_weeks_at_fill = None;
    fill_volume = None;
    freshness_basis = TL.Range_top_breakout;
    sized_down_wide_stop = false;
    triple_confirmation = _triple;
  }

(* A minimal placed-ticket entry row. Only [position_id] and [ticket_lifecycle]
   matter to the cancel path; every other field is inert filler. *)
let _base_entry : TA.entry_decision =
  {
    symbol = "AAPL";
    entry_date = _placement_date;
    position_id = "AAPL-wein-1";
    macro_trend = Weinstein_types.Bullish;
    macro_confidence = 0.5;
    macro_indicators = [];
    stage = Weinstein_types.Stage2 { weeks_advancing = 4; late = false };
    ma_direction = Weinstein_types.Rising;
    ma_slope_pct = 0.0;
    rs_trend = None;
    rs_value = None;
    volume_quality = None;
    volume_ratio = None;
    resistance_quality = None;
    support_quality = None;
    sector_name = "Information Technology";
    sector_rating = Screener.Strong;
    cascade_score = 0;
    cascade_grade = Weinstein_types.A;
    cascade_score_components = [];
    cascade_rationale = [];
    side = Trading_base.Types.Long;
    suggested_entry = _entry_price;
    close_at_decision = None;
    ma_value = None;
    local_range_top = None;
    suggested_stop = 0.0;
    installed_stop = 0.0;
    stop_floor_kind = TA.Buffer_fallback;
    split_safe_basis = TA.Flag_off;
    risk_pct = 0.0;
    initial_position_value = 0.0;
    initial_risk_dollars = 0.0;
    ticket_lifecycle = Some _lifecycle;
    alternatives_considered = [];
  }

(* Push one production-built transition through the audit and read back the
   token it persisted. Returns [] for a transition the audit records no reason
   for — so a producer whose output stops reaching [cancel_reason] shrinks the
   reachable set and fails the equality. *)
let _reasons_through_trade_audit (trans : Position.transition) =
  let t = TA.create () in
  TA.record_entry t { _base_entry with position_id = trans.position_id };
  TA.record_transitions t [ trans ];
  List.filter_map (TA.get_audit_records t) ~f:(fun (r : TA.audit_record) ->
      Option.bind r.entry.ticket_lifecycle ~f:(fun (l : TL.t) ->
          l.cancel_reason))

let _reachable_from transitions =
  List.concat_map transitions ~f:_reasons_through_trade_audit
  |> String.Set.of_list

(* Producer 1 — Weinstein_strategy.Entry_ticket_ttl ------------------------- *)

type _ttl_input = {
  positions : Position.t String.Map.t;
  rescreen : bool;
  max_rest_weeks : int;
  qualifies : bool;
  current_date : Date.t;
}

(* Expand [acc] over one grid axis. Keeps the cartesian product flat rather than
   five nested [concat_map]s. *)
let _axis acc values ~set =
  List.concat_map acc ~f:(fun a -> List.map values ~f:(set a))

let _position_grid =
  [
    _positions_of [ _entering ~id:"A-1" ~symbol:"AAPL" ~filled_quantity:0.0 ];
    _positions_of [ _entering ~id:"A-1" ~symbol:"AAPL" ~filled_quantity:40.0 ];
    _positions_of [ _holding ~id:"A-1" ~symbol:"AAPL" ];
  ]

(* [-1] and [0] are the "unbounded" clock readings, [1] and [4] armed ones. *)
let _max_rest_weeks_grid = [ -1; 0; 1; 4 ]

(* Same day as placement, two weeks on, and five months on. *)
let _current_date_grid =
  [ _placement_date; _date "2024-01-19"; _date "2024-06-01" ]

let _ttl_inputs =
  let seed =
    {
      positions = String.Map.empty;
      rescreen = false;
      max_rest_weeks = 0;
      qualifies = true;
      current_date = _placement_date;
    }
  in
  let a =
    _axis [ seed ] _position_grid ~set:(fun i positions -> { i with positions })
  in
  let a =
    _axis a [ true; false ] ~set:(fun i rescreen -> { i with rescreen })
  in
  let a =
    _axis a _max_rest_weeks_grid ~set:(fun i max_rest_weeks ->
        { i with max_rest_weeks })
  in
  let a =
    _axis a [ true; false ] ~set:(fun i qualifies -> { i with qualifies })
  in
  _axis a _current_date_grid ~set:(fun i current_date ->
      { i with current_date })

let _ttl_transitions =
  List.concat_map _ttl_inputs ~f:(fun i ->
      Entry_ticket_ttl.cancellations ~rescreen:i.rescreen
        ~max_rest_weeks:i.max_rest_weeks ~positions:i.positions
        ~still_qualifies:(fun ~symbol:_ ~side:_ -> i.qualifies)
        ~current_date:i.current_date)

(* Producer 2 — Trading_simulation.Cancel_handler --------------------------- *)

let _rejection_transitions =
  let position_grid =
    [
      _positions_of [ _entering ~id:"A-1" ~symbol:"AAPL" ~filled_quantity:0.0 ];
      _positions_of [ _holding ~id:"A-1" ~symbol:"AAPL" ];
      String.Map.empty;
    ]
  in
  let trade_grid =
    [
      []; [ _rejected_trade ~symbol:"AAPL" ]; [ _rejected_trade ~symbol:"MSFT" ];
    ]
  in
  List.concat_map position_grid ~f:(fun positions ->
      List.concat_map trade_grid ~f:(fun rejected_trades ->
          Cancel_handler.transitions_for_rejected_trades
            ~date:(_date "2024-02-02") ~positions ~rejected_trades))

(* Tests ------------------------------------------------------------------- *)

(** The pin. Every token any production producer can drive into
    [Ticket_lifecycle.cancel_reason] is collected by running those producers,
    and the collected set must equal the documented closed list — no extras, and
    none missing. The equality is non-vacuous in both directions: an empty
    reachable set (a grid that stopped driving anything) fails just as loudly as
    a fourth token appearing. *)
let test_reachable_reasons_equal_the_documented_closed_list _ =
  assert_that
    (Set.to_list (_reachable_from (_ttl_transitions @ _rejection_transitions)))
    (equal_to (Set.to_list _documented_cancel_reasons))

(** The partition the docstrings assert, pinned separately: two of the three
    tokens are strategy {e decisions} and the third is a simulator {e accident}.
    Set equality alone would still pass if a token migrated between the two
    modules, which would silently invalidate the decision-vs-accident split
    every cancel-reason analysis groups on. *)
let test_each_producer_contributes_its_documented_tokens _ =
  assert_that
    ( Set.to_list (_reachable_from _ttl_transitions),
      Set.to_list (_reachable_from _rejection_transitions) )
    (equal_to
       ( [ "entry_ticket_requalification_failed"; "entry_ticket_ttl_expired" ],
         [ Cancel_handler.portfolio_rejection_reason ] ))

let suite =
  "cancel reason closed list"
  >::: [
         "reachable cancel reasons equal the documented closed list"
         >:: test_reachable_reasons_equal_the_documented_closed_list;
         "each producer contributes its documented tokens"
         >:: test_each_producer_contributes_its_documented_tokens;
       ]

let () = run_test_tt_main suite
