(** Pinned tests for {!Benchmark_relative_computer}.

    Coverage:
    - no benchmark series → all five metrics 0.0
    - <5 paired samples → all five metrics 0.0
    - perfect linear (r_strat = 2 · r_bench) → β=2, α=0, corr=1
    - identical series (r_strat = r_bench) → β=1, α=0, corr=1, TE=0
    - zero variance benchmark → β=0, α=0, corr=0
    - step-sourced benchmark and override-wins paths *)

open OUnit2
open Core
open Trading_simulation_types.Metric_types
open Matchers
module Simulator_types = Trading_simulation_types.Simulator_types

let _date s = Date.of_string s

let _make_step ?benchmark_return ~date ~portfolio_value () :
    Simulator_types.step_result =
  {
    date;
    portfolio = Trading_simulation_types.Portfolio_summary.empty;
    portfolio_value;
    trades = [];
    orders_submitted = [];
    splits_applied = [];
    benchmark_return;
    had_market_bars = true;
  }

let _config =
  {
    Simulator_types.start_date = _date "2024-01-01";
    end_date = _date "2024-12-31";
    initial_cash = 10_000.0;
    commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 };
    strategy_cadence = Types.Cadence.Daily;
  }

let _run ?benchmark_returns steps =
  let computer =
    Trading_simulation.Benchmark_relative_computer.computer ?benchmark_returns
      ()
  in
  computer.run ~config:_config ~steps

let _curve_from_returns ?(seed_value = 10_000.0) returns_pct =
  let values =
    List.fold returns_pct ~init:[ seed_value ] ~f:(fun acc r ->
        let prev = List.hd_exn acc in
        let next = prev *. (1.0 +. (r /. 100.0)) in
        next :: acc)
    |> List.rev
  in
  List.mapi values ~f:(fun i v ->
      _make_step
        ~date:(Date.add_days (_date "2024-01-02") i)
        ~portfolio_value:v ())

let _curve_with_step_benchmark ~strat ~bench =
  let values =
    List.fold strat ~init:[ 10_000.0 ] ~f:(fun acc r ->
        let prev = List.hd_exn acc in
        let next = prev *. (1.0 +. (r /. 100.0)) in
        next :: acc)
    |> List.rev
  in
  List.mapi values ~f:(fun i v ->
      let benchmark_return = if i = 0 then None else List.nth bench (i - 1) in
      _make_step ?benchmark_return
        ~date:(Date.add_days (_date "2024-01-02") i)
        ~portfolio_value:v ())

let test_no_benchmark_yields_zero _ =
  let steps = _curve_from_returns [ 1.0; -2.0; 3.0; -1.0; 2.0; -1.0 ] in
  let metrics = _run steps in
  assert_that metrics
    (map_includes
       [
         (BenchmarkAlphaPctAnnualized, float_equal 0.0);
         (BenchmarkBeta, float_equal 0.0);
         (TrackingErrorPctAnnualized, float_equal 0.0);
         (InformationRatio, float_equal 0.0);
         (CorrelationToBenchmark, float_equal 0.0);
       ])

let test_too_few_samples _ =
  let steps = _curve_from_returns [ 1.0; -1.0; 2.0; -2.0 ] in
  let metrics = _run ~benchmark_returns:[ 1.0; -1.0; 2.0; -2.0 ] steps in
  assert_that metrics
    (map_includes
       [
         (BenchmarkAlphaPctAnnualized, float_equal 0.0);
         (BenchmarkBeta, float_equal 0.0);
         (CorrelationToBenchmark, float_equal 0.0);
       ])

let test_identical_series _ =
  let bench = [ 0.5; -0.3; 0.7; -0.2; 0.4; -0.5; 0.1 ] in
  let steps = _curve_from_returns bench in
  let metrics = _run ~benchmark_returns:bench steps in
  assert_that
    (Map.find_exn metrics BenchmarkBeta)
    (float_equal ~epsilon:1e-6 1.0);
  assert_that
    (Map.find_exn metrics BenchmarkAlphaPctAnnualized)
    (float_equal ~epsilon:1e-6 0.0);
  assert_that
    (Map.find_exn metrics CorrelationToBenchmark)
    (float_equal ~epsilon:1e-6 1.0);
  assert_that
    (Map.find_exn metrics TrackingErrorPctAnnualized)
    (float_equal ~epsilon:1e-6 0.0)

let test_perfect_linear_2x _ =
  let bench = [ 0.5; -0.3; 0.7; -0.2; 0.4; -0.5; 0.1 ] in
  let strat = List.map bench ~f:(fun r -> 2.0 *. r) in
  let steps = _curve_from_returns strat in
  let metrics = _run ~benchmark_returns:bench steps in
  assert_that
    (Map.find_exn metrics BenchmarkBeta)
    (float_equal ~epsilon:1e-3 2.0);
  assert_that
    (Map.find_exn metrics BenchmarkAlphaPctAnnualized)
    (float_equal ~epsilon:1e-3 0.0);
  assert_that
    (Map.find_exn metrics CorrelationToBenchmark)
    (float_equal ~epsilon:1e-3 1.0)

let test_zero_variance_benchmark _ =
  let bench = [ 0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0 ] in
  let strat = [ 0.5; -0.3; 0.7; -0.2; 0.4; -0.5; 0.1 ] in
  let steps = _curve_from_returns strat in
  let metrics = _run ~benchmark_returns:bench steps in
  assert_that
    (Map.find_exn metrics BenchmarkBeta)
    (float_equal ~epsilon:1e-9 0.0);
  assert_that
    (Map.find_exn metrics CorrelationToBenchmark)
    (float_equal ~epsilon:1e-9 0.0)

let test_override_wins_over_step_benchmark _ =
  let bench = [ 0.5; -0.3; 0.7; -0.2; 0.4; -0.5; 0.1 ] in
  let strat = List.map bench ~f:(fun r -> 2.0 *. r) in
  let bench_zeros = List.map bench ~f:(fun _ -> 0.0) in
  let steps = _curve_with_step_benchmark ~strat ~bench:bench_zeros in
  let metrics = _run ~benchmark_returns:bench steps in
  assert_that
    (Map.find_exn metrics BenchmarkBeta)
    (float_equal ~epsilon:1e-3 2.0)

let test_step_sourced_benchmark _ =
  let bench = [ 0.5; -0.3; 0.7; -0.2; 0.4; -0.5; 0.1 ] in
  let strat = List.map bench ~f:(fun r -> 1.5 *. r) in
  let steps = _curve_with_step_benchmark ~strat ~bench in
  let metrics = _run steps in
  assert_that
    (Map.find_exn metrics BenchmarkBeta)
    (float_equal ~epsilon:1e-3 1.5)

let suite =
  "Benchmark_relative_computer"
  >::: [
         "no benchmark → all metrics 0.0" >:: test_no_benchmark_yields_zero;
         "<5 paired samples → metrics 0.0" >:: test_too_few_samples;
         "identical series → β=1, α=0, corr=1, TE=0" >:: test_identical_series;
         "perfect linear 2× → β=2, α=0, corr=1" >:: test_perfect_linear_2x;
         "zero-variance benchmark → β=0, corr=0"
         >:: test_zero_variance_benchmark;
         "override wins over step-sourced benchmark"
         >:: test_override_wins_over_step_benchmark;
         "step-sourced benchmark recovers β" >:: test_step_sourced_benchmark;
       ]

let () = run_test_tt_main suite
