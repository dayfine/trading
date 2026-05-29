open OUnit2
open Matchers
open Backtest_stats

(* Reference points: Phi(0) = 0.5, Phi(1.96) ~ 0.975, Phi(-1) ~ 0.158655,
   Phi(2.326348) ~ 0.99. *)
let test_cdf_known_points _ =
  assert_that (Normal_dist.cdf 0.0) (float_equal ~epsilon:1e-9 0.5);
  assert_that (Normal_dist.cdf 1.96) (float_equal ~epsilon:1e-4 0.975);
  assert_that (Normal_dist.cdf (-1.0)) (float_equal ~epsilon:1e-5 0.1586553);
  assert_that (Normal_dist.cdf 2.326348) (float_equal ~epsilon:1e-5 0.99)

(* Phi^-1(0.5) = 0, Phi^-1(0.975) ~ 1.959964, Phi^-1(0.99) ~ 2.326348. *)
let test_inv_cdf_known_points _ =
  assert_that (Normal_dist.inv_cdf 0.5) (float_equal ~epsilon:1e-9 0.0);
  assert_that (Normal_dist.inv_cdf 0.975) (float_equal ~epsilon:1e-5 1.959964);
  assert_that (Normal_dist.inv_cdf 0.99) (float_equal ~epsilon:1e-5 2.326348)

(* cdf and inv_cdf are inverses on a mid-range probability. *)
let test_round_trip _ =
  assert_that
    (Normal_dist.cdf (Normal_dist.inv_cdf 0.8))
    (float_equal ~epsilon:1e-9 0.8)

(* inv_cdf is undefined at the open-interval endpoints; the contract raises. *)
let test_inv_cdf_rejects_zero _ =
  assert_raises
    (Invalid_argument "Normal_dist.inv_cdf: p must be in (0, 1), got 0")
    (fun () -> Normal_dist.inv_cdf 0.0)

let test_inv_cdf_rejects_one _ =
  assert_raises
    (Invalid_argument "Normal_dist.inv_cdf: p must be in (0, 1), got 1")
    (fun () -> Normal_dist.inv_cdf 1.0)

let suite =
  "normal_dist"
  >::: [
         "cdf_known_points" >:: test_cdf_known_points;
         "inv_cdf_known_points" >:: test_inv_cdf_known_points;
         "round_trip" >:: test_round_trip;
         "inv_cdf_rejects_zero" >:: test_inv_cdf_rejects_zero;
         "inv_cdf_rejects_one" >:: test_inv_cdf_rejects_one;
       ]

let () = run_test_tt_main suite
