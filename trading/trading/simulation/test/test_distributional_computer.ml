(** Pinned tests for {!Distributional_computer} (M5.2d).

    Each test pins the entire output set against hand-computed values. Test
    inputs are short, hand-pickable curves so all moments / tails fit on paper.
*)

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
    benchmark_return = None;
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
  let computer = Trading_simulation.Distributional_computer.computer () in
  computer.run ~config:_config ~steps

(** Build a synthetic equity curve from a list of consecutive percent returns:
    [seed_value × Π (1 + r_i / 100)]. The first sample is [seed_value], then one
    sample per return — the [N+1]-sample curve produces exactly the [N] input
    returns when fed to the computer. Dates are auto-incremented from
    [2024-01-02] in trading-day order. *)
let _curve_from_returns ?(seed_value = 10_000.0) returns_pct =
  let values =
    List.fold returns_pct ~init:[ seed_value ] ~f:(fun acc r ->
        let prev = List.hd_exn acc in
        let next = prev *. (1.0 +. (r /. 100.0)) in
        next :: acc)
    |> List.rev
  in
  List.mapi values ~f:(fun i v ->
      _make_step ~date:(Date.add_days (_date "2024-01-02") i) ~portfolio_value:v)

(* ==================== Empty / degenerate inputs ==================== *)

let test_empty_steps_yields_zero_metrics _ =
  let metrics = _run [] in
  assert_that metrics
    (map_includes
       [
         (Skewness, float_equal 0.0);
         (Kurtosis, float_equal 0.0);
         (CVaR95, float_equal 0.0);
         (CVaR99, float_equal 0.0);
         (TailRatio, float_equal 0.0);
         (GainToPain, float_equal 0.0);
       ])

(** Single-step input: no returns can be derived. All metrics fall back to zero.
*)
let test_single_step_yields_zero _ =
  let steps =
    [ _make_step ~date:(_date "2024-01-02") ~portfolio_value:10_000.0 ]
  in
  let metrics = _run steps in
  assert_that metrics
    (map_includes
       [
         (Skewness, float_equal 0.0);
         (Kurtosis, float_equal 0.0);
         (TailRatio, float_equal 0.0);
         (GainToPain, float_equal 0.0);
       ])

(** Constant equity curve → all returns 0; variance is 0; skew/kurt fall back to
    0; gain-to-pain falls back to 0 (no gains, no losses). *)
let test_flat_curve _ =
  let steps = _curve_from_returns [ 0.0; 0.0; 0.0; 0.0 ] in
  let metrics = _run steps in
  assert_that metrics
    (map_includes
       [
         (Skewness, float_equal 0.0);
         (Kurtosis, float_equal 0.0);
         (GainToPain, float_equal 0.0);
       ])

(* ==================== Symmetric distribution ==================== *)

(** Returns [-1, +1, -1, +1]. Mean 0; variance 1; m3 = 0; m4 = 1. Skewness = 0 /
    1 = 0. Kurtosis (excess) = (1 / 1) - 3 = -2. The two tail-cut metrics use
    [floor(4 × 0.05) = 0] elements → both fall back to 0.0. GainToPain = 2 / 2 =
    1.0. *)
let test_symmetric_distribution _ =
  let steps = _curve_from_returns [ -1.0; 1.0; -1.0; 1.0 ] in
  let metrics = _run steps in
  assert_that metrics
    (map_includes
       [
         (Skewness, float_equal ~epsilon:1e-6 0.0);
         (Kurtosis, float_equal ~epsilon:1e-6 (-2.0));
         (GainToPain, float_equal ~epsilon:1e-6 1.0);
         (CVaR95, float_equal 0.0);
         (CVaR99, float_equal 0.0);
         (TailRatio, float_equal 0.0);
       ])

(* ==================== Right-skewed distribution ==================== *)

(** Returns [-1, -1, -1, 3]. Mean = 0; variance = ((1 + 1 + 1 + 9) / 4) = 3.
    m3 = (-1 -1 -1 + 27) / 4 = 24 / 4 = 6. Skewness = 6 / pow(3, 1.5) ≈ 1.1547.
    m4 = (1 + 1 + 1 + 81) / 4 = 21. Kurtosis (excess) = 21 / 9 - 3 ≈ -0.6667.
    GainToPain = 3 / 3 = 1.0. *)
