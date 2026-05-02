(** Regression: split-day broker model + strategy-side [Position.t] state
    consistency.

    Background. PR-3 of the broker-model split redesign (#664) wired
    [Simulator._detect_splits_for_held_positions] + [_apply_split_events] into
    the daily step. On a split day the held [Trading_portfolio.Portfolio.t]'s
    lots are rescaled (×factor), keeping [_compute_portfolio_value] continuous.
    Verified by [test_split_day_mtm.ml] (3/3 PASS).

    What PR-3 missed. The simulator only adjusts the
    {b broker portfolio ledger}; it does {b not} adjust the strategy-side
    [Position.t] map ([t.positions : Position.t Core.String.Map.t]). After a 4:1
    split on a held long:

    - [Trading_portfolio.Portfolio.positions] reflects the post-split lot
      quantity (e.g. 400 shares; total cost basis preserved at $50K).
    - [Position.t] still carries the pre-split [Holding.quantity = 100] and
      pre-split [entry_price = $500].
    - The strategy reads its [Portfolio_view.positions] (built from
      [t.positions]) and sees 100 shares; the broker actually holds 400.

    Surface — exit on a post-split bar. When a strategy emits [TriggerExit]
    after a split day, [Position.apply_transition] reads the stale
    [Holding.quantity = 100] and produces an [Exiting { quantity = 100; ... }]
    state. [Order_generator] reads that quantity and builds a market sell for
    100 shares. The engine fills 100 shares against a 400-share broker position.
    The strategy's [Position] transitions to [Closed], so it will {b never}
    attempt to sell the remaining 300 shares — they are orphaned in the broker
    ledger. On a long-only universe run the cumulative bookkeeping drift across
    many split-day events drives portfolio value arbitrarily off the rails
    (negative on the sp500-2019-2023 baseline rerun reported in the dispatch).

    Test setup. Synthetic [TEST] symbol with 7 trading days. Days 1–4: pre-split
    closes around $500; adjusted_close back-rolled to ~$125. Day 5: 4:1 forward
    split — raw close drops to $125, adjusted_close continuous. Days 6–7:
    post-split flat. The custom [Buy_then_exit] strategy enters 100 shares on
    day 1, then emits [TriggerExit] on a post-split day (parameterized).

    Assertions, all of which FAIL on current main and PASS after the fix:

    - [test_post_split_exit_clears_position]: after the exit fully fills, the
      broker portfolio's positions list is empty (no orphaned lots). On current
      main only 100 of 400 shares clear; the broker still holds 300 orphan
      shares.

    - [test_post_split_exit_no_orphan_equity]: at the last step, cash is back to
      ~$100K (initial), reflecting full 400-share liquidation at $125 against a
      per-share cost basis of $125 (zero realised P&L). On current main, cash
      recovers to only $62.5K and the orphan equity inflates [portfolio_value]
      to ~$100.6K (cash $62.5K + 300 × $127).

    - [test_split_day_position_reflects_post_split]: on the split day's step
      output, the strategy-side [Holding.quantity] for [TEST] is 400 (×4) and
      [Holding.entry_price] is $125 (÷4). On current main both stay at the
      pre-split values. *)

open OUnit2
open Core
open Trading_simulation.Simulator
open Matchers
open Test_helpers
module Position = Trading_strategy.Position
module Strategy_interface = Trading_strategy.Strategy_interface

let _date s = Date.of_string s

(** Build a [Daily_price.t] with explicit raw OHLC and adjusted close. *)
let _make_bar ~date ~open_ ~high ~low ~close ~adjusted_close ~volume =
  Types.Daily_price.
    {
      date;
      open_price = open_;
      high_price = high;
      low_price = low;
      close_price = close;
      adjusted_close;
      volume;
    }

(** Synthetic 4:1 split bars for [TEST] — same shape as the AAPL fixture in
    [test_split_day_mtm.ml] but with a longer post-split tail so the strategy
    can issue an exit transition AFTER the split day has been observed. *)
let _split_bars =
  [
    _make_bar ~date:(_date "2024-01-02") ~open_:498.0 ~high:502.0 ~low:495.0
      ~close:500.0 ~adjusted_close:125.0 ~volume:1_000_000;
    _make_bar ~date:(_date "2024-01-03") ~open_:500.0 ~high:505.0 ~low:498.0
      ~close:504.0 ~adjusted_close:126.0 ~volume:1_000_000;
    _make_bar ~date:(_date "2024-01-04") ~open_:504.0 ~high:508.0 ~low:496.0
      ~close:500.0 ~adjusted_close:125.0 ~volume:1_000_000;
    _make_bar ~date:(_date "2024-01-05") ~open_:500.0 ~high:502.0 ~low:498.0
      ~close:500.0 ~adjusted_close:125.0 ~volume:1_000_000;
    (* Split day: 4:1 forward — raw / 4, adjusted continuous. *)
    _make_bar ~date:(_date "2024-01-08") ~open_:125.0 ~high:127.0 ~low:124.0
      ~close:125.0 ~adjusted_close:125.0 ~volume:4_000_000;
    _make_bar ~date:(_date "2024-01-09") ~open_:125.0 ~high:126.0 ~low:124.0
      ~close:125.0 ~adjusted_close:125.0 ~volume:4_000_000;
    _make_bar ~date:(_date "2024-01-10") ~open_:125.0 ~high:127.0 ~low:124.0
      ~close:127.0 ~adjusted_close:127.0 ~volume:4_000_000;
  ]

let _config =
  {
    start_date = _date "2024-01-02";
    end_date = _date "2024-01-11";
    initial_cash = 100_000.0;
    commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 };
    strategy_cadence = Types.Cadence.Daily;
  }

