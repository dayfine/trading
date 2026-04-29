(** End-to-end exercise of {!Force_liquidation_runner} with a synthetic
    [Position.t] [Holding] + bar input.

    Closes the runner-side contract for G4: given a held position whose
    unrealized P&L exceeds the configured threshold, the runner emits a
    [TriggerExit] transition and routes a [force_liquidation_event] through the
    audit recorder. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
module Position = Trading_strategy.Position
module FL = Portfolio_risk.Force_liquidation

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let _date s = Date.of_string s

let _make_bar ~date ~close =
  Types.Daily_price.
    {
      date;
      open_price = close;
      high_price = close *. 1.01;
      low_price = close *. 0.99;
      close_price = close;
      adjusted_close = close;
      volume = 1_000_000;
    }

(** Build a [Holding] position with [side]/[entry_price]/[quantity] using the
    canonical entry chain so the result is bit-equal to what the simulator would
    have produced. *)
let _make_holding ~symbol ~side ~entry_date ~quantity ~entry_price =
  let pos_id = symbol ^ "-1" in
  let unwrap = function
    | Ok p -> p
    | Error err -> assert_failure ("position setup failed: " ^ Status.show err)
  in
  let trans kind = { Position.position_id = pos_id; date = entry_date; kind } in
  let p =
    Position.create_entering
      (trans
         (Position.CreateEntering
            {
              symbol;
              side;
              target_quantity = quantity;
              entry_price;
              reasoning =
                Position.TechnicalSignal
                  { indicator = "audit"; description = "test-entry" };
            }))
    |> unwrap
  in
  let p =
    Position.apply_transition p
      (trans
         (Position.EntryFill
            { filled_quantity = quantity; fill_price = entry_price }))
    |> unwrap
  in
  Position.apply_transition p
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

(** Build an [Entering] position — entry order placed but not yet filled.
    [_position_input_of_holding] returns [None] for non-Holding positions, so no
    event fires for these. *)
let _make_entering ~symbol ~side ~entry_date ~quantity ~entry_price =
  let pos_id = symbol ^ "-1" in
  let unwrap = function
    | Ok p -> p
    | Error err -> assert_failure ("position setup failed: " ^ Status.show err)
  in
  let trans kind = { Position.position_id = pos_id; date = entry_date; kind } in
  Position.create_entering
    (trans
       (Position.CreateEntering
          {
            symbol;
            side;
            target_quantity = quantity;
            entry_price;
            reasoning =
              Position.TechnicalSignal
                { indicator = "audit"; description = "test-entry" };
          }))
  |> unwrap

(** Recorder bundle that captures every emitted force-liquidation event into a
    mutable ref. Other callbacks are no-ops. *)
let _capturing_recorder () =
  let captured = ref [] in
  let recorder : Audit_recorder.t =
    {
      record_entry = (fun _ -> ());
      record_exit = (fun _ -> ());
      record_cascade_summary = (fun _ -> ());
      record_force_liquidation = (fun e -> captured := e :: !captured);
    }
  in
  (recorder, captured)

(* ------------------------------------------------------------------ *)
(* Per-position trigger                                                 *)
(* ------------------------------------------------------------------ *)

let test_per_position_trigger_emits_exit _ =
  (* Long entered $100, current $40 — 60% loss; default threshold 50% fires. *)
  let pos =
    _make_holding ~symbol:"AAPL" ~side:Trading_base.Types.Long
      ~entry_date:(_date "2024-01-02") ~quantity:100.0 ~entry_price:100.0
  in
  let bar = _make_bar ~date:(_date "2024-04-29") ~close:40.0 in
  let positions = String.Map.singleton "AAPL" pos in
  let get_price s = if String.equal s "AAPL" then Some bar else None in
  let peak_tracker = FL.Peak_tracker.create () in
  let recorder, captured = _capturing_recorder () in
  let transitions =
    Force_liquidation_runner.update ~config:FL.default_config ~positions
      ~get_price ~cash:1_000_000.0 ~current_date:(_date "2024-04-29")
      ~peak_tracker ~audit_recorder:recorder
  in
  assert_that transitions
    (elements_are
       [
         all_of
           [
             field
               (fun (t : Position.transition) -> t.position_id)
               (equal_to "AAPL-1");
             field
               (fun (t : Position.transition) -> t.kind)
               (matching ~msg:"Expected TriggerExit"
                  (function
                    | Position.TriggerExit { exit_price; _ } -> Some exit_price
                    | _ -> None)
                  (float_equal 40.0));
           ];
       ]);
  assert_that !captured (size_is 1)

let test_per_position_trigger_no_fire_under_threshold _ =
  (* Long $100 → $60 = 40% loss; threshold 50%; no fire. *)
  let pos =
    _make_holding ~symbol:"AAPL" ~side:Trading_base.Types.Long
      ~entry_date:(_date "2024-01-02") ~quantity:100.0 ~entry_price:100.0
  in
  let bar = _make_bar ~date:(_date "2024-04-29") ~close:60.0 in
  let positions = String.Map.singleton "AAPL" pos in
  let get_price s = if String.equal s "AAPL" then Some bar else None in
  let peak_tracker = FL.Peak_tracker.create () in
  let recorder, captured = _capturing_recorder () in
  let transitions =
    Force_liquidation_runner.update ~config:FL.default_config ~positions
      ~get_price ~cash:1_000_000.0 ~current_date:(_date "2024-04-29")
      ~peak_tracker ~audit_recorder:recorder
  in
  assert_that transitions is_empty;
  assert_that !captured is_empty

(* ------------------------------------------------------------------ *)
(* Portfolio-floor trigger                                              *)
(* ------------------------------------------------------------------ *)

let test_portfolio_floor_trigger_closes_all _ =
  (* Two positions; portfolio_value drops below 40% of peak; both close. *)
  let pos_a =
    _make_holding ~symbol:"AAPL" ~side:Trading_base.Types.Long
      ~entry_date:(_date "2024-01-02") ~quantity:100.0 ~entry_price:100.0
  in
  let pos_b =
    _make_holding ~symbol:"TSLA" ~side:Trading_base.Types.Long
      ~entry_date:(_date "2024-01-02") ~quantity:50.0 ~entry_price:200.0
  in
  let positions =
    String.Map.of_alist_exn [ ("AAPL", pos_a); ("TSLA", pos_b) ]
  in
  let peak_tracker = FL.Peak_tracker.create () in
  let recorder, captured = _capturing_recorder () in
  (* First tick: establish peak at 1M with both positions at par. *)
  let bar_par_a = _make_bar ~date:(_date "2024-01-02") ~close:100.0 in
  let bar_par_b = _make_bar ~date:(_date "2024-01-02") ~close:200.0 in
  let get_price_par s =
    if String.equal s "AAPL" then Some bar_par_a
    else if String.equal s "TSLA" then Some bar_par_b
    else None
  in
  (* cash: 1M - 10K (AAPL) - 10K (TSLA) = 980K; positions worth 20K → total 1M. *)
  let _ =
    Force_liquidation_runner.update ~config:FL.default_config ~positions
      ~get_price:get_price_par ~cash:980_000.0
      ~current_date:(_date "2024-01-02") ~peak_tracker ~audit_recorder:recorder
  in
  (* Second tick: catastrophic drop. AAPL 100→20, TSLA 200→40.
     Position values: 100*20 + 50*40 = 4000; cash unchanged at 980_000.
     Wait — that's still 984K which is above 40% of 1M peak. Need a bigger
     drop in CASH for the floor to fire. Let's drop cash too (e.g. simulate
     accumulated losses on shorts that already covered): cash 200_000,
     positions 4000 → total 204_000, well below 400_000 (40% of peak 1M). *)
  let bar_crash_a = _make_bar ~date:(_date "2024-04-29") ~close:20.0 in
  let bar_crash_b = _make_bar ~date:(_date "2024-04-29") ~close:40.0 in
  let get_price_crash s =
    if String.equal s "AAPL" then Some bar_crash_a
    else if String.equal s "TSLA" then Some bar_crash_b
    else None
  in
  let transitions =
    Force_liquidation_runner.update ~config:FL.default_config ~positions
      ~get_price:get_price_crash ~cash:200_000.0
      ~current_date:(_date "2024-04-29") ~peak_tracker ~audit_recorder:recorder
  in
  (* Both positions close under Portfolio_floor reason. *)
  assert_that transitions (size_is 2);
  assert_that !captured (size_is 2);
  (* Halt state must flip. *)
  assert_that (FL.Peak_tracker.halt_state peak_tracker) (equal_to FL.Halted)

