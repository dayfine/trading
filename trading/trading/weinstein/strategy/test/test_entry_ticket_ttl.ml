(** F2 resting-entry-ticket lifecycle — re-screen cancel (primary) + clock TTL
    (backstop). Plan [dev/plans/entry-ticket-async-v2-2026-08-10.md] §2-M2 /
    §3-F2; book §4.7 ("until you either cancel the orders or they are actually
    executed") + §7 (the weekend-homework loop at which that decision is taken).

    Three layers are pinned here:
    - {!Entry_ticket_ttl.cancellations} — which resting tickets are retired.
    - {!Entry_ticket_ttl.run} — the {!Entry_freeze} pin lifecycle around a
      cancel (plan §6 "TTL × freeze"), including the complementary no-ratchet
      guarantee for a ticket that is still resting.
    - The end-to-end arming: a real [Weinstein_strategy.config] driven through
      the real [on_market_close] screening path emits the cancel when either
      [enable_entry_ticket_rescreen] or [entry_order_max_rest_weeks > 0] is set,
      and emits nothing at the defaults ([false] / [0]) — {b including} the two
      single-mechanism arms that the old combined [entry_order_ttl_weeks] knob
      could not express (defect C, 2026-08-16).

    The both-off path deliberately {b extends} — never weakens — the GTC
    persistence contract pinned by
    [trading/simulation/test/test_gtc_entry_persistence.ml]. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
module Position = Trading_strategy.Position
module FL = Portfolio_risk.Force_liquidation

(* ------------------------------------------------------------------ *)
(* Helpers                                                             *)
(* ------------------------------------------------------------------ *)

let _index_symbol = "GSPCX"
let _friday = Date.of_string "2024-04-26"

(** An [Entering] position for [symbol], created on [created], with [filled]
    shares already booked (default: none — a truly resting ticket). *)
let _entering ?(side = Trading_base.Types.Long) ?(filled = 0.0) ~id ~symbol
    ~created () =
  let trans kind : Position.transition =
    { position_id = id; date = created; kind }
  in
  let unwrap = function
    | Ok p -> p
    | Error err -> assert_failure ("position setup failed: " ^ Status.show err)
  in
  let pos =
    Position.create_entering
      (trans
         (Position.CreateEntering
            {
              symbol;
              side;
              target_quantity = 10.0;
              entry_price = 100.0;
              reasoning = ManualDecision { description = "F2 test" };
            }))
    |> unwrap
  in
  if Float.equal filled 0.0 then pos
  else
    Position.apply_transition pos
      (trans
         (Position.EntryFill { filled_quantity = filled; fill_price = 100.0 }))
    |> unwrap

(** A [Holding] position — never a cancel candidate; the ticket has become a
    real position. *)
let _holding ~id ~symbol ~created () =
  let trans kind : Position.transition =
    { position_id = id; date = created; kind }
  in
  let unwrap = function
    | Ok p -> p
    | Error err -> assert_failure ("position setup failed: " ^ Status.show err)
  in
  let pos = _entering ~id ~symbol ~created () in
  let pos =
    Position.apply_transition pos
      (trans
         (Position.EntryFill { filled_quantity = 10.0; fill_price = 100.0 }))
    |> unwrap
  in
  Position.apply_transition pos
    (trans
       (Position.EntryComplete
          {
            risk_params =
              {
                stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          }))
  |> unwrap

let _positions ps =
  List.map ps ~f:(fun (p : Position.t) -> (p.id, p)) |> String.Map.of_alist_exn

(* Coarse tag per emitted cancel: which of the two paths fired. Keeps the test
   independent of the exact diagnostic wording. *)
let _cancels transitions =
  List.filter_map transitions ~f:(fun (t : Position.transition) ->
      match t.kind with
      | Position.CancelEntry { reason } ->
          let tag =
            if String.is_substring reason ~substring:"requalification" then
              "requalification"
            else if String.is_substring reason ~substring:"ttl" then "ttl"
            else "other"
          in
          Some (t.position_id, tag)
      | _ -> None)

let _always_qualifies ~symbol:_ ~side:_ = true
let _never_qualifies ~symbol:_ ~side:_ = false

(* ------------------------------------------------------------------ *)
(* cancellations — the cancel decision                                 *)
(* ------------------------------------------------------------------ *)

(** R1: at the default [0] nothing is ever cancelled — not even a ticket that
    has rested for a year AND fails the re-screen. This is the property that
    makes [test_gtc_entry_persistence]'s GTC-forever contract an extension
    rather than a weakening. *)
let test_ttl_zero_never_cancels _ =
  assert_that
    (Entry_ticket_ttl.cancellations ~rescreen:false ~max_rest_weeks:0
       ~positions:
         (_positions
            [
              _entering ~id:"P1" ~symbol:"AAA"
                ~created:(Date.of_string "2023-04-28")
                ();
            ])
       ~still_qualifies:_never_qualifies ~current_date:_friday
    |> _cancels)
    is_empty

(** PRIMARY path: a fresh ticket (rested 1 of 4 permitted weeks) whose symbol
    fails the next weekly re-screen — base broken down / MA rolled / sector or
    macro flip — is cancelled on requalification, not on the clock. *)
let test_requalification_failure_cancels_before_ttl _ =
  assert_that
    (Entry_ticket_ttl.cancellations ~rescreen:true ~max_rest_weeks:4
       ~positions:
         (_positions
            [
              _entering ~id:"P1" ~symbol:"AAA"
                ~created:(Date.add_days _friday (-7))
                ();
            ])
       ~still_qualifies:_never_qualifies ~current_date:_friday
    |> _cancels)
    (elements_are [ equal_to ("P1", "requalification") ])

(** PRECEDENCE, with the two causes actually in contention. The test above
    cannot show it: a 1-week-old ticket against a 4-week clock leaves the clock
    unable to fire, so "re-screen first" is never exercised. Here the ticket is
    9 weeks old (past the clock) {b and} failing the re-screen, so both branches
    would cancel it and only the recorded reason distinguishes them.

    The reason is not cosmetic — [Ticket_lifecycle.cancel_reason] persists it,
    and a TTL analysis that reads the clock's token on a ticket the re-screen
    retired would attribute a book-supported decision to an invented number. *)
let test_rescreen_reason_wins_when_both_would_fire _ =
  assert_that
    (Entry_ticket_ttl.cancellations ~rescreen:true ~max_rest_weeks:4
       ~positions:
         (_positions
            [
              _entering ~id:"P1" ~symbol:"AAA"
                ~created:(Date.add_days _friday (-7 * 9))
                ();
            ])
       ~still_qualifies:_never_qualifies ~current_date:_friday
    |> _cancels)
    (elements_are [ equal_to ("P1", "requalification") ])

(** BACKSTOP path: a still-qualifying ticket survives review week [N] and is
    cancelled at week [N + 1]. Both halves asserted together so an off-by-one in
    either direction fails. *)
let test_clock_backstop_fires_one_week_after_ttl _ =
  let cancels_at ~weeks =
    Entry_ticket_ttl.cancellations ~rescreen:true ~max_rest_weeks:4
      ~positions:
        (_positions
           [
             _entering ~id:"P1" ~symbol:"AAA"
               ~created:(Date.add_days _friday (-7 * weeks))
               ();
           ])
      ~still_qualifies:_always_qualifies ~current_date:_friday
    |> _cancels
  in
  assert_that
    [ cancels_at ~weeks:3; cancels_at ~weeks:4; cancels_at ~weeks:5 ]
    (elements_are
       [ is_empty; is_empty; elements_are [ equal_to ("P1", "ttl") ] ])

(** A ticket that filled before its TTL is a normal entry: once it is [Holding]
    nothing in this module touches it, however old it is. Partially-filled
    [Entering] is likewise skipped — [CancelEntry] closes the position, which
    would strand the booked shares (and [Position]'s own validator rejects it).
*)
let test_filled_and_partially_filled_tickets_are_never_cancelled _ =
  assert_that
    (Entry_ticket_ttl.cancellations ~rescreen:true ~max_rest_weeks:4
       ~positions:
         (_positions
            [
              _holding ~id:"FILLED" ~symbol:"AAA"
                ~created:(Date.add_days _friday (-70))
                ();
              _entering ~id:"PARTIAL" ~symbol:"BBB"
                ~created:(Date.add_days _friday (-70))
                ~filled:4.0 ();
            ])
       ~still_qualifies:_never_qualifies ~current_date:_friday
    |> _cancels)
    is_empty

(** The re-screen predicate is asked per (symbol, side): a long ticket and a
    short ticket on the same tape are judged independently, so a tape that
    retires longs leaves a qualifying short alone. *)
let test_requalification_is_per_side _ =
  let long_only ~symbol:_ ~side =
    match side with
    | Trading_base.Types.Long -> false
    | Trading_base.Types.Short -> true
  in
  assert_that
    (Entry_ticket_ttl.cancellations ~rescreen:true ~max_rest_weeks:4
       ~positions:
         (_positions
            [
              _entering ~id:"L" ~symbol:"AAA" ~created:_friday ();
              _entering ~id:"S" ~symbol:"BBB" ~side:Trading_base.Types.Short
                ~created:_friday ();
            ])
       ~still_qualifies:long_only ~current_date:_friday
    |> _cancels)
    (elements_are [ equal_to ("L", "requalification") ])

(* ------------------------------------------------------------------ *)
(* run — the Entry_freeze pin lifecycle (plan §6 "TTL × freeze")        *)
(* ------------------------------------------------------------------ *)

let _pin_apply pending ?(held_set = String.Set.empty) candidates =
  Entry_freeze.apply ~enabled:true ~pending ~held_set ~candidates

(** Minimal candidate carrying only the fields the freeze reads. *)
let _candidate ~ticker ~entry : Screener.scored_candidate =
  let base =
    Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker
      ~bars:[] ~benchmark_bars:[] ~prior_stage:None ~as_of_date:_friday
  in
  {
    ticker;
    analysis = base;
    side = Trading_base.Types.Long;
    sector =
      {
        sector_name = "Tech";
        rating = Screener.Neutral;
        stage = base.stage.stage;
      };
    grade = Weinstein_types.A;
    score = 70;
    suggested_entry = entry;
    suggested_stop = entry *. 0.95;
    risk_pct = 0.05;
    swing_target = None;
    rationale = [];
  }

(** The load-bearing pin-lifecycle claim: cancelling a ticket RELEASES its
    frozen [E], so the symbol's next qualification pins the fresh level (60)
    rather than the level the expired ticket was written against (50).

    Discriminating: the symbol is still in [held_set] on the cancelling tick
    (its [Entering] position closes only once the transition is applied), so
    [Entry_freeze.apply]'s own stale-release rule would have KEPT the pin.
    Remove the [Entry_freeze.release] call from {!Entry_ticket_ttl.run} and this
    reads 50.0. *)
let test_cancel_releases_pin_so_symbol_repins_fresh _ =
  let pending = Entry_freeze.create () in
  let held = String.Set.of_list [ "AAA" ] in
  let _wk1 = _pin_apply pending [ _candidate ~ticker:"AAA" ~entry:50.0 ] in
  let cancelled =
    Entry_ticket_ttl.run ~rescreen:true ~max_rest_weeks:4
      ~pending_entry_e:pending
      ~positions:
        (_positions
           [
             _entering ~id:"P1" ~symbol:"AAA"
               ~created:(Date.add_days _friday (-7))
               ();
           ])
      ~still_qualifies:_never_qualifies ~current_date:_friday
  in
  (* Same tick: the symbol is still held, and [apply] must not resurrect a pin
     for a symbol that is not a candidate. *)
  let _same_tick = _pin_apply pending ~held_set:held [] in
  let later = _pin_apply pending [ _candidate ~ticker:"AAA" ~entry:60.0 ] in
  assert_that (_cancels cancelled)
    (elements_are [ equal_to ("P1", "requalification") ]);
  assert_that
    (List.map later ~f:(fun (c : Screener.scored_candidate) ->
         c.suggested_entry))
    (elements_are [ float_equal 60.0 ])

(** The complementary half of §6: while a ticket is STILL resting (not
    cancelled), its [E] must not ratchet up week over week. The pin survives
    both the dormant held week and the re-qualification at a chased level. *)
let test_resting_ticket_does_not_ratchet_e _ =
  let pending = Entry_freeze.create () in
  let held = String.Set.of_list [ "AAA" ] in
  let _wk1 = _pin_apply pending [ _candidate ~ticker:"AAA" ~entry:50.0 ] in
  (* Ticket rests: under the armed TTL it is young enough and still qualifies,
     so nothing is cancelled and nothing is released. *)
  let resting =
    Entry_ticket_ttl.run ~rescreen:true ~max_rest_weeks:4
      ~pending_entry_e:pending
      ~positions:
        (_positions
           [
             _entering ~id:"P1" ~symbol:"AAA"
               ~created:(Date.add_days _friday (-7))
               ();
           ])
      ~still_qualifies:_always_qualifies ~current_date:_friday
  in
  let _dormant = _pin_apply pending ~held_set:held [] in
  let later = _pin_apply pending [ _candidate ~ticker:"AAA" ~entry:70.0 ] in
  assert_that (_cancels resting) is_empty;
  assert_that
    (List.map later ~f:(fun (c : Screener.scored_candidate) ->
         c.suggested_entry))
    (elements_are [ float_equal 50.0 ])

(* ------------------------------------------------------------------ *)
(* End-to-end: the CONFIG arms the cancel through the real screening   *)
(* path (not just the direct-parameter surface above).                 *)
(* ------------------------------------------------------------------ *)

let _daily_bar ~date ~price =
  {
    Types.Daily_price.date;
    open_price = price;
    high_price = price *. 1.01;
    low_price = price *. 0.99;
    close_price = price;
    adjusted_close = price;
    volume = 1_000_000;
    active_through = None;
  }

let _daily_bars ~start_date ~n ~start_price ~step =
  List.init n ~f:(fun i ->
      _daily_bar
        ~date:(Date.add_days start_date i)
        ~price:(start_price +. (Float.of_int i *. step)))

(** Index rising (Bullish macro, so the screen runs), plus a candidate symbol
    whose series is supplied by the caller. *)
let _reader ~end_date ~symbol ~symbol_step =
  let n = 260 in
  let start_date = Date.add_days end_date (-(n - 1)) in
  Bar_reader.of_in_memory_bars
    [
      (_index_symbol, _daily_bars ~start_date ~n ~start_price:100.0 ~step:1.0);
      (symbol, _daily_bars ~start_date ~n ~start_price:200.0 ~step:symbol_step);
    ]

let _get_price_of ~bar_reader ~current_date symbol =
  match Bar_reader.daily_bars_for bar_reader ~symbol ~as_of:current_date with
  | [] -> None
  | bars -> List.last bars

(** Drive one real Friday tick through [Internal_for_test.on_market_close] with
    [config] — the same code path [make] wires — and return its transitions. *)
let _drive ~config ~bar_reader ~current_date ~positions =
  let result =
    Internal_for_test.on_market_close ~fold_start_date:None ~config ~ad_bars:[]
      ~stop_states:(ref String.Map.empty)
      ~last_stop_out_dates:(Hashtbl.create (module String))
      ~prior_macro:(ref Weinstein_types.Neutral)
      ~prior_macro_result:(ref None)
      ~prior_decline_character:(ref Decline_character.Not_declining)
      ~peak_tracker:(FL.Peak_tracker.create ())
      ~bar_reader
      ~prior_stages:(Hashtbl.create (module String))
      ~prior_stage_ma_values:(Hashtbl.create (module String))
      ~sector_prior_stages:(Hashtbl.create (module String))
      ~ticker_sectors:(Hashtbl.create (module String))
      ~stage3_streaks:(Hashtbl.create (module String))
      ~laggard_streaks:(Hashtbl.create (module String))
      ~audit_recorder:Audit_recorder.noop
      ~get_price:(_get_price_of ~bar_reader ~current_date)
      ~get_indicator:(fun _ _ _ _ -> None)
      ~portfolio:{ cash = 100_000.0; positions }
  in
  assert_that result is_ok;
  match result with
  | Ok output -> _cancels output.Trading_strategy.Strategy_interface.transitions
  | Error _ -> []

let _ttl_config ~rescreen ~max_rest_weeks =
  {
    (Weinstein_strategy.default_config ~universe:[ "ZZZ" ]
       ~index_symbol:_index_symbol)
    with
    enable_entry_ticket_rescreen = rescreen;
    entry_order_max_rest_weeks = max_rest_weeks;
  }

let _resting_ticket ~weeks_old =
  _positions
    [
      _entering ~id:"ZZZ-1" ~symbol:"ZZZ"
        ~created:(Date.add_days _friday (-7 * weeks_old))
        ();
    ]

(** END-TO-END, PRIMARY path: a resting ticket on a symbol in a sustained
    decline (below a falling 30-week MA — Stage 4, never a long candidate) fails
    the weekly re-screen and is cancelled — but ONLY when the config arms the
    mechanism. All three arms run the identical tick; the differences are the
    config flags, which pins the config→screening arming rather than the
    direct-parameter surface.

    The third arm is the point of defect C: [enable_entry_ticket_rescreen]
    alone, with the clock left unbounded, gets the book-supported cancel. Under
    the old single [entry_order_ttl_weeks] knob that combination was unreachable
    — [0] returned [[]] without even consulting the re-screen predicate, so
    taking the faithful half meant also accepting an invented number. *)
let test_config_arms_rescreen_cancel_end_to_end _ =
  let bar_reader =
    _reader ~end_date:_friday ~symbol:"ZZZ" ~symbol_step:(-0.5)
  in
  let drive ~rescreen ~max_rest_weeks =
    _drive
      ~config:(_ttl_config ~rescreen ~max_rest_weeks)
      ~bar_reader ~current_date:_friday
      ~positions:(_resting_ticket ~weeks_old:1)
  in
  let cancelled = elements_are [ equal_to ("ZZZ-1", "requalification") ] in
  assert_that
    [
      drive ~rescreen:false ~max_rest_weeks:0;
      drive ~rescreen:true ~max_rest_weeks:4;
      drive ~rescreen:true ~max_rest_weeks:0;
    ]
    (elements_are [ is_empty; cancelled; cancelled ])

(** END-TO-END, BACKSTOP path: an aged ticket is retired on the clock even while
    its symbol keeps qualifying (rising series, Stage 2). The unbounded arm
    emits nothing however old the ticket is, and the [8] arm shows the
    younger-than-TTL ticket surviving — so the cancel is attributable to age,
    not to the tick simply always cancelling.

    The fourth arm is the other half of defect C: the clock alone, with the
    re-screen off, still fires. The two mechanisms are now genuinely independent
    in both directions. *)
let test_config_arms_clock_backstop_end_to_end _ =
  let bar_reader = _reader ~end_date:_friday ~symbol:"ZZZ" ~symbol_step:1.0 in
  let drive ~rescreen ~max_rest_weeks ~weeks_old =
    _drive
      ~config:(_ttl_config ~rescreen ~max_rest_weeks)
      ~bar_reader ~current_date:_friday
      ~positions:(_resting_ticket ~weeks_old)
  in
  let expired = elements_are [ equal_to ("ZZZ-1", "ttl") ] in
  assert_that
    [
      drive ~rescreen:false ~max_rest_weeks:0 ~weeks_old:9;
      drive ~rescreen:true ~max_rest_weeks:8 ~weeks_old:9;
      drive ~rescreen:true ~max_rest_weeks:8 ~weeks_old:3;
      drive ~rescreen:false ~max_rest_weeks:8 ~weeks_old:9;
    ]
    (elements_are [ is_empty; expired; is_empty; expired ])

let suite =
  "entry_ticket_ttl"
  >::: [
         "ttl 0 never cancels" >:: test_ttl_zero_never_cancels;
         "re-screen failure cancels before the clock"
         >:: test_requalification_failure_cancels_before_ttl;
         "the re-screen's reason wins when both causes would fire"
         >:: test_rescreen_reason_wins_when_both_would_fire;
         "clock backstop fires at week N+1"
         >:: test_clock_backstop_fires_one_week_after_ttl;
         "filled / partially-filled tickets are never cancelled"
         >:: test_filled_and_partially_filled_tickets_are_never_cancelled;
         "re-screen is judged per side" >:: test_requalification_is_per_side;
         "cancel releases the pin so the symbol re-pins fresh"
         >:: test_cancel_releases_pin_so_symbol_repins_fresh;
         "a resting ticket does not ratchet E"
         >:: test_resting_ticket_does_not_ratchet_e;
         "config arms the re-screen cancel end to end"
         >:: test_config_arms_rescreen_cancel_end_to_end;
         "config arms the clock backstop end to end"
         >:: test_config_arms_clock_backstop_end_to_end;
       ]

let () = run_test_tt_main suite