(** Two-phase strategy:

    - First call: emit [CreateEntering] for [target_quantity] shares at the
      day's close. The simulator places + fills a market order on the next bar;
      the position transitions to [Holding] when [EntryComplete] fires.
    - Subsequent calls: passive until [bar.date >= trigger_exit_on_or_after],
      then emit [TriggerExit] reading the {b live} [Holding] state from the
      [Portfolio_view.positions] map. The exit price is taken from the live
      [Holding.entry_price] (mirroring how Weinstein's stop machinery would
      source a stop-driven exit). *)
module Make_buy_then_exit (Cfg : sig
  val symbol : string
  val target_quantity : float
  val trigger_exit_on_or_after : Date.t
end) : Strategy_interface.STRATEGY = struct
  let name = "BuyThenExit"
  let entered = ref false
  let exited = ref false

  let _entry_transition ~bar =
    {
      Position.position_id = Cfg.symbol ^ "-1";
      date = bar.Types.Daily_price.date;
      kind =
        Position.CreateEntering
          {
            symbol = Cfg.symbol;
            side = Position.Long;
            target_quantity = Cfg.target_quantity;
            entry_price = bar.close_price;
            reasoning =
              Position.TechnicalSignal
                { indicator = "test"; description = "buy-then-exit" };
          };
    }

  let _exit_transition_opt ~positions ~current_date =
    let position_id = Cfg.symbol ^ "-1" in
    match Map.find positions position_id with
    | Some (pos : Position.t) -> (
        match Position.get_state pos with
        | Position.Holding { entry_price; _ } ->
            Some
              {
                Position.position_id;
                date = current_date;
                kind =
                  Position.TriggerExit
                    {
                      exit_reason =
                        Position.SignalReversal
                          { description = "test post-split exit" };
                      exit_price = entry_price;
                    };
              }
        | _ -> None)
    | None -> None

  let on_market_close ~get_price ~get_indicator:_
      ~(portfolio : Trading_strategy.Portfolio_view.t) =
    if not !entered then (
      match get_price Cfg.symbol with
      | None -> Ok { Strategy_interface.transitions = [] }
      | Some bar ->
          entered := true;
          Ok { Strategy_interface.transitions = [ _entry_transition ~bar ] })
    else if !exited then Ok { Strategy_interface.transitions = [] }
    else
      match get_price Cfg.symbol with
      | None -> Ok { Strategy_interface.transitions = [] }
      | Some bar ->
          if Date.( < ) bar.date Cfg.trigger_exit_on_or_after then
            Ok { Strategy_interface.transitions = [] }
          else
            let trans_opt =
              _exit_transition_opt ~positions:portfolio.positions
                ~current_date:bar.date
            in
            (match trans_opt with Some _ -> exited := true | None -> ());
            Ok { Strategy_interface.transitions = Option.to_list trans_opt }
