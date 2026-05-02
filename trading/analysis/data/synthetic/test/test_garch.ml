open OUnit2
open Core
open Matchers
open Synthetic

(* Bull-like default: low vol, high persistence, stationary. *)
let _bull_params : Garch.params = { omega = 1e-6; alpha = 0.05; beta = 0.93 }

(* ------------------------------------------------------------------ *)
(* Validation                                                           *)
(* ------------------------------------------------------------------ *)

let test_validate_default_ok _ = assert_that (Garch.validate _bull_params) is_ok

let test_validate_rejects_zero_omega _ =
  assert_that
    (Garch.validate { _bull_params with omega = 0.0 })
    (is_error_with Status.Invalid_argument)

let test_validate_rejects_negative_alpha _ =
  assert_that
    (Garch.validate { _bull_params with alpha = -0.01 })
    (is_error_with Status.Invalid_argument)

let test_validate_rejects_non_stationary _ =
  assert_that
    (Garch.validate { omega = 1e-6; alpha = 0.6; beta = 0.5 })
    (is_error_with Status.Invalid_argument)

(* ------------------------------------------------------------------ *)
(* Long-run variance                                                    *)
(* ------------------------------------------------------------------ *)

let test_long_run_variance_default _ =
  (* omega / (1 - alpha - beta) = 1e-6 / 0.02 = 5e-5 *)
  assert_that
    (Garch.long_run_variance _bull_params)
    (is_some_and (float_equal 5e-5))

let test_long_run_variance_non_stationary_is_none _ =
  assert_that
    (Garch.long_run_variance { omega = 1e-6; alpha = 0.6; beta = 0.5 })
    is_none

(* ------------------------------------------------------------------ *)
(* Sampling                                                             *)
(* ------------------------------------------------------------------ *)

let test_sample_returns_zero_steps_is_empty _ =
  assert_that
    (Garch.sample_returns _bull_params ~n_steps:0 ~seed:1 ~initial_variance:5e-5)
    is_empty

let test_sample_returns_length_matches _ =
  let returns =
    Garch.sample_returns _bull_params ~n_steps:200 ~seed:42
      ~initial_variance:5e-5
  in
  assert_that returns (size_is 200)

let test_sample_returns_deterministic _ =
  let r1 =
    Garch.sample_returns _bull_params ~n_steps:200 ~seed:42
      ~initial_variance:5e-5
  in
  let r2 =
    Garch.sample_returns _bull_params ~n_steps:200 ~seed:42
      ~initial_variance:5e-5
  in
  assert_that (List.equal Float.equal r1 r2) (equal_to true)

let test_sample_returns_finite _ =
  let returns =
    Garch.sample_returns _bull_params ~n_steps:1000 ~seed:99
      ~initial_variance:5e-5
  in
  assert_that (List.for_all returns ~f:Float.is_finite) (equal_to true)

(* ------------------------------------------------------------------ *)
(* Variance clustering — feed a short window, then a long window with   *)
(* the same parameters. The realised variance over a stretch following  *)
(* a high-shock burst should exceed the variance over a stretch         *)
(* following a quiet stretch. We compare two windows from the same      *)
(* generated path: the 50 returns following the largest-magnitude       *)
(* return vs. the 50 returns following the smallest-magnitude return.   *)
(* ------------------------------------------------------------------ *)

let _variance xs =
  let n = List.length xs in
  if n = 0 then 0.0
  else
    let m = List.sum (module Float) xs ~f:Fn.id /. Float.of_int n in
    List.sum (module Float) xs ~f:(fun x -> (x -. m) ** 2.0) /. Float.of_int n

let test_variance_clustering _ =
  let returns =
    Garch.sample_returns _bull_params ~n_steps:2000 ~seed:11
      ~initial_variance:5e-5
  in
  let arr = Array.of_list returns in
  let n = Array.length arr in
  (* Find the index of the largest |r| in [0, n-100). The window we sample
     is [i+1, i+50] so we need i + 50 < n. *)
  let max_idx = ref 0 in
  let min_idx = ref 0 in
  for i = 0 to n - 100 do
    if Float.(Float.abs arr.(i) > Float.abs arr.(!max_idx)) then max_idx := i;
    if Float.(Float.abs arr.(i) < Float.abs arr.(!min_idx)) then min_idx := i
  done;
  let window_after i = Array.sub arr ~pos:(i + 1) ~len:50 |> Array.to_list in
  let var_after_high = _variance (window_after !max_idx) in
  let var_after_low = _variance (window_after !min_idx) in
  (* GARCH variance clustering means a large shock raises σ², driving up
     variance in the immediately following window. We assert the post-high
     window variance strictly exceeds the post-low window variance. *)
  assert_that var_after_high (gt (module Float_ord) var_after_low)

(* ------------------------------------------------------------------ *)
(* Stationary regime — empirical variance of a long sample is in the    *)
(* same order of magnitude as the long-run variance.                    *)
(* ------------------------------------------------------------------ *)

let test_empirical_variance_near_long_run _ =
  let returns =
    Garch.sample_returns _bull_params ~n_steps:5000 ~seed:5
      ~initial_variance:5e-5
  in
  let v = _variance returns in
  (* Long-run variance = 5e-5; empirical variance should be within a factor
     of ~3 (loose band — finite-sample variance has high variance itself). *)
  assert_that v (is_between (module Float_ord) ~low:1.5e-5 ~high:1.5e-4)

let suite =
  "garch"
  >::: [
         "validate default ok" >:: test_validate_default_ok;
         "validate rejects zero omega" >:: test_validate_rejects_zero_omega;
         "validate rejects negative alpha"
         >:: test_validate_rejects_negative_alpha;
         "validate rejects non-stationary"
         >:: test_validate_rejects_non_stationary;
         "long_run_variance default" >:: test_long_run_variance_default;
         "long_run_variance non-stationary is None"
         >:: test_long_run_variance_non_stationary_is_none;
         "sample_returns n=0 is empty"
         >:: test_sample_returns_zero_steps_is_empty;
         "sample_returns length matches" >:: test_sample_returns_length_matches;
         "sample_returns deterministic in seed"
         >:: test_sample_returns_deterministic;
         "sample_returns finite for long path" >:: test_sample_returns_finite;
         "variance clusters after large shocks" >:: test_variance_clustering;
         "empirical variance near long-run target"
         >:: test_empirical_variance_near_long_run;
       ]

let () = run_test_tt_main suite