let test_no_positions_no_events _ =
  let peak_tracker = FL.Peak_tracker.create () in
  let recorder, captured = _capturing_recorder () in
  let transitions =
    Force_liquidation_runner.update ~config:FL.default_config
      ~positions:String.Map.empty
      ~get_price:(fun _ -> None)
      ~cash:1_000_000.0 ~current_date:(_date "2024-04-29") ~peak_tracker
      ~audit_recorder:recorder
  in
  assert_that transitions is_empty;
  assert_that !captured is_empty

let test_short_position_loss_fires _ =
  (* Short at $200, current $320 = 60% loss (entry 200 + price up 120 / cost
     basis 200 = 0.6); default 50% fires. *)
  let pos =
    _make_holding ~symbol:"TSLA" ~side:Trading_base.Types.Short
      ~entry_date:(_date "2024-01-02") ~quantity:50.0 ~entry_price:200.0
  in
  let bar = _make_bar ~date:(_date "2024-04-29") ~close:320.0 in
  let positions = String.Map.singleton "TSLA" pos in
  let get_price s = if String.equal s "TSLA" then Some bar else None in
  let peak_tracker = FL.Peak_tracker.create () in
  let recorder, captured = _capturing_recorder () in
  let transitions =
    Force_liquidation_runner.update ~config:FL.default_config ~positions
      ~get_price ~cash:1_000_000.0 ~current_date:(_date "2024-04-29")
      ~peak_tracker ~audit_recorder:recorder
  in
  assert_that transitions (size_is 1);
  assert_that !captured
    (elements_are
       [
         all_of
           [
             field (fun (e : FL.event) -> e.symbol) (equal_to "TSLA");
             field
               (fun (e : FL.event) -> e.side)
               (equal_to Trading_base.Types.Short);
             field (fun (e : FL.event) -> e.reason) (equal_to FL.Per_position);
           ];
       ])

