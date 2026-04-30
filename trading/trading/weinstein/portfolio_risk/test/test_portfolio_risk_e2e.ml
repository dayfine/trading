(** End-to-end tests for position management (Milestone 4).

    Demonstrates: "You can track positions, compute trailing stops, monitor for
    stop hits, and get alerts when something needs attention."

    Exercises the full position lifecycle across three modules:
    - [Weinstein_stops]: trailing stop state machine driven by real weekly bars
    - [Weinstein_order_gen]: translation of strategy transitions into broker
      orders
    - [Portfolio_risk]: position sizing and exposure limits

    Uses real cached AAPL weekly bars for the lifecycle test. *)

open Core
open OUnit2
open Matchers
open Trading_base.Types
open Trading_strategy

(* ------------------------------------------------------------------ *)
(* Test 1: Full position lifecycle — entry → trailing stop → exit      *)
(* ------------------------------------------------------------------ *)

(** Advance the stop state by one weekly bar.

    Runs [Stage.classify] on the bar history up to and including [bar] to derive
    [ma_value], [ma_direction], and [stage], then calls
    [Weinstein_stops.update]. Returns the new state, the event, and the stop
    level after the update. *)
let _advance_stop ~state ~history ~bar =
  let stage_result =
    Stage.classify ~config:Stage.default_config ~bars:history ~prior_stage:None
  in
  let new_state, event =
    Weinstein_stops.update ~config:Weinstein_stops.default_config ~side:Long
      ~state ~current_bar:bar ~ma_value:stage_result.ma_value
      ~ma_direction:stage_result.ma_direction ~stage:stage_result.stage
  in
  (new_state, event, Weinstein_stops.get_stop_level new_state)

(** Run the stop state machine across [lifecycle] bars. The classifier is seeded
    with [warmup] bars so the first step has a full MA window. Iteration halts
    when [Stop_hit] fires.

    Returns [(final_state, events, stop_level_history, bars_processed)] where
    [stop_level_history] has one entry per bar processed — suitable for
    monotonicity checks — and [bars_processed] is the prefix of [lifecycle]
    consumed up to and including the bar that triggered the halt. *)
