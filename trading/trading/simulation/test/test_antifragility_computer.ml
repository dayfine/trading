(** Pinned tests for {!Antifragility_computer} (M5.2d).

    Two acceptance gates from the M5.2d plan:

    - convex synthetic strategy ([r_strat = r_bench²]) → γ > 0
    - concave synthetic strategy ([r_strat = -r_bench²]) → γ < 0

    Plus stand-alone defaults (no benchmark → 0.0), and a hand-pinned
    bucket-asymmetry case. *)

open OUnit2
open Core
open Trading_simulation_types.Metric_types
open Matchers
module Simulator_types = Trading_simulation_types.Simulator_types

let _date s = Date.of_string s

let _make_step ?benchmark_return ~date ~portfolio_value () :
    Simulator_types.step_result =
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
    benchmark_return;
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
    Trading_simulation.Antifragility_computer.computer ?benchmark_returns ()
  in
  computer.run ~config:_config ~steps

(** Convert a list of consecutive percent returns into an [N+1]-sample equity
    curve seeded at [10000]. The N returns recovered by the computer match the
    input list. *)
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

(* ==================== No-benchmark default ==================== *)

let test_no_benchmark_yields_zero _ =
  let steps = _curve_from_returns [ 1.0; -2.0; 3.0; -1.0; 2.0; -1.0 ] in
  let metrics = _run steps in
  assert_that metrics
    (map_includes
       [ (ConcavityCoef, float_equal 0.0); (BucketAsymmetry, float_equal 0.0) ])

(* ==================== Insufficient samples ==================== *)

(** Only 4 paired returns → below [_min_paired_samples = 5] → both metrics fall
    back to 0.0. *)
let test_too_few_samples _ =
  let steps = _curve_from_returns [ 1.0; -1.0; 2.0; -2.0 ] in
  let metrics = _run ~benchmark_returns:[ 1.0; -1.0; 2.0; -2.0 ] steps in
  assert_that metrics
    (map_includes
       [ (ConcavityCoef, float_equal 0.0); (BucketAsymmetry, float_equal 0.0) ])

(* ==================== Convex strategy → γ > 0 ==================== *)

(** Convex strategy: [r_strat = r_bench²]. The OLS quadratic fit recovers
    [α = 0, β = 0, γ = 1]. We verify γ > 0 (the acceptance gate from the M5.2d
    plan); we also pin γ ≈ 1.0 within a generous tolerance because the
    constructed inputs satisfy the model exactly. *)
let test_convex_strategy_gamma_positive _ =
  let bench = [ -3.0; -2.0; -1.0; 0.0; 1.0; 2.0; 3.0 ] in
  let strat = List.map bench ~f:(fun r -> r *. r) in
  let steps = _curve_from_returns strat in
  let metrics = _run ~benchmark_returns:bench steps in
  let gamma = Map.find_exn metrics ConcavityCoef in
  assert_that gamma (gt (module Float_ord) 0.0);
  assert_that gamma (float_equal ~epsilon:1e-3 1.0)

(* ==================== Concave strategy → γ < 0 ==================== *)

(** Concave strategy: [r_strat = -r_bench²]. The OLS fit recovers [γ = -1]. *)
let test_concave_strategy_gamma_negative _ =
  let bench = [ -3.0; -2.0; -1.0; 0.0; 1.0; 2.0; 3.0 ] in
  let strat = List.map bench ~f:(fun r -> -.(r *. r)) in
  let steps = _curve_from_returns strat in
  let metrics = _run ~benchmark_returns:bench steps in
  let gamma = Map.find_exn metrics ConcavityCoef in
  assert_that gamma (lt (module Float_ord) 0.0);
  assert_that gamma (float_equal ~epsilon:1e-3 (-1.0))

(* ==================== Linear strategy → γ ≈ 0 ==================== *)

(** Linear strategy: [r_strat = 2 × r_bench]. Quadratic fit recovers [γ ≈ 0]. *)
let test_linear_strategy_gamma_zero _ =
  let bench = [ -3.0; -2.0; -1.0; 0.0; 1.0; 2.0; 3.0 ] in
  let strat = List.map bench ~f:(fun r -> 2.0 *. r) in
  let steps = _curve_from_returns strat in
  let metrics = _run ~benchmark_returns:bench steps in
  let gamma = Map.find_exn metrics ConcavityCoef in
  assert_that gamma (float_equal ~epsilon:1e-3 0.0)

(* ==================== Bucket asymmetry ==================== *)

