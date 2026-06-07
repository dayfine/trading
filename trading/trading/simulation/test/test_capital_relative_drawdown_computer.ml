(** Pinned tests for {!Capital_relative_drawdown_computer}.

    Each test pins [MaxUnderwaterVsInitialPct] against a hand-computed value. *)

open OUnit2
open Core
open Trading_simulation_types.Metric_types
open Matchers
module Simulator_types = Trading_simulation_types.Simulator_types

let _date s = Date.of_string s

let _make_step ~date ~portfolio_value : Simulator_types.step_result =
  {
    date;
    portfolio = Trading_simulation_types.Portfolio_summary.empty;
    portfolio_value;
    trades = [];
    orders_submitted = [];
    splits_applied = [];
    benchmark_return = None;
    had_market_bars = true;
  }

let _config =
  {
    Simulator_types.start_date = _date "2024-01-01";
    end_date = _date "2024-12-31";
    initial_cash = 1_000.0;
    commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 };
    strategy_cadence = Types.Cadence.Daily;
  }

let _run ?initial_cash steps =
  let computer =
    Trading_simulation.Capital_relative_drawdown_computer.computer ?initial_cash
      ()
  in
  computer.run ~config:_config ~steps

(* ----- NAV dips below initial → positive metric ----- *)

(** Initial 1000; curve [1000, 900, 850, 950]. Worst NAV is 850, so the worst
    shortfall vs initial is (1000 - 850) / 1000 × 100 = 15%. *)
let test_dips_below_initial _ =
  let steps =
    [
      _make_step ~date:(_date "2024-01-02") ~portfolio_value:1_000.0;
      _make_step ~date:(_date "2024-01-03") ~portfolio_value:900.0;
      _make_step ~date:(_date "2024-01-04") ~portfolio_value:850.0;
      _make_step ~date:(_date "2024-01-05") ~portfolio_value:950.0;
    ]
  in
  let metrics = _run ~initial_cash:1_000.0 steps in
  assert_that metrics
    (map_includes
       [ (MaxUnderwaterVsInitialPct, float_equal ~epsilon:1e-6 15.0) ])

(* ----- 2× then halve but stays at/above initial → metric 0 ----- *)

(** Initial 1000; curve [1000, 2000, 1000]. The peak-relative max drawdown would
    be 50% (2000 → 1000), but the NAV never falls below the initial stake, so
    the capital-relative metric is 0. This is the key contrast with
    [MaxDrawdown]. *)
let test_doubles_then_halves_stays_at_initial _ =
  let steps =
    [
      _make_step ~date:(_date "2024-01-02") ~portfolio_value:1_000.0;
      _make_step ~date:(_date "2024-01-03") ~portfolio_value:2_000.0;
      _make_step ~date:(_date "2024-01-04") ~portfolio_value:1_000.0;
    ]
  in
  let metrics = _run ~initial_cash:1_000.0 steps in
  assert_that metrics
    (map_includes [ (MaxUnderwaterVsInitialPct, float_equal 0.0) ])

(* ----- initial_cash absent → 0.0 ----- *)

let test_no_initial_cash_yields_zero _ =
  let steps =
    [
      _make_step ~date:(_date "2024-01-02") ~portfolio_value:1_000.0;
      _make_step ~date:(_date "2024-01-03") ~portfolio_value:500.0;
    ]
  in
  let metrics = _run steps in
  assert_that metrics
    (map_includes [ (MaxUnderwaterVsInitialPct, float_equal 0.0) ])

(* ----- initial_cash <= 0 → 0.0 ----- *)

let test_nonpositive_initial_cash_yields_zero _ =
  let steps =
    [ _make_step ~date:(_date "2024-01-02") ~portfolio_value:500.0 ]
  in
  let metrics = _run ~initial_cash:0.0 steps in
  assert_that metrics
    (map_includes [ (MaxUnderwaterVsInitialPct, float_equal 0.0) ])

let suite =
  "Capital_relative_drawdown_computer"
  >::: [
         "NAV dips below initial → positive metric" >:: test_dips_below_initial;
         "2× then halve but stays at initial → 0"
         >:: test_doubles_then_halves_stays_at_initial;
         "initial_cash absent → 0" >:: test_no_initial_cash_yields_zero;
         "initial_cash <= 0 → 0" >:: test_nonpositive_initial_cash_yields_zero;
       ]

let () = run_test_tt_main suite
