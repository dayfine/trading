(** Pinned tests for {!Drawdown_analytics_computer} (M5.2c).

    Each test pins the entire metric set against a hand-computed value. *)

open OUnit2
open Core
open Trading_simulation_types.Metric_types
open Matchers
module Simulator_types = Trading_simulation_types.Simulator_types

let _date s = Date.of_string s

let _make_step ~date ~portfolio_value : Simulator_types.step_result =
  let portfolio =
    Trading_portfolio.Portfolio.create ~initial_cash:10_000.0 ()
  in
  {
    date;
    portfolio;
    portfolio_value;
    trades = [];
    orders_submitted = [];
    splits_applied = [];
  }

let _config =
  {
    Simulator_types.start_date = _date "2024-01-01";
    end_date = _date "2024-12-31";
    initial_cash = 10_000.0;
    commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 };
    strategy_cadence = Types.Cadence.Daily;
  }

let _run steps =
  let computer = Trading_simulation.Drawdown_analytics_computer.computer () in
  computer.run ~config:_config ~steps

(* ----- Empty input ----- *)

let test_empty_steps_yields_zero_metrics _ =
  let metrics = _run [] in
  assert_that metrics
    (map_includes
       [
         (AvgDrawdownPct, float_equal 0.0);
         (MedianDrawdownPct, float_equal 0.0);
         (MaxDrawdownDurationDays, float_equal 0.0);
         (AvgDrawdownDurationDays, float_equal 0.0);
         (TimeInDrawdownPct, float_equal 0.0);
         (UlcerIndex, float_equal 0.0);
         (PainIndex, float_equal 0.0);
         (UnderwaterCurveArea, float_equal 0.0);
       ])

(* ----- Monotonically rising equity → no drawdown ----- *)

(** Three rising days. Every day is a new peak; per_day_dd = [0,0,0]; no closed
    episodes; no in-progress episode (the final day is itself a new peak). All
    metrics reduce to zero. *)
let test_monotonic_up _ =
  let steps =
    [
      _make_step ~date:(_date "2024-01-02") ~portfolio_value:10_000.0;
      _make_step ~date:(_date "2024-01-03") ~portfolio_value:10_500.0;
      _make_step ~date:(_date "2024-01-04") ~portfolio_value:11_000.0;
    ]
  in
  let metrics = _run steps in
  assert_that metrics
    (map_includes
       [
         (AvgDrawdownPct, float_equal 0.0);
         (MaxDrawdownDurationDays, float_equal 0.0);
         (TimeInDrawdownPct, float_equal 0.0);
         (UlcerIndex, float_equal 0.0);
         (PainIndex, float_equal 0.0);
         (UnderwaterCurveArea, float_equal 0.0);
       ])

(* ----- Hand-pinned 5-day curve with one closed + one trailing episode ----- *)

(** Equity curve: [10000, 9000, 9500, 11000, 10000] on consecutive trading days
    2024-01-02..06.

    Per-day drawdown:
    - 2024-01-02: peak=10000, dd=0%
    - 2024-01-03: peak=10000, dd=10%
    - 2024-01-04: peak=10000, dd=5%
    - 2024-01-05: peak=11000 (new high), dd=0% — closes episode 1
    - 2024-01-06: peak=11000, dd = (11000-10000)/11000 × 100 ≈ 9.0909%

    Episodes:
    - E1: peak_date=2024-01-02, end=2024-01-05, max_depth=10%, duration = 3
    - E2 (trailing): peak_date=2024-01-05, end=2024-01-06, max_depth ≈ 9.0909%,
      duration = 1.

    Avg / median depth: (10 + 9.0909) / 2 ≈ 9.5455%. (Two-element median is the
    mean of the two values.)

    Avg duration = (3 + 1) / 2 = 2; max duration = 3.

    Per-day (n=5):
    - n_underwater = 3 → TimeInDrawdownPct = 60%.
    - PainIndex (mean of [0, 10, 5, 0, 9.0909]) = 24.0909 / 5 ≈ 4.8182%.
    - UnderwaterCurveArea = PainIndex × 5 ≈ 24.0909 (percent · days).
    - UlcerIndex = sqrt(mean of [0, 100, 25, 0, 82.6446]) = sqrt(207.6446 / 5) =
      sqrt(41.5289) ≈ 6.4443. *)
