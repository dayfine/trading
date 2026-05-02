(** Pinned tests for {!Return_basics_computer} (M5.2b).

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
  let computer = Trading_simulation.Return_basics_computer.computer () in
  computer.run ~config:_config ~steps

(* ----- Empty input ----- *)

let test_empty_steps_yields_zero_metrics _ =
  let metrics = _run [] in
  assert_that metrics
    (map_includes
       [
         (TotalReturnPct, float_equal 0.0);
         (VolatilityPctAnnualized, float_equal 0.0);
         (DownsideDeviationPctAnnualized, float_equal 0.0);
         (BestDayPct, float_equal 0.0);
         (WorstDayPct, float_equal 0.0);
         (BestWeekPct, float_equal 0.0);
         (WorstWeekPct, float_equal 0.0);
       ])

(* ----- Total return ----- *)

(** Three steps, portfolio walks 10000 → 11000 → 12000. Total return = (12000 -
    10000) / 10000 × 100 = 20%. *)
let test_total_return_pct _ =
  let steps =
    [
      _make_step ~date:(_date "2024-01-02") ~portfolio_value:10_000.0;
      _make_step ~date:(_date "2024-01-03") ~portfolio_value:11_000.0;
      _make_step ~date:(_date "2024-01-04") ~portfolio_value:12_000.0;
    ]
  in
  let metrics = _run steps in
  assert_that (Map.find metrics TotalReturnPct) (is_some_and (float_equal 20.0))

(* ----- Best/worst day ----- *)

(** Day-over-day returns:
    - 10000 → 10500 = +5.0%
    - 10500 → 9975 = -5.0% (= -525 / 10500)
    - 9975 → 11_172.0 = +12.0% (= +1197 / 9975)

    Best day = +12, worst day = -5. *)
let test_best_worst_day _ =
  let steps =
    [
      _make_step ~date:(_date "2024-01-02") ~portfolio_value:10_000.0;
      _make_step ~date:(_date "2024-01-03") ~portfolio_value:10_500.0;
      _make_step ~date:(_date "2024-01-04") ~portfolio_value:9_975.0;
      _make_step ~date:(_date "2024-01-05") ~portfolio_value:11_172.0;
    ]
  in
  let metrics = _run steps in
  assert_that metrics
    (map_includes
       [
         (BestDayPct, float_equal ~epsilon:1e-6 12.0);
         (WorstDayPct, float_equal ~epsilon:1e-6 (-5.0));
       ])

(* ----- Volatility ----- *)

(** Two steps with returns [+5%, -5%]. mean = 0, stdev (popn) = sqrt((25 + 25) /
    2) = 5. Annualized = 5 × sqrt(252) ≈ 79.3725%. Downside dev: only negative
    returns count (positive clipped to 0): values [0, -5], mean = -2.5,
    popn-stdev = sqrt((6.25 + 6.25) / 2) = 2.5; annualized = 2.5 × sqrt(252) ≈
    39.6863%. *)
let test_volatility_and_downside _ =
  let steps =
    [
      _make_step ~date:(_date "2024-01-02") ~portfolio_value:10_000.0;
      _make_step ~date:(_date "2024-01-03") ~portfolio_value:10_500.0;
      _make_step ~date:(_date "2024-01-04") ~portfolio_value:9_975.0;
    ]
  in
  let metrics = _run steps in
  let sqrt_252 = Float.sqrt 252.0 in
  let expected_vol = 5.0 *. sqrt_252 in
  let expected_dd = 2.5 *. sqrt_252 in
  assert_that metrics
    (map_includes
       [
         (VolatilityPctAnnualized, float_equal ~epsilon:1e-6 expected_vol);
         (DownsideDeviationPctAnnualized, float_equal ~epsilon:1e-6 expected_dd);
       ])

(* ----- Calendar bucket extremes ----- *)

(** Two months: Jan ends at 11000 (+10% from 10000), Feb ends at 9900 (-10% from
    11000). Best month = +10, worst month = -10. *)
let test_best_worst_month _ =
  let steps =
    [
      _make_step ~date:(_date "2024-01-02") ~portfolio_value:10_000.0;
      _make_step ~date:(_date "2024-01-15") ~portfolio_value:10_500.0;
      _make_step ~date:(_date "2024-01-31") ~portfolio_value:11_000.0;
      _make_step ~date:(_date "2024-02-15") ~portfolio_value:10_400.0;
      _make_step ~date:(_date "2024-02-29") ~portfolio_value:9_900.0;
    ]
  in
  let metrics = _run steps in
  assert_that metrics
    (map_includes
       [
         (BestMonthPct, float_equal ~epsilon:1e-6 10.0);
         (WorstMonthPct, float_equal ~epsilon:1e-6 (-10.0));
       ])

(** Two years to validate quarter + year bucketing.

    Bucket end-values (last sample within each bucket, chronological):
    - 2024 Q1: 11000 (2024-03-30)
    - 2024 Q4: 11000 (2024-12-31)
    - 2025 Q1: 12000 (2025-03-30)
    - 2025 Q4: 12000 (2025-12-31)
    - Year 2024: 11000 (last 2024 sample)
    - Year 2025: 12000

    The first bucket compounds against [initial_value] (= 10000, the first
    sample). Subsequent buckets compound against the previous bucket's last
    value.

    Year returns: 2024 = (11000-10000)/10000 = +10%; 2025 = (12000-11000)/11000
    ≈ +9.0909%. Best year = 10, worst year = 9.0909.

    Quarter returns: 2024-Q1 = +10% (vs 10000), 2024-Q4 = 0% (11000→11000),
    2025-Q1 ≈ +9.0909% (11000→12000), 2025-Q4 = 0% (12000→12000). Best quarter =
    +10, worst quarter = 0. *)
let test_best_worst_year_and_quarter _ =
  let steps =
    [
      _make_step ~date:(_date "2024-01-02") ~portfolio_value:10_000.0;
      _make_step ~date:(_date "2024-03-30") ~portfolio_value:11_000.0;
      _make_step ~date:(_date "2024-12-31") ~portfolio_value:11_000.0;
      _make_step ~date:(_date "2025-03-30") ~portfolio_value:12_000.0;
      _make_step ~date:(_date "2025-12-31") ~portfolio_value:12_000.0;
    ]
  in
  let metrics = _run steps in
  let year_2025_return = (12_000.0 -. 11_000.0) /. 11_000.0 *. 100.0 in
  assert_that metrics
    (map_includes
       [
         (BestYearPct, float_equal ~epsilon:1e-6 10.0);
         (WorstYearPct, float_equal ~epsilon:1e-6 year_2025_return);
         (BestQuarterPct, float_equal ~epsilon:1e-6 10.0);
         (WorstQuarterPct, float_equal ~epsilon:1e-6 0.0);
       ])

let suite =
  "Return_basics_computer"
  >::: [
         "empty steps yields zero metrics"
         >:: test_empty_steps_yields_zero_metrics;
         "total_return_pct" >:: test_total_return_pct;
         "best/worst day" >:: test_best_worst_day;
         "volatility + downside dev (annualized)"
         >:: test_volatility_and_downside;
         "best/worst month" >:: test_best_worst_month;
         "best/worst year + best quarter" >:: test_best_worst_year_and_quarter;
       ]

let () = run_test_tt_main suite
