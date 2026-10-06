(** Sharpe on excess return over the cash yield (#3137 part 1). Without a
    [cash_yield] the computer is unchanged (rf = 0); with one, each period's
    return is reduced by the cash rate accrued over the calendar days the period
    spans. *)

open OUnit2
open Core
open Matchers
open Trading_simulation_types.Metric_types
open Trading_simulation.Simulator
module Metric_computers = Trading_simulation.Metric_computers
module Cash_yield = Trading_simulation_cash_yield.Cash_yield

let _step ~date ~value =
  {
    date = Date.of_string date;
    portfolio = Trading_simulation_types.Portfolio_summary.empty;
    portfolio_value = value;
    trades = [];
    orders_submitted = [];
    splits_applied = [];
    benchmark_return = None;
    had_market_bars = true;
  }

let _config =
  {
    start_date = Date.of_string "2024-01-01";
    end_date = Date.of_string "2024-01-12";
    initial_cash = 10_000.0;
    commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 };
    strategy_cadence = Types.Cadence.Daily;
  }

let _sharpe ?risk_free_rate ?cash_yield steps =
  let c =
    Metric_computers.sharpe_ratio_computer ?risk_free_rate ?cash_yield ()
  in
  Map.find (c.run ~config:_config ~steps) SharpeRatio

(* 36 %/yr with no fee = exactly 0.001 per calendar day (ACT/360). *)
let _cash_rate = Cash_yield.constant ~rate_pct:36.0 ~fee_bp:0.0

let _consecutive_days =
  [
    _step ~date:"2024-01-01" ~value:10_000.0;
    _step ~date:"2024-01-02" ~value:10_100.0;
    _step ~date:"2024-01-03" ~value:10_150.0;
    _step ~date:"2024-01-04" ~value:10_300.0;
  ]

(* On one-day periods the excess is r - 0.001 every period, which is the flat
   annual rf path with rf = 0.001 * 252. *)
let test_excess_matches_flat_rf_on_daily_marks _ =
  let flat = _sharpe ~risk_free_rate:0.252 _consecutive_days in
  assert_that
    (_sharpe ~cash_yield:_cash_rate _consecutive_days)
    (is_some_and (float_equal ~epsilon:1e-9 (Option.value_exn flat)))

let _population_sharpe xs =
  let n = Float.of_int (List.length xs) in
  let mean = List.sum (module Float) xs ~f:Fn.id /. n in
  let var =
    List.sum (module Float) xs ~f:(fun x -> (x -. mean) *. (x -. mean)) /. n
  in
  mean /. Float.sqrt var *. Float.sqrt 252.0

(* Fri -> Mon spans three calendar days, so its period rf is 0.003, not 0.001. *)
let test_weekend_period_charges_calendar_days _ =
  let steps =
    [
      _step ~date:"2024-01-05" ~value:10_000.0;
      _step ~date:"2024-01-08" ~value:10_200.0;
      _step ~date:"2024-01-09" ~value:10_150.0;
      _step ~date:"2024-01-10" ~value:10_300.0;
    ]
  in
  let expected =
    _population_sharpe
      [
        (10_200.0 /. 10_000.0) -. 1.0 -. 0.003;
        (10_150.0 /. 10_200.0) -. 1.0 -. 0.001;
        (10_300.0 /. 10_150.0) -. 1.0 -. 0.001;
      ]
  in
  assert_that
    (_sharpe ~cash_yield:_cash_rate steps)
    (is_some_and (float_equal ~epsilon:1e-9 expected))

(* The rf = 0 path is pinned by the pre-existing Sharpe tests in
   [test_metrics.ml], which this change leaves untouched. *)
let suite =
  "sharpe_excess"
  >::: [
         "excess matches flat rf on daily marks"
         >:: test_excess_matches_flat_rf_on_daily_marks;
         "weekend period charges calendar days"
         >:: test_weekend_period_charges_calendar_days;
       ]

let () = run_test_tt_main suite