let test_right_skewed _ =
  let steps = _curve_from_returns [ -1.0; -1.0; -1.0; 3.0 ] in
  let metrics = _run steps in
  let var = 3.0 in
  let sigma = Float.sqrt var in
  let expected_skew = 6.0 /. (sigma *. sigma *. sigma) in
  let expected_kurt = (21.0 /. (var *. var)) -. 3.0 in
  assert_that metrics
    (map_includes
       [
         (Skewness, float_equal ~epsilon:1e-4 expected_skew);
         (Kurtosis, float_equal ~epsilon:1e-4 expected_kurt);
         (GainToPain, float_equal ~epsilon:1e-6 1.0);
       ])

(* ==================== Tail-cut metrics ==================== *)

(** 100 returns: 95 zeros and 5 large drops of -10%. With 100 samples,
    [floor(100 × 0.05) = 5] → CVaR95 averages the worst 5 (= -10%).
    [floor(100 × 0.01) = 1] → CVaR99 averages the worst 1 (= -10%). Top-5% mean
    = 0 (best 5 are zeros) → TailRatio = 0/10 = 0.0. GainToPain = 0/(5×10) = 0.
*)
let test_cvar_with_known_tail _ =
  let returns =
    List.init 95 ~f:(fun _ -> 0.0) @ List.init 5 ~f:(fun _ -> -10.0)
  in
  let steps = _curve_from_returns returns in
  let metrics = _run steps in
  assert_that metrics
    (map_includes
       [
         (CVaR95, float_equal ~epsilon:1e-6 (-10.0));
         (CVaR99, float_equal ~epsilon:1e-6 (-10.0));
         (TailRatio, float_equal 0.0);
         (GainToPain, float_equal 0.0);
       ])

(** Tail ratio with known top + bottom: 5 returns of +10%, 90 of 0, 5 of -5%.
    Top-5% = 10; Bottom-5% = -5; ratio = 10 / 5 = 2.0. *)
let test_tail_ratio_asymmetric _ =
  let returns =
    List.init 5 ~f:(fun _ -> 10.0)
    @ List.init 90 ~f:(fun _ -> 0.0)
    @ List.init 5 ~f:(fun _ -> -5.0)
  in
  let steps = _curve_from_returns returns in
  let metrics = _run steps in
  assert_that metrics
    (map_includes
       [
         (TailRatio, float_equal ~epsilon:1e-6 2.0);
         (CVaR95, float_equal ~epsilon:1e-6 (-5.0));
       ])

(* ==================== Gain-to-pain edge cases ==================== *)

(** All-positive returns → GainToPain is infinity. *)
let test_gain_to_pain_all_positive_is_infinity _ =
  let steps = _curve_from_returns [ 1.0; 2.0; 3.0 ] in
  let metrics = _run steps in
  assert_that
    (Map.find metrics GainToPain)
    (is_some_and (equal_to Float.infinity))

(** Asymmetric gains/losses: gains sum to 6, losses sum to 2 → GainToPain = 3.0.
*)
let test_gain_to_pain_asymmetric _ =
  let steps = _curve_from_returns [ 1.0; 2.0; 3.0; -2.0 ] in
  let metrics = _run steps in
  let gtp = 6.0 /. 2.0 in
  assert_that
    (Map.find metrics GainToPain)
    (is_some_and (float_equal ~epsilon:1e-6 gtp))

let suite =
  "Distributional_computer"
  >::: [
         "empty steps yields zero metrics"
         >:: test_empty_steps_yields_zero_metrics;
         "single step yields zero" >:: test_single_step_yields_zero;
         "flat curve → all zero" >:: test_flat_curve;
         "symmetric ±1 returns: skew=0, excess kurt=-2, gtp=1.0"
         >:: test_symmetric_distribution;
         "right-skewed [-1,-1,-1,3]: pinned skew + kurt" >:: test_right_skewed;
         "CVaR with known tail (95 zeros + 5 drops of -10)"
         >:: test_cvar_with_known_tail;
         "tail ratio asymmetric (top=+10 / bottom=-5 → 2.0)"
         >:: test_tail_ratio_asymmetric;
         "gain-to-pain all-positive → infinity"
         >:: test_gain_to_pain_all_positive_is_infinity;
         "gain-to-pain asymmetric (6/2 = 3.0)" >:: test_gain_to_pain_asymmetric;
       ]

let () = run_test_tt_main suite
