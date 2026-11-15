(** {!Entry_walk.walk_report} and {!Cascade_trace.shadow_verdict}, driven
    through the real entry walk on daily-bar fixtures whose three names land on
    three different gates (a narrow structural stop, a crash-wide one, none at
    all) under the investor preset's [require_structural_stop].

    Pinned: for every name the walk classified, the shadow built from the report
    says what the walk did (the two cannot disagree); each of the four shadow
    constructors comes out of the real check; asking it consumes no position id;
    the walk's decisions and tickets are the same with and without the report;
    and [long_cash_left_pct] is the long budget less the placed ticket's cost,
    over portfolio value. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
module AR = Audit_recorder
module Position = Trading_strategy.Position

let _current_date = Date.of_string "2024-06-14"

let _bar ~date ~close : Types.Daily_price.t =
  {
    date;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
    active_through = None;
  }

(* Consecutive daily bars ending on [_current_date]. *)
let _daily closes =
  List.mapi closes ~f:(fun i close ->
      _bar
        ~date:(Date.add_days _current_date (i - List.length closes + 1))
        ~close)

let _bar_reader =
  Bar_reader.of_in_memory_bars
    [
      (* A 9.1% correction then 105: a structural stop ~5% under the entry. *)
      ( "NARROW",
        _daily
          [
            100.0;
            104.0;
            108.0;
            110.0;
            106.0;
            102.0;
            100.0;
            101.0;
            103.0;
            104.0;
            105.0;
          ] );
      (* A crash from 200 to 45, then 95: a structural stop half the entry
         away. *)
      ( "WIDE",
        _daily
          [
            100.0;
            150.0;
            200.0;
            130.0;
            80.0;
            45.0;
            55.0;
            65.0;
            75.0;
            85.0;
            90.0;
            95.0;
          ] );
      (* No correction: only the automatic-percentage fallback exists. *)
      ( "RISING",
        _daily [ 95.0; 96.0; 97.0; 98.0; 99.0; 100.0; 101.0; 102.0; 103.0 ] );
      (* A steady decline with no rally: a short on it gets a narrow stop. *)
      ( "FALLING",
        _daily [ 105.0; 104.0; 103.0; 102.0; 101.0; 100.0; 99.0; 97.0; 95.0 ] );
    ]

let _candidate ?(side = Trading_base.Types.Long) ticker :
    Screener.scored_candidate =
  {
    ticker;
    analysis =
      {
        ticker;
        stage =
          {
            stage = Weinstein_types.Stage2 { weeks_advancing = 8; late = false };
            ma_value = 100.0;
            ma_direction = Weinstein_types.Rising;
            ma_slope_pct = 0.01;
            transition = None;
            above_ma_count = 8;
          };
        rs = None;
        volume = None;
        resistance = None;
        support = None;
        breakout_price = None;
        breakdown_price = None;
        local_range_top = None;
        prior_stage = None;
        continuation = None;
        supply = None;
        virgin_readmission = false;
        range_top_freshness = None;
        require_breakout_volume = true;
        current_close = None;
        as_of_date = _current_date;
      };
    sector =
      {
        sector_name = "Test";
        rating = Neutral;
        stage = Weinstein_types.Stage2 { weeks_advancing = 8; late = false };
      };
    side;
    grade = Weinstein_types.B;
    score = 60;
    suggested_entry = 105.0;
    suggested_stop = 100.0;
    risk_pct = 0.05;
    swing_target = None;
    rationale = [ "test breakout" ];
  }

let _held : Position.t =
  {
    id = "HELD-pos";
    symbol = "HELD";
    side = Trading_base.Types.Long;
    entry_reasoning = Position.PricePattern "test breakout";
    exit_reason = None;
    state =
      Position.Holding
        {
          quantity = 10.0;
          entry_price = 100.0;
          entry_date = _current_date;
          risk_params =
            {
              stop_loss_price = None;
              take_profit_price = None;
              max_hold_days = None;
            };
        };
    last_updated = _current_date;
    portfolio_lot_ids = [];
  }

let _portfolio =
  {
    Trading_strategy.Portfolio_view.cash = 1_000_000.0;
    positions = String.Map.singleton _held.id _held;
  }

(* The investor gate is on, so all four shadow verdicts are reachable. *)
let _config =
  {
    (Weinstein_strategy_config.default_config
       ~universe:[ "NARROW"; "WIDE"; "RISING" ]
       ~index_symbol:"SPY")
    with
    require_structural_stop = true;
  }

(* Run the walk; its transitions, its decisions and (when asked) its report. *)
let _walk ~with_report =
  let decisions = ref [] in
  let report = ref None in
  let transitions =
    Entry_walk.entries_from_candidates ~config:_config
      ~candidates:(List.map [ "NARROW"; "WIDE"; "RISING" ] ~f:_candidate)
      ~stop_states:(ref String.Map.empty) ~bar_reader:_bar_reader
      ~portfolio:_portfolio
      ~get_price:(fun _ -> None)
      ~current_date:_current_date
      ~on_candidates_considered:(fun d -> decisions := d)
      ?on_walk_report:(Option.some_if with_report (fun r -> report := Some r))
      ()
  in
  (transitions, !decisions, !report)

let _report_exn () =
  match _walk ~with_report:true with
  | _, _, Some report -> report
  | _, _, None -> assert_failure "the walk built no report"

(* One tag per walk outcome / shadow verdict, so the two can be compared. *)
let _outcome_tag : AR.walk_outcome -> string = function
  | Placed -> "funded"
  | Skipped Stop_too_wide -> "too wide"
  | Skipped (No_structural_stop _) -> "no structural stop"
  | Skipped _ -> "other skip"

let _shadow_tag : AR.Top_n.shadow -> string = function
  | Buyable _ -> "funded"
  | Stop_too_wide _ -> "too wide"
  | No_structural_stop -> "no structural stop"
  | Already_held -> "held"

(** The shadow and the walk cannot disagree: for every name the walk classified,
    the shadow built from the walk's report says what the walk did. *)
let test_shadow_agrees_with_the_walk _ =
  let _, decisions, report = _walk ~with_report:true in
  let report = Option.value_exn report in
  let tags f = List.map decisions ~f:(fun (d : AR.walk_decision) -> f d) in
  assert_that
    (tags (fun d -> _shadow_tag (Cascade_trace.shadow_verdict report d.ranked)))
    (equal_to (tags (fun d -> _outcome_tag d.outcome)))

(** Each of the four shadow constructors, from the real check: the narrow floor
    is buyable at its ~5% distance, the crash floor too wide at about half, the
    no-correction series has no structural stop, and a held name is
    [Already_held] before any stop is computed (it has no bars at all). *)
let test_every_shadow_verdict _ =
  let report = _report_exn () in
  assert_that
    (List.map [ "NARROW"; "WIDE"; "RISING"; "HELD" ] ~f:(fun t ->
         Cascade_trace.shadow_verdict report (_candidate t)))
    (elements_are
       [
         matching ~msg:"Buyable"
           (function AR.Top_n.Buyable d -> Some d | _ -> None)
           (is_between (module Float_ord) ~low:0.01 ~high:0.15);
         matching ~msg:"Stop_too_wide"
           (function AR.Top_n.Stop_too_wide d -> Some d | _ -> None)
           (gt (module Float_ord) 0.15);
         matching ~msg:"No_structural_stop"
           (function AR.Top_n.No_structural_stop -> Some () | _ -> None)
           (equal_to ());
         matching ~msg:"Already_held"
           (function AR.Top_n.Already_held -> Some () | _ -> None)
           (equal_to ());
       ])

(** The shadow places nothing: asking the walk's check about every name, the
    buyable one included, consumes no position id. (It is handed no stop-state
    table and no cash, so those cannot move by construction.) *)
let test_shadow_consumes_no_position_id _ =
  let report = _report_exn () in
  let before = Entry_audit_capture.position_counter () in
  List.iter [ "NARROW"; "WIDE"; "RISING"; "HELD" ] ~f:(fun t ->
      ignore
        (Cascade_trace.shadow_verdict report (_candidate t) : AR.Top_n.shadow));
  assert_that (Entry_audit_capture.position_counter ()) (equal_to before)

(* What the walk decided and placed, minus the position ids (a global counter
   that moves between runs by design). *)
let _walk_shape ~with_report =
  let transitions, decisions, _ = _walk ~with_report in
  ( List.map decisions ~f:(fun (d : AR.walk_decision) ->
        (d.ranked.ticker, _outcome_tag d.outcome)),
    List.filter_map transitions ~f:(fun (t : Position.transition) ->
        match t.kind with
        | Position.CreateEntering e ->
            Some (e.symbol, e.target_quantity, e.entry_price)
        | _ -> None) )

(** Asking for the report changes nothing about the walk: the same names in the
    same order with the same outcomes, and the same tickets at the same size. *)
let test_report_leaves_the_walk_unchanged _ =
  assert_that
    (_walk_shape ~with_report:true)
    (equal_to (_walk_shape ~with_report:false))

(** [long_cash_left_pct] is the long budget (all of the cash here: no sleeve, no
    reserve) less what the one placed ticket costs, over portfolio value. *)
let test_long_cash_left_is_budget_less_placed_cost _ =
  let transitions, _, report = _walk ~with_report:true in
  let placed =
    List.sum
      (module Float)
      transitions
      ~f:(fun (t : Position.transition) ->
        match t.kind with
        | Position.CreateEntering e -> e.target_quantity *. e.entry_price
        | _ -> 0.0)
  in
  let value =
    Trading_strategy.Portfolio_view.portfolio_value _portfolio
      ~get_price:(fun _ -> None)
  in
  assert_that report
    (is_some_and
       (field
          (fun (r : Entry_walk.walk_report) -> r.long_cash_left_pct)
          (float_equal ((_portfolio.cash -. placed) /. value))))

(* A walk over one long (NARROW) and one short (FALLING) on an empty book
   holding [cash], with fallback stops allowed so both can be placed: its
   transitions and its report. *)
let _cash_walk ?(short_sleeve_fraction = 0.0) ~cash () =
  let report = ref None in
  let transitions =
    Entry_walk.entries_from_candidates
      ~config:
        { _config with require_structural_stop = false; short_sleeve_fraction }
      ~candidates:
        [
          _candidate "NARROW";
          _candidate ~side:Trading_base.Types.Short "FALLING";
        ]
      ~stop_states:(ref String.Map.empty) ~bar_reader:_bar_reader
      ~portfolio:{ cash; positions = String.Map.empty }
      ~get_price:(fun _ -> None)
      ~current_date:_current_date
      ~on_walk_report:(fun r -> report := Some r)
      ()
  in
  (transitions, Option.value_exn !report)

(* What the placed tickets on [side] cost. *)
let _cost_on side transitions =
  List.sum
    (module Float)
    transitions
    ~f:(fun (t : Position.transition) ->
      match t.kind with
      | Position.CreateEntering e
        when Trading_base.Types.equal_position_side e.side side ->
          e.target_quantity *. e.entry_price
      | _ -> 0.0)

let _cash = 1_000_000.0

(** A short ticket draws on the same cash in the combined walk but never reduces
    the long figure: with one long and one short placed, the figure is the cash
    less the long's cost only. *)
let test_short_tickets_do_not_reduce_long_cash _ =
  let transitions, report = _cash_walk ~cash:_cash () in
  assert_that
    (_cost_on Trading_base.Types.Short transitions, report.long_cash_left_pct)
    (all_of
       [
         field fst (gt (module Float_ord) 0.0);
         field snd
           (float_equal
              ((_cash -. _cost_on Trading_base.Types.Long transitions) /. _cash));
       ])

(** Under a reserved short sleeve the long budget is what lies above the sleeve,
    so the figure is measured against it. *)
let test_long_cash_left_is_measured_above_the_sleeve _ =
  let sleeve = 0.2 in
  let transitions, report =
    _cash_walk ~short_sleeve_fraction:sleeve ~cash:_cash ()
  in
  assert_that report.long_cash_left_pct
    (float_equal
       ((_cash -. (_cash *. sleeve)
        -. _cost_on Trading_base.Types.Long transitions)
       /. _cash))

(** A book worth nothing reports [0.0], not a division by zero. *)
let test_long_cash_left_is_zero_on_a_worthless_book _ =
  assert_that (snd (_cash_walk ~cash:0.0 ())).long_cash_left_pct
    (float_equal 0.0)

let () =
  run_test_tt_main
    ("walk_report"
    >::: [
           "short tickets do not reduce long cash"
           >:: test_short_tickets_do_not_reduce_long_cash;
           "long cash left is measured above the sleeve"
           >:: test_long_cash_left_is_measured_above_the_sleeve;
           "long cash left is zero on a worthless book"
           >:: test_long_cash_left_is_zero_on_a_worthless_book;
           "the shadow agrees with the walk"
           >:: test_shadow_agrees_with_the_walk;
           "every shadow verdict" >:: test_every_shadow_verdict;
           "the shadow consumes no position id"
           >:: test_shadow_consumes_no_position_id;
           "the report leaves the walk unchanged"
           >:: test_report_leaves_the_walk_unchanged;
           "long cash left is budget less placed cost"
           >:: test_long_cash_left_is_budget_less_placed_cost;
         ])