end

(** Find the step on a specific date. Fail with diagnostic on miss. *)
let _step_on ~date steps =
  match
    List.find steps
      ~f:(fun (s : Trading_simulation_types.Simulator_types.step_result) ->
        Date.equal s.date date)
  with
  | Some s -> s
  | None ->
      assert_failure
        (Printf.sprintf "no step on %s; have %d steps" (Date.to_string date)
           (List.length steps))

(** Find the {b last} step in [steps]. *)
let _last_step steps =
  match List.last steps with
  | Some s -> s
  | None -> assert_failure "no steps in result"

(** Run the simulation and return the result. Builds test data via
    [with_test_data]. [test_name] is used as the unique CSV-storage subdirectory
    so OUnit's parallel sub-test execution does not race on
    [test_data/<name>/...] setup/teardown. Each sub-test in [suite] passes its
    own name. *)
let _run_split_exit_simulation ~test_name ~trigger_exit_on =
  let module Strat = Make_buy_then_exit (struct
    let symbol = "TEST"
    let target_quantity = 100.0
    let trigger_exit_on_or_after = trigger_exit_on
  end) in
  let result_ref = ref None in
  with_test_data test_name
    [ ("TEST", _split_bars) ]
    ~f:(fun data_dir ->
      let deps =
        create_deps ~symbols:[ "TEST" ] ~data_dir
          ~strategy:(module Strat)
          ~commission:_config.commission ()
      in
      let sim = create_exn ~config:_config ~deps in
      match run sim with
      | Ok r -> result_ref := Some r
      | Error err -> assert_failure ("simulation failed: " ^ Status.show err));
  match !result_ref with
  | Some r -> r
  | None -> assert_failure "simulation produced no result"

(* ------------------------------------------------------------------ *)
(* Test 1: post-split exit clears the broker position completely       *)
(* ------------------------------------------------------------------ *)

(** Scenario:
    - Day 1 (01-02): strategy emits [CreateEntering] for 100 shares.
    - Day 2 (01-03): order fills at open=$500. Broker: 100 shares, $50K cost
      basis, cash=$50K. Strategy: [Holding { quantity=100; entry_price=500 }].
    - Days 3–4: passive.
    - Day 5 (01-08, split day): detector fires (factor=4). Broker: 400 shares,
      $50K cost basis (per-share $125), cash=$50K. {b POST-FIX} strategy
      [Holding { quantity=400; entry_price=125 }]. {b PRE-FIX} strategy stays at
      [{ quantity=100; entry_price=500 }].
    - Day 6 (01-09): strategy emits [TriggerExit] reading the live
      [Holding.quantity]. POST-FIX: 400. PRE-FIX: 100.
    - Day 7 (01-10): exit order fills at open=$125. POST-FIX: 400 shares sell,
      broker cash recovers to $100K, position closed. PRE-FIX: 100 shares sell,
      leaving 300 orphan shares.

    Pin: broker.positions is empty at the last step. *)
let test_post_split_exit_clears_position _ =
  let result =
    _run_split_exit_simulation ~test_name:"split_day_stop_exit_clears_position"
      ~trigger_exit_on:(_date "2024-01-09")
  in
  let last = _last_step result.steps in
  assert_that last.portfolio.positions (size_is 0)

