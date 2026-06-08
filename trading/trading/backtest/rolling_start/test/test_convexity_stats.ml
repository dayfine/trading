open Core
open OUnit2
open Matchers
module CS = Rolling_start.Convexity_stats

(* Matcher: the float under test is +infinity. Composed via [matching] so it
   obeys the one-assert_that-per-value rule. *)
let is_pos_infinity : float matcher =
  matching ~msg:"expected +infinity"
    (fun x -> if Float.is_inf x && Float.( > ) x 0.0 then Some () else None)
    __

(* ---- time_underwater_pct ---- *)

let test_tuw_empty _ = assert_that (CS.time_underwater_pct []) (float_equal 0.0)

let test_tuw_singleton _ =
  assert_that (CS.time_underwater_pct [ 100.0 ]) (float_equal 0.0)

let test_tuw_monotone_up _ =
  (* Every point is a new high; none is below the prior high -> 0%. *)
  assert_that
    (CS.time_underwater_pct [ 100.0; 101.0; 102.0; 110.0 ])
    (float_equal 0.0)

let test_tuw_flat _ =
  (* No point strictly below the prior high -> 0%. *)
  assert_that (CS.time_underwater_pct [ 100.0; 100.0; 100.0 ]) (float_equal 0.0)

let test_tuw_drawdown_and_recover _ =
  (* Series: 100, 90, 80, 120, 110.
     point 1 (100): high-water set, not counted.
     point 2 (90): < 100 -> underwater.
     point 3 (80): < 100 -> underwater.
     point 4 (120): new high, not underwater.
     point 5 (110): < 120 -> underwater.
     3 of 5 observations underwater -> 60%. *)
  assert_that
    (CS.time_underwater_pct [ 100.0; 90.0; 80.0; 120.0; 110.0 ])
    (float_equal 60.0)

let test_tuw_all_below_first _ =
  (* 100, 50, 50, 50: points 2-4 all strictly below the high-water 100.
     3 of 4 -> 75%. *)
  assert_that
    (CS.time_underwater_pct [ 100.0; 50.0; 50.0; 50.0 ])
    (float_equal 75.0)

(* ---- tail_ratio ---- *)

let test_tail_ratio_empty _ = assert_that (CS.tail_ratio []) (float_equal 0.0)

let test_tail_ratio_symmetric _ =
  (* Symmetric series around 0; |p95| = |p5| -> ratio 1.0.
     sorted [-10;-5;0;5;10], n=5.
     p95 rank = 0.95*4 = 3.8 -> 5 + 0.8*(10-5) = 9.
     p5  rank = 0.05*4 = 0.2 -> -10 + 0.2*(-5 - -10) = -9.
     |9| / |-9| = 1.0. *)
  assert_that (CS.tail_ratio [ 0.0; -10.0; 10.0; -5.0; 5.0 ]) (float_equal 1.0)

let test_tail_ratio_upside_heavy _ =
  (* Upper tail twice the lower in magnitude.
     sorted [-5;-2;0;2;20], n=5.
     p95 rank = 3.8 -> 2 + 0.8*(20-2) = 16.4.
     p5  rank = 0.2 -> -5 + 0.2*(-2 - -5) = -4.4.
     16.4 / 4.4 = 3.7272... *)
  assert_that
    (CS.tail_ratio [ 0.0; -5.0; 20.0; -2.0; 2.0 ])
    (float_equal ~epsilon:1e-6 (16.4 /. 4.4))

let test_tail_ratio_all_gains _ =
  (* All-positive series: p5 magnitude is positive too here, so the ratio is
     finite. Use a series whose p5 is exactly 0 to hit the infinity branch. *)
  (* sorted [0;0;0;0;10], n=5. p5 rank = 0.2 -> 0 + 0.2*(0-0) = 0.
     p95 rank = 3.8 -> 0 + 0.8*(10-0) = 8.  |8| / 0 -> +infinity. *)
  assert_that (CS.tail_ratio [ 0.0; 0.0; 0.0; 0.0; 10.0 ]) is_pos_infinity

let test_tail_ratio_all_zero _ =
  (* Both tails zero magnitude -> 0.0. *)
  assert_that (CS.tail_ratio [ 0.0; 0.0; 0.0 ]) (float_equal 0.0)

(* ---- return_skew ---- *)

let test_skew_empty _ = assert_that (CS.return_skew []) (float_equal 0.0)

let test_skew_singleton _ =
  assert_that (CS.return_skew [ 5.0 ]) (float_equal 0.0)

let test_skew_flat _ =
  (* Zero variance -> 0.0. *)
  assert_that (CS.return_skew [ 3.0; 3.0; 3.0 ]) (float_equal 0.0)

let test_skew_symmetric _ =
  (* Symmetric distribution -> skew 0. [-2;-1;0;1;2] *)
  assert_that (CS.return_skew [ 0.0; -2.0; 2.0; -1.0; 1.0 ]) (float_equal 0.0)

let test_skew_right_tailed _ =
  (* [0;0;0;0;10]: mean 2, population.
     deviations: -2,-2,-2,-2,8.
     m2 = (4+4+4+4+64)/5 = 80/5 = 16.  sigma = 4.
     m3 = (-8-8-8-8+512)/5 = 480/5 = 96.
     skew = 96 / 4^3 = 96 / 64 = 1.5. *)
  assert_that (CS.return_skew [ 0.0; 0.0; 0.0; 0.0; 10.0 ]) (float_equal 1.5)

let test_skew_left_tailed _ =
  (* Mirror of the right-tailed case -> -1.5. *)
  assert_that
    (CS.return_skew [ 0.0; 0.0; 0.0; 0.0; -10.0 ])
    (float_equal (-1.5))

let suite =
  "convexity_stats"
  >::: [
         "tuw_empty" >:: test_tuw_empty;
         "tuw_singleton" >:: test_tuw_singleton;
         "tuw_monotone_up" >:: test_tuw_monotone_up;
         "tuw_flat" >:: test_tuw_flat;
         "tuw_drawdown_and_recover" >:: test_tuw_drawdown_and_recover;
         "tuw_all_below_first" >:: test_tuw_all_below_first;
         "tail_ratio_empty" >:: test_tail_ratio_empty;
         "tail_ratio_symmetric" >:: test_tail_ratio_symmetric;
         "tail_ratio_upside_heavy" >:: test_tail_ratio_upside_heavy;
         "tail_ratio_all_gains" >:: test_tail_ratio_all_gains;
         "tail_ratio_all_zero" >:: test_tail_ratio_all_zero;
         "skew_empty" >:: test_skew_empty;
         "skew_singleton" >:: test_skew_singleton;
         "skew_flat" >:: test_skew_flat;
         "skew_symmetric" >:: test_skew_symmetric;
         "skew_right_tailed" >:: test_skew_right_tailed;
         "skew_left_tailed" >:: test_skew_left_tailed;
       ]

let () = run_test_tt_main suite