(* ------------------------------------------------------------------ *)
(* Defensive guards (PR #695, qc-behavioral B3)                         *)
(* ------------------------------------------------------------------ *)

(** Guard: [_position_input_of_holding] returns [None] for non-Holding
    positions. An [Entering] position (entry order placed, no fills yet) has no
    entry_price / quantity that match the [Holding] state's contract; the runner
    must skip it without firing an event. *)
let test_non_holding_position_does_not_fire _ =
  let pos =
    _make_entering ~symbol:"AAPL" ~side:Trading_base.Types.Long
      ~entry_date:(_date "2024-01-02") ~quantity:100.0 ~entry_price:100.0
  in
  let bar = _make_bar ~date:(_date "2024-04-29") ~close:30.0 in
  let positions = String.Map.singleton "AAPL" pos in
  let get_price s = if String.equal s "AAPL" then Some bar else None in
  let peak_tracker = FL.Peak_tracker.create () in
  let recorder, captured = _capturing_recorder () in
  let transitions =
    Force_liquidation_runner.update ~config:FL.default_config ~positions
      ~get_price ~cash:1_000_000.0 ~current_date:(_date "2024-04-29")
      ~peak_tracker ~audit_recorder:recorder
  in
  assert_that transitions is_empty;
  assert_that !captured is_empty

(** Guard: [_position_input_of_holding] returns [None] when [get_price] returns
    [None] for the position's symbol — the runner can't evaluate the threshold
    without a current price. The position is silently skipped this tick rather
    than fired with stale data. *)
let test_missing_price_does_not_fire _ =
  let pos =
    _make_holding ~symbol:"AAPL" ~side:Trading_base.Types.Long
      ~entry_date:(_date "2024-01-02") ~quantity:100.0 ~entry_price:100.0
  in
  let positions = String.Map.singleton "AAPL" pos in
  let peak_tracker = FL.Peak_tracker.create () in
  let recorder, captured = _capturing_recorder () in
  let transitions =
    Force_liquidation_runner.update ~config:FL.default_config ~positions
      ~get_price:(fun _ -> None)
      ~cash:1_000_000.0 ~current_date:(_date "2024-04-29") ~peak_tracker
      ~audit_recorder:recorder
  in
  assert_that transitions is_empty;
  assert_that !captured is_empty

(* ------------------------------------------------------------------ *)
(* Double-exit avoidance — strategy-level filter                        *)
(* ------------------------------------------------------------------ *)

(** [Weinstein_strategy.Internal_for_test.positions_minus_exited] removes any
    position whose [position_id] appears in a [TriggerExit] transition. The
    force-liquidation runner sees the filtered map, so a position already
    stop-exited this tick does NOT receive a duplicate force-liquidation
    [TriggerExit].

    Pinning this at the [_positions_minus_exited] seam (rather than the runner)
    matches where the contract lives — the runner has no notion of pending
    stop-exits; the strategy filter is the single source of truth. *)
let test_double_exit_avoidance_filters_already_exited _ =
  let pos_a =
    _make_holding ~symbol:"AAPL" ~side:Trading_base.Types.Long
      ~entry_date:(_date "2024-01-02") ~quantity:100.0 ~entry_price:100.0
  in
  let pos_b =
    _make_holding ~symbol:"TSLA" ~side:Trading_base.Types.Long
      ~entry_date:(_date "2024-01-02") ~quantity:50.0 ~entry_price:200.0
  in
  let positions =
    String.Map.of_alist_exn [ ("AAPL", pos_a); ("TSLA", pos_b) ]
  in
  (* AAPL just received a stop-exit transition this tick — must be filtered
     out before force-liquidation considers it. *)
  let stop_exit_transitions =
    [
      {
        Position.position_id = "AAPL-1";
        date = _date "2024-04-29";
        kind =
          Position.TriggerExit
            {
              exit_reason =
                Position.StopLoss
                  {
                    stop_price = 90.0;
                    actual_price = 89.0;
                    loss_percent = 11.0;
                  };
              exit_price = 89.0;
            };
      };
    ]
  in
  let filtered =
    Weinstein_strategy.Internal_for_test.positions_minus_exited ~positions
      ~stop_exit_transitions
  in
  assert_that
    (Map.keys filtered |> List.sort ~compare:String.compare)
    (elements_are [ equal_to "TSLA" ])

let suite =
  "force_liquidation_runner"
  >::: [
         "per_position_trigger_emits_exit"
         >:: test_per_position_trigger_emits_exit;
         "per_position_trigger_no_fire_under_threshold"
         >:: test_per_position_trigger_no_fire_under_threshold;
         "portfolio_floor_trigger_closes_all"
         >:: test_portfolio_floor_trigger_closes_all;
         "no_positions_no_events" >:: test_no_positions_no_events;
         "short_position_loss_fires" >:: test_short_position_loss_fires;
         "non-Holding position does not fire"
         >:: test_non_holding_position_does_not_fire;
         "missing price does not fire" >:: test_missing_price_does_not_fire;
         "double-exit avoidance filters already-exited"
         >:: test_double_exit_avoidance_filters_already_exited;
       ]

let () = run_test_tt_main suite