let test_one_closed_one_trailing_episode _ =
  let steps =
    [
      _make_step ~date:(_date "2024-01-02") ~portfolio_value:10_000.0;
      _make_step ~date:(_date "2024-01-03") ~portfolio_value:9_000.0;
      _make_step ~date:(_date "2024-01-04") ~portfolio_value:9_500.0;
      _make_step ~date:(_date "2024-01-05") ~portfolio_value:11_000.0;
      _make_step ~date:(_date "2024-01-06") ~portfolio_value:10_000.0;
    ]
  in
  let metrics = _run steps in
  let trailing_dd_pct = (11_000.0 -. 10_000.0) /. 11_000.0 *. 100.0 in
  let avg_dd = (10.0 +. trailing_dd_pct) /. 2.0 in
  let pain = (0.0 +. 10.0 +. 5.0 +. 0.0 +. trailing_dd_pct) /. 5.0 in
  let underwater_area = pain *. 5.0 in
  let mean_sq =
    (0.0 +. (10.0 *. 10.0) +. (5.0 *. 5.0) +. 0.0
    +. (trailing_dd_pct *. trailing_dd_pct))
    /. 5.0
  in
  let ulcer = Float.sqrt mean_sq in
  assert_that metrics
    (map_includes
       [
         (AvgDrawdownPct, float_equal ~epsilon:1e-6 avg_dd);
         (MedianDrawdownPct, float_equal ~epsilon:1e-6 avg_dd);
         (MaxDrawdownDurationDays, float_equal 3.0);
         (AvgDrawdownDurationDays, float_equal 2.0);
         (TimeInDrawdownPct, float_equal ~epsilon:1e-6 60.0);
         (PainIndex, float_equal ~epsilon:1e-6 pain);
         (UnderwaterCurveArea, float_equal ~epsilon:1e-6 underwater_area);
         (UlcerIndex, float_equal ~epsilon:1e-6 ulcer);
       ])

(* ----- Single never-recovers episode ----- *)

(** Three days, monotonic decline: [10000, 9000, 8500]. Single trailing episode
    that never recovers.
    - peak_date = day 1, end = day 3, max_depth = 15%, duration = 2.
    - Per-day dd = [0, 10, 15]; n=5? No — n=3.
    - TimeInDrawdownPct = 2/3 × 100 ≈ 66.6667.
    - PainIndex = (0 + 10 + 15)/3 = 25/3 ≈ 8.3333.
    - UnderwaterCurveArea = 25.0.
    - UlcerIndex = sqrt((0 + 100 + 225)/3) = sqrt(108.3333) ≈ 10.4083.
    - AvgDrawdownPct = MedianDrawdownPct = 15 (single episode). *)
let test_never_recovers _ =
  let steps =
    [
      _make_step ~date:(_date "2024-01-02") ~portfolio_value:10_000.0;
      _make_step ~date:(_date "2024-01-03") ~portfolio_value:9_000.0;
      _make_step ~date:(_date "2024-01-04") ~portfolio_value:8_500.0;
    ]
  in
  let metrics = _run steps in
  assert_that metrics
    (map_includes
       [
         (AvgDrawdownPct, float_equal ~epsilon:1e-6 15.0);
         (MedianDrawdownPct, float_equal ~epsilon:1e-6 15.0);
         (MaxDrawdownDurationDays, float_equal 2.0);
         (AvgDrawdownDurationDays, float_equal 2.0);
         (TimeInDrawdownPct, float_equal ~epsilon:1e-6 (2.0 /. 3.0 *. 100.0));
         (PainIndex, float_equal ~epsilon:1e-6 (25.0 /. 3.0));
         (UnderwaterCurveArea, float_equal ~epsilon:1e-6 25.0);
         (UlcerIndex, float_equal ~epsilon:1e-6 (Float.sqrt (325.0 /. 3.0)));
       ])

let suite =
  "Drawdown_analytics_computer"
  >::: [
         "empty steps yields zero metrics"
         >:: test_empty_steps_yields_zero_metrics;
         "monotonically up → no drawdown" >:: test_monotonic_up;
         "5-day curve with one closed + one trailing episode"
         >:: test_one_closed_one_trailing_episode;
         "never-recovers single episode" >:: test_never_recovers;
       ]

let () = run_test_tt_main suite