(* ------------------------------------------------------------------ *)
(* Test 2: realised cash + portfolio_value after exit are split-clean   *)
(* ------------------------------------------------------------------ *)

(** Cost basis of the original 100-share entry at $500 = $50,000 total. After
    4:1 split: 400 shares at $125 per share, total cost basis still $50,000.
    Selling all 400 at the post-split open ($125) yields $0 realised P&L
    (commission is zero). Cash: $50K (after entry) + $50K (from full exit) =
    $100K (= initial).

    PRE-FIX: only 100 shares sell at $125 → $12,500 cash recovered →
    cash=$62,500. Plus 300 orphan shares × $127 (last close) = $38,100 of
    phantom equity → portfolio_value ≈ $100,600. Pin both cash and
    portfolio_value to ~$100K to fail in that regime. *)
let test_post_split_exit_no_orphan_equity _ =
  let result =
    _run_split_exit_simulation ~test_name:"split_day_stop_exit_no_orphan_equity"
      ~trigger_exit_on:(_date "2024-01-09")
  in
  let last = _last_step result.steps in
  assert_that last
    (all_of
       [
         field
           (fun (s : Trading_simulation_types.Simulator_types.step_result) ->
             s.portfolio.current_cash)
           (float_equal ~epsilon:0.5 100_000.0);
         field
           (fun (s : Trading_simulation_types.Simulator_types.step_result) ->
             s.portfolio_value)
           (float_equal ~epsilon:0.5 100_000.0);
       ])

(* ------------------------------------------------------------------ *)
(* Test 3: strategy-side Position reflects post-split state             *)
(* ------------------------------------------------------------------ *)

(** This pins the new behaviour added by the fix: on the split day, the
    strategy-side [Position.t] (read by the strategy via
    [Portfolio_view.positions]) is split-adjusted in lockstep with the broker
    portfolio. [Holding.quantity] becomes 400 (×4) and [Holding.entry_price]
    becomes $125 (÷4). PRE-FIX both stay at 100 / $500.

    Assertion: read [Position.t] for symbol [TEST] from the {b post-fix}
    [step_result.portfolio_view] equivalent. We don't expose the [Position.t]
    map on [step_result] directly, so we observe the effect indirectly: a lazy
    strategy that {e never} exits would leave the broker with 400 shares at the
    last day. The post-split bar's broker quantity is already pinned by
    [test_split_day_mtm.ml] to 400; this test pins that the strategy-side exit
    (which reads [Holding.quantity]) clears {b all} 400 shares — which is only
    possible if the strategy's [Holding.quantity] is 400.

    Concretely: when [trigger_exit_on_or_after] is the split day itself, the
    strategy emits [TriggerExit] at the close of the split day (after the
    simulator has applied the split), and the order fills the next bar. Pin that
    the post-fill broker holds 0 shares. *)
let test_split_day_position_reflects_post_split _ =
  let result =
    _run_split_exit_simulation
      ~test_name:"split_day_stop_exit_reflects_post_split"
      ~trigger_exit_on:(_date "2024-01-08")
  in
  let last = _last_step result.steps in
  let last_cash_or_value =
    all_of
      [
        field
          (fun (s : Trading_simulation_types.Simulator_types.step_result) ->
            s.portfolio.positions)
          (size_is 0);
        field
          (fun (s : Trading_simulation_types.Simulator_types.step_result) ->
            s.portfolio.current_cash)
          (float_equal ~epsilon:0.5 100_000.0);
      ]
  in
  assert_that last last_cash_or_value

let suite =
  "split_day_stop_exit"
  >::: [
         "post_split_exit_clears_position"
         >:: test_post_split_exit_clears_position;
         "post_split_exit_no_orphan_equity"
         >:: test_post_split_exit_no_orphan_equity;
         "split_day_position_reflects_post_split"
         >:: test_split_day_position_reflects_post_split;
       ]

let () = run_test_tt_main suite