let _run_stop_lifecycle ~initial_state ~warmup ~lifecycle =
  let rec loop state history remaining events stop_levels processed =
    match remaining with
    | [] -> (state, List.rev events, List.rev stop_levels, List.rev processed)
    | bar :: rest ->
        let history' = history @ [ bar ] in
        let new_state, event, stop_level =
          _advance_stop ~state ~history:history' ~bar
        in
        let events' = event :: events in
        let stop_levels' = stop_level :: stop_levels in
        let processed' = bar :: processed in
        let hit =
          match event with Weinstein_stops.Stop_hit _ -> true | _ -> false
        in
        if hit then
          ( new_state,
            List.rev events',
            List.rev stop_levels',
            List.rev processed' )
        else loop new_state history' rest events' stop_levels' processed'
  in
  loop initial_state warmup lifecycle [] [] []

let test_full_position_lifecycle _ =
  (* AAPL from 2020-09 through 2024-03: post-split (Aug 2020) so close ≈
     adjusted_close — no split-adjustment mismatch between Stage (which
     reads adjusted_close) and Stops (which reads close_price).

     The 30-bar warmup puts entry at 2021-03-26 with 30-week MA ~$122 as
     the reference level. The lifecycle then exercises the full stop
     progression:

       2021-04-16  Stop_raised  117.26 → 117.67   1st correction completes
       2021-07-02  Stop_raised  117.67 → 120.88   2nd correction, larger
       2021-11-19  Stop_raised  120.88 → 136.89   3rd, after ~$180 peak
       2022-05-13  Entered_tightening              Stage 3/4 detected;
                                                   stop snugs to ~$148.38
       2022-05-20  Stop_hit     trigger 132.61     tightened stop breached

     Three progressive trailing ratchets demonstrate the "never lowered"
     invariant across multiple completed corrections. The final tightening +
     exit confirms the full state machine cycle: Initial → Trailing →
     Tightened → Stop_hit. *)
  let start_date = Date.of_string "2020-09-01" in
  let end_date = Date.of_string "2024-03-28" in
  let weekly =
    Test_data_loader.load_weekly_bars ~symbol:"AAPL" ~start_date ~end_date
  in
  let warmup_count = 30 in
  let warmup, lifecycle = List.split_n weekly warmup_count in
  let entry_stage =
    Stage.classify ~config:Stage.default_config ~bars:warmup ~prior_stage:None
  in
  let initial_state =
    Weinstein_stops.compute_initial_stop ~config:Weinstein_stops.default_config
      ~side:Long ~reference_level:entry_stage.ma_value
  in
  let initial_stop = Weinstein_stops.get_stop_level initial_state in
  let _final_state, events, stop_levels, processed_bars =
    _run_stop_lifecycle ~initial_state ~warmup ~lifecycle
  in
  (* Core Weinstein invariant: the stop level is never lowered for a long
     position. Zipping [initial_stop :: stop_levels[:-1]] against
     [stop_levels] gives one (prev, curr) pair per bar, and [each] asserts
     curr >= prev on every pair — so a regression reports the offending
     index instead of a bare "false". *)
  let pairs =
    List.zip_exn (initial_stop :: List.drop_last_exn stop_levels) stop_levels
  in
  assert_that pairs
    (each (fun (prev, curr) -> assert_that curr (ge (module Float_ord) prev)));
  (* The "notable" event sequence — drop No_change and pair each with the
     bar that produced it — must match the observed lifecycle exactly.
     [elements_are] pins both the count and the per-slot shape, so a
     regression in any phase fails loud with an index mismatch. *)
  let notable =
    List.filter_mapi (List.zip_exn processed_bars events) ~f:(fun _ (bar, ev) ->
        match ev with Weinstein_stops.No_change -> None | _ -> Some (bar, ev))
  in
  (* Helper: assert a Stop_raised event with expected old/new levels (±0.5). *)
  let assert_raised ~date ~old_lvl ~new_lvl ((bar : Types.Daily_price.t), ev) =
    assert_that bar.date (equal_to (Date.of_string date));
    assert_that ev
      (matching ~msg:"Expected Stop_raised"
         (function
           | Weinstein_stops.Stop_raised { old_level; new_level; _ } ->
               Some (old_level, new_level)
           | _ -> None)
         (fun (o, n) ->
           assert_that o (float_equal ~epsilon:0.5 old_lvl);
           assert_that n (float_equal ~epsilon:0.5 new_lvl)))
  in
  assert_that notable
    (elements_are
       [
         (* Three progressive trailing ratchets — the stop goes up with each
            completed correction, never back down. *)
         assert_raised ~date:"2021-04-16" ~old_lvl:117.26 ~new_lvl:117.67;
         assert_raised ~date:"2021-07-02" ~old_lvl:117.67 ~new_lvl:120.88;
         assert_raised ~date:"2021-11-19" ~old_lvl:120.88 ~new_lvl:136.89;
         (* Regime change: Stage 3/4 detected → stop snugs to ~$148.38. *)
         (fun ((bar : Types.Daily_price.t), ev) ->
           assert_that bar.date (equal_to (Date.of_string "2022-05-13"));
           assert_that ev
             (matching ~msg:"Expected Entered_tightening at Stage 3/4"
                (function
                  | Weinstein_stops.Entered_tightening { reason } -> Some reason
                  | _ -> None)
                (fun reason ->
                  assert_that
                    (String.is_substring reason ~substring:"Stage 3/4")
                    (equal_to true))));
         (* Exit: tightened stop breached the following week. *)
         (fun ((bar : Types.Daily_price.t), ev) ->
           assert_that bar.date (equal_to (Date.of_string "2022-05-20"));
           assert_that ev
             (matching ~msg:"Expected Stop_hit on the tightened stop"
                (function
                  | Weinstein_stops.Stop_hit { trigger_price; stop_level } ->
                      Some (trigger_price, stop_level)
                  | _ -> None)
                (fun (trigger_price, stop_level) ->
                  assert_that trigger_price (float_equal ~epsilon:1.0 132.61);
                  assert_that stop_level (float_equal ~epsilon:1.0 148.38))));
       ])

(* ------------------------------------------------------------------ *)
(* Test 2: Order generation for a position lifecycle                    *)
(* ------------------------------------------------------------------ *)

(** Minimal AAPL position in Holding state used by the [get_position] lookup
    callback. [Weinstein_order_gen.from_transitions] calls this to determine
    share counts for stop-update orders. *)
let _aapl_holding_position =
  {
    Position.id = "AAPL-1";
    symbol = "AAPL";
    side = Position.Long;
    entry_reasoning =
      Position.TechnicalSignal
        { indicator = "SMA30"; description = "stage 2 breakout" };
    exit_reason = None;
    state =
      Position.Holding
        {
          quantity = 100.0;
          entry_price = 150.0;
          entry_date = Date.of_string "2023-01-09";
          risk_params =
            {
              Position.stop_loss_price = Some 138.0;
              take_profit_price = None;
              max_hold_days = None;
            };
        };
    last_updated = Date.of_string "2023-01-09";
    portfolio_lot_ids = [];
  }

let _lookup_aapl position_id =
  if String.equal position_id "AAPL-1" then Some _aapl_holding_position
  else None

(** Build the sequence of transitions a position goes through during a typical
    lifecycle: 1. CreateEntering (strategy requests entry) 2. EntryFill +
    EntryComplete (simulator-internal, should be ignored) 3. Two
    UpdateRiskParams (stop raised twice as price advances) 4. TriggerExit
    (strategy detects stop hit — should not produce a new order because the GTC
    stop is already at the broker) *)
let _lifecycle_transitions =
  [
    {
      Position.position_id = "AAPL-1";
      date = Date.of_string "2023-01-09";
      kind =
        Position.CreateEntering
          {
            symbol = "AAPL";
            side = Position.Long;
            target_quantity = 100.0;
            entry_price = 150.0;
            reasoning =
              Position.TechnicalSignal
                { indicator = "SMA30"; description = "stage 2 breakout" };
          };
    };
    {
      position_id = "AAPL-1";
      date = Date.of_string "2023-01-10";
      kind = Position.EntryFill { filled_quantity = 100.0; fill_price = 150.0 };
    };
    {
      position_id = "AAPL-1";
      date = Date.of_string "2023-01-10";
      kind =
        Position.EntryComplete
          {
            risk_params =
              {
                Position.stop_loss_price = Some 138.0;
                take_profit_price = None;
                max_hold_days = None;
              };
          };
    };
    {
      position_id = "AAPL-1";
      date = Date.of_string "2023-06-01";
      kind =
        Position.UpdateRiskParams
          {
            new_risk_params =
              {
                Position.stop_loss_price = Some 155.0;
                take_profit_price = None;
                max_hold_days = None;
              };
          };
    };
    {
      position_id = "AAPL-1";
      date = Date.of_string "2023-09-01";
      kind =
        Position.UpdateRiskParams
          {
            new_risk_params =
              {
                Position.stop_loss_price = Some 165.0;
                take_profit_price = None;
                max_hold_days = None;
              };
          };
    };
    {
      position_id = "AAPL-1";
      date = Date.of_string "2023-10-27";
      kind =
        Position.TriggerExit
          {
            exit_reason =
              Position.StopLoss
                {
                  stop_price = 165.0;
                  actual_price = 164.0;
                  loss_percent = 0.006;
                };
            exit_price = 164.0;
          };
    };
  ]

let test_order_generation_for_lifecycle _ =
  let orders =
    Weinstein_order_gen.from_transitions ~transitions:_lifecycle_transitions
      ~get_position:_lookup_aapl
  in
  (* Expected: one entry StopLimit + two Stop updates. EntryFill,
     EntryComplete, and TriggerExit all produce no broker order. *)
  assert_that orders
    (elements_are
       [
         (fun o ->
           assert_that o.Weinstein_order_gen.ticker (equal_to "AAPL");
           assert_that o.side (equal_to Buy);
           assert_that o.shares (equal_to 100);
           assert_that o.order_type
             (matching ~msg:"Expected StopLimit for entry"
                (function StopLimit _ -> Some () | _ -> None)
                (equal_to ())));
         (fun o ->
           assert_that o.Weinstein_order_gen.ticker (equal_to "AAPL");
           assert_that o.side (equal_to Sell);
           assert_that o.shares (equal_to 100);
           assert_that o.order_type
             (matching ~msg:"Expected Stop at 155.0"
                (function Stop p -> Some p | _ -> None)
                (float_equal 155.0)));
         (fun o ->
           assert_that o.Weinstein_order_gen.ticker (equal_to "AAPL");
           assert_that o.side (equal_to Sell);
           assert_that o.shares (equal_to 100);
           assert_that o.order_type
             (matching ~msg:"Expected Stop at 165.0"
                (function Stop p -> Some p | _ -> None)
                (float_equal 165.0)));
       ])

(* ------------------------------------------------------------------ *)
(* Test 3: Position sizing respects risk budget                         *)
(* ------------------------------------------------------------------ *)

(** For a set of (entry, stop) pairs, verify that the computed position size
    never risks more than [risk_per_trade_pct] of portfolio value. The
    invariant: [shares * (entry - stop) / portfolio_value <= risk_pct]. *)
let test_position_sizing_respects_risk_budget _ =
  let portfolio_value = 100_000.0 in
  let config = Portfolio_risk.default_config in
  let cases = [ (50.0, 45.0); (100.0, 92.0); (250.0, 230.0); (17.50, 16.25) ] in
  let risk_ratios =
    List.map cases ~f:(fun (entry, stop) ->
        let result =
          Portfolio_risk.compute_position_size ~config ~portfolio_value
            ~side:`Long ~entry_price:entry ~stop_price:stop ()
        in
        result.risk_amount /. portfolio_value)
  in
  (* Every case must come in at or below the configured risk cap. [each]
     applies the same bound check to every element; the count is pinned by
     construction since [List.map cases] preserves length. *)
  assert_that risk_ratios
    (all_of
       [
         field List.length (equal_to (List.length cases));
         each (le (module Float_ord) config.risk_per_trade_pct);
       ])

(* ------------------------------------------------------------------ *)
(* Test 4: Portfolio exposure limits flag over-concentration            *)
(* ------------------------------------------------------------------ *)

(** Build a portfolio_snapshot for limit-check tests, bypassing the actual
    Portfolio module so we can set arbitrary sector counts. *)
let _make_snapshot ?(cash = 80_000.0) ?(long_exp = 15_000.0) ?(short_exp = 0.0)
    ?(positions = 3) ?(sectors = []) () =
  let total = cash +. long_exp -. short_exp in
  {
    Portfolio_risk.total_value = total;
    cash;
    cash_pct = (if Float.( > ) total 0.0 then cash /. total else 0.0);
    long_exposure = long_exp;
    long_exposure_pct =
      (if Float.( > ) total 0.0 then long_exp /. total else 0.0);
    short_exposure = short_exp;
    short_exposure_pct =
      (if Float.( > ) total 0.0 then short_exp /. total else 0.0);
    position_count = positions;
    sector_counts = sectors;
  }

let test_exposure_limits_flag_over_concentration _ =
  (* Stuff the unknown-sector bucket up to the cap (default
     max_unknown_sector_positions = 2). Adding a third unknown-sector
     position should be rejected with [Unknown_sector_exceeded]. *)
  let config = Portfolio_risk.default_config in
  let snap_at_cap = _make_snapshot ~sectors:[ ("", 2) ] () in
  let over_cap =
    Portfolio_risk.check_limits ~config ~snapshot:snap_at_cap
      ~proposed_side:`Long ~proposed_value:5_000.0 ~proposed_sector:""
  in
  assert_that over_cap
    (equal_to (Result.Error [ Portfolio_risk.Unknown_sector_exceeded 3 ]));
  (* Under the cap — same config, one unknown position — should pass. *)
  let snap_under_cap = _make_snapshot ~sectors:[ ("", 1) ] () in
  let under_cap =
    Portfolio_risk.check_limits ~config ~snapshot:snap_under_cap
      ~proposed_side:`Long ~proposed_value:5_000.0 ~proposed_sector:""
  in
  assert_that under_cap (equal_to (Result.Ok ()));
  (* Named-sector cap (default max_sector_concentration = 5). Five Tech
     positions on the books — a sixth should fail with
     [Sector_concentration]. *)
  let snap_tech_full = _make_snapshot ~sectors:[ ("Tech", 5) ] () in
  let tech_sixth =
    Portfolio_risk.check_limits ~config ~snapshot:snap_tech_full
      ~proposed_side:`Long ~proposed_value:5_000.0 ~proposed_sector:"Tech"
  in
  assert_that tech_sixth
    (equal_to
       (Result.Error [ Portfolio_risk.Sector_concentration ("Tech", 6) ]))

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let () =
  run_test_tt_main
    ("portfolio_risk_e2e"
    >::: [
           "full position lifecycle — trailing stop on real AAPL bars"
           >:: test_full_position_lifecycle;
           "order generation for position lifecycle"
           >:: test_order_generation_for_lifecycle;
           "position sizing respects portfolio risk budget"
           >:: test_position_sizing_respects_risk_budget;
           "exposure limits flag over-concentration"
           >:: test_exposure_limits_flag_over_concentration;
         ])