(* Build 10 paired samples (2 per quintile when sorted by benchmark).
   Benchmarks (sorted): [-5, -4, -3, -2, -1, 1, 2, 3, 4, 5]
   Buckets (Q1..Q5):   [-5,-4] [-3,-2] [-1,1] [2,3] [4,5]
   Strategy values constructed so that bucket means are
     Q1=10, Q2=2, Q3=2, Q4=2, Q5=10
   BucketAsymmetry = (10 + 10) / (2 + 2 + 2) = 20 / 6 ~= 3.3333. *)
let test_bucket_asymmetry_barbell _ =
  let bench = [ -5.0; -4.0; -3.0; -2.0; -1.0; 1.0; 2.0; 3.0; 4.0; 5.0 ] in
  (* Strategy returns in the same chronological position as the benchmarks
     (after sort: Q1 mean 10, Q2 2, Q3 2, Q4 2, Q5 10). *)
  let strat = [ 10.0; 10.0; 2.0; 2.0; 2.0; 2.0; 2.0; 2.0; 10.0; 10.0 ] in
  let steps = _curve_from_returns strat in
  let metrics = _run ~benchmark_returns:bench steps in
  assert_that
    (Map.find metrics BucketAsymmetry)
    (is_some_and (float_equal ~epsilon:1e-3 (20.0 /. 6.0)))

(* ==================== Step-sourced benchmark series ==================== *)

(** Build a benchmark-bearing equity curve. Each step carries
    [benchmark_return = Some r]; portfolio_value follows [strat] returns. The N
    benchmark values populate one fewer step than the curve (the seed step has
    no benchmark — there is no prior bar). *)
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

(** Convex strategy via step-sourced benchmark returns. Same shape as
    {!test_convex_strategy_gamma_positive} but the benchmark series flows
    through [step_result.benchmark_return] instead of an override — pinning the
    production wiring path. *)
let test_step_sourced_benchmark_recovers_convex _ =
  let bench = [ -3.0; -2.0; -1.0; 0.0; 1.0; 2.0; 3.0 ] in
  let strat = List.map bench ~f:(fun r -> r *. r) in
  let steps = _curve_with_step_benchmark ~strat ~bench in
  let metrics = _run steps in
  let gamma = Map.find_exn metrics ConcavityCoef in
  assert_that gamma
    (all_of [ gt (module Float_ord) 0.0; float_equal ~epsilon:1e-3 1.0 ])

(** When both an override and step-sourced benchmark returns are present, the
    override wins. Steps carry [Some 0.0] (linear-flat) but the override
    supplies the convex series — γ should reflect the override (≈ 1.0), not the
    step-sourced flat-line (which would yield γ = 0). *)
let test_override_wins_over_step_benchmark _ =
  let bench = [ -3.0; -2.0; -1.0; 0.0; 1.0; 2.0; 3.0 ] in
  let strat = List.map bench ~f:(fun r -> r *. r) in
  let bench_zeros = List.map bench ~f:(fun _ -> 0.0) in
  let steps = _curve_with_step_benchmark ~strat ~bench:bench_zeros in
  let metrics = _run ~benchmark_returns:bench steps in
  let gamma = Map.find_exn metrics ConcavityCoef in
  assert_that gamma (float_equal ~epsilon:1e-3 1.0)

(** Steps that all carry [benchmark_return = None] (e.g. simulator with no
    benchmark configured) and no override → both metrics emit 0.0. *)
let test_step_benchmark_all_none_yields_zero _ =
  let steps = _curve_from_returns [ 1.0; -2.0; 3.0; -1.0; 2.0; -1.0 ] in
  let metrics = _run steps in
  assert_that metrics
    (map_includes
       [ (ConcavityCoef, float_equal 0.0); (BucketAsymmetry, float_equal 0.0) ])

let suite =
  "Antifragility_computer"
  >::: [
         "no benchmark → both metrics 0.0" >:: test_no_benchmark_yields_zero;
         "too few paired samples → both metrics 0.0" >:: test_too_few_samples;
         "convex strategy (r_strat = r_bench²) → γ > 0"
         >:: test_convex_strategy_gamma_positive;
         "concave strategy (r_strat = -r_bench²) → γ < 0"
         >:: test_concave_strategy_gamma_negative;
         "linear strategy → γ ≈ 0" >:: test_linear_strategy_gamma_zero;
         "bucket asymmetry barbell (Q1+Q5 dominate) → 3.333"
         >:: test_bucket_asymmetry_barbell;
         "step-sourced benchmark recovers convex γ"
         >:: test_step_sourced_benchmark_recovers_convex;
         "override wins over step-sourced benchmark"
         >:: test_override_wins_over_step_benchmark;
         "all step benchmarks None → both metrics 0.0"
         >:: test_step_benchmark_all_none_yields_zero;
       ]

let () = run_test_tt_main suite
