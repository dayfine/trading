open OUnit2
open Matchers
open Backtest_stats

(* Population moments of a known symmetric series [1;2;3;4;5]: skew 0, non-excess
   kurtosis 1.7 (platykurtic). Pins the moment helpers against hand-computed
   values. *)
let test_skewness_kurtosis_symmetric _ =
  assert_that
    (Deflated_sharpe.skewness [ 1.0; 2.0; 3.0; 4.0; 5.0 ])
    (float_equal ~epsilon:1e-9 0.0);
  assert_that
    (Deflated_sharpe.kurtosis [ 1.0; 2.0; 3.0; 4.0; 5.0 ])
    (float_equal ~epsilon:1e-9 1.7)

(* Left-skewed series [-2;0;1;1]: skew -0.8164965809, kurt 2.0. *)
let test_skewness_kurtosis_skewed _ =
  assert_that
    (Deflated_sharpe.skewness [ -2.0; 0.0; 1.0; 1.0 ])
    (float_equal ~epsilon:1e-9 (-0.8164965809));
  assert_that
    (Deflated_sharpe.kurtosis [ -2.0; 0.0; 1.0; 1.0 ])
    (float_equal ~epsilon:1e-9 2.0)

let test_moments_reject_short _ =
  assert_raises
    (Invalid_argument "Deflated_sharpe: need at least 2 observations, got 1")
    (fun () -> Deflated_sharpe.skewness [ 1.0 ])

let test_moments_reject_zero_variance _ =
  assert_raises
    (Invalid_argument "Deflated_sharpe: zero variance, higher moment undefined")
    (fun () -> Deflated_sharpe.kurtosis [ 3.0; 3.0; 3.0 ])

(* PSR closed form against hand-computed Bailey/Lopez de Prado values.
   Fixture A: SR_hat=0.5, SR*=0, T=24, normal (g3=0, g4=3) -> 0.9881134547.
   Fixture B: same but SR*=0.3 -> 0.8170846532 (higher benchmark, lower prob).
   Fixture C: non-normal SR_hat=0.8, SR*=0.2, T=36, g3=-0.5, g4=4 ->
   0.9951851034. *)
let test_psr_normal_zero_benchmark _ =
  assert_that
    (Deflated_sharpe.psr ~observed_sharpe:0.5 ~benchmark_sharpe:0.0 ~n_obs:24
       ~skewness:0.0 ~kurtosis:3.0)
    (float_equal ~epsilon:1e-9 0.9881134547)

let test_psr_positive_benchmark _ =
  assert_that
    (Deflated_sharpe.psr ~observed_sharpe:0.5 ~benchmark_sharpe:0.3 ~n_obs:24
       ~skewness:0.0 ~kurtosis:3.0)
    (float_equal ~epsilon:1e-9 0.8170846532)

let test_psr_non_normal _ =
  assert_that
    (Deflated_sharpe.psr ~observed_sharpe:0.8 ~benchmark_sharpe:0.2 ~n_obs:36
       ~skewness:(-0.5) ~kurtosis:4.0)
    (float_equal ~epsilon:1e-9 0.9951851034)

let test_psr_rejects_one_obs _ =
  assert_raises
    (Invalid_argument "Deflated_sharpe.psr: n_obs must be >= 2, got 1")
    (fun () ->
      Deflated_sharpe.psr ~observed_sharpe:0.5 ~benchmark_sharpe:0.0 ~n_obs:1
        ~skewness:0.0 ~kurtosis:3.0)

(* expected_max_sharpe: N=12, var=0.04 -> 0.3329622776; N=10, var=0.01 ->
   0.1574598301. *)
let test_expected_max_sharpe _ =
  assert_that
    (Deflated_sharpe.expected_max_sharpe ~n_trials:12 ~sharpe_variance:0.04)
    (float_equal ~epsilon:1e-9 0.3329622776);
  assert_that
    (Deflated_sharpe.expected_max_sharpe ~n_trials:10 ~sharpe_variance:0.01)
    (float_equal ~epsilon:1e-9 0.1574598301)

(* Best-of-N is undefined with a single trial: there is no selection bias to
   correct, so the contract raises rather than returning a misleading value. *)
let test_expected_max_sharpe_rejects_one_trial _ =
  assert_raises
    (Invalid_argument
       "Deflated_sharpe.expected_max_sharpe: n_trials must be >= 2, got 1")
    (fun () ->
      Deflated_sharpe.expected_max_sharpe ~n_trials:1 ~sharpe_variance:0.04)

(* End-to-end DSR: observed=0.5, fold_returns [1;2;3;4;5] (T=5, skew 0, kurt
   1.7), N=12, variance 0.04. The benchmark SR_star is 0.3329622776, then PSR at
   that benchmark is 0.6281656469. The DSR (0.628) is well below the raw PSR
   against a zero benchmark (0.988), showing the best-of-12 deflation at work. *)
let test_deflated_sharpe_end_to_end _ =
  assert_that
    (Deflated_sharpe.deflated_sharpe ~observed_sharpe:0.5
       ~fold_returns:[ 1.0; 2.0; 3.0; 4.0; 5.0 ]
       ~n_trials:12 ~sharpe_variance_across_trials:0.04)
    (float_equal ~epsilon:1e-9 0.6281656469)

(* Degenerate guard propagates from the inner moment computation: zero-variance
   fold returns make skewness/kurtosis undefined. *)
let test_deflated_sharpe_rejects_zero_variance_folds _ =
  assert_raises
    (Invalid_argument "Deflated_sharpe: zero variance, higher moment undefined")
    (fun () ->
      Deflated_sharpe.deflated_sharpe ~observed_sharpe:0.5
        ~fold_returns:[ 2.0; 2.0; 2.0 ] ~n_trials:12
        ~sharpe_variance_across_trials:0.04)

let suite =
  "deflated_sharpe"
  >::: [
         "skewness_kurtosis_symmetric" >:: test_skewness_kurtosis_symmetric;
         "skewness_kurtosis_skewed" >:: test_skewness_kurtosis_skewed;
         "moments_reject_short" >:: test_moments_reject_short;
         "moments_reject_zero_variance" >:: test_moments_reject_zero_variance;
         "psr_normal_zero_benchmark" >:: test_psr_normal_zero_benchmark;
         "psr_positive_benchmark" >:: test_psr_positive_benchmark;
         "psr_non_normal" >:: test_psr_non_normal;
         "psr_rejects_one_obs" >:: test_psr_rejects_one_obs;
         "expected_max_sharpe" >:: test_expected_max_sharpe;
         "expected_max_sharpe_rejects_one_trial"
         >:: test_expected_max_sharpe_rejects_one_trial;
         "deflated_sharpe_end_to_end" >:: test_deflated_sharpe_end_to_end;
         "deflated_sharpe_rejects_zero_variance_folds"
         >:: test_deflated_sharpe_rejects_zero_variance_folds;
       ]

let () = run_test_tt_main suite
