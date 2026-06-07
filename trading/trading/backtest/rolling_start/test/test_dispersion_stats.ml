open Core
open OUnit2
open Matchers
module DS = Rolling_start.Dispersion_stats

(* Matcher: the float under test is NaN. Composed via [matching] so it obeys the
   one-assert_that-per-value rule. *)
let is_nan : float matcher =
  matching ~msg:"expected NaN"
    (fun x -> if Float.is_nan x then Some () else None)
    __

(* All expected values below are hand-computed with the NumPy-default "linear"
   (type-7) percentile method: for a sorted list of length n, the p-th
   percentile reads at rank r = p/100 * (n - 1) with linear interpolation. *)

let test_median_odd _ =
  (* sorted [1;2;3;4;5], middle element = 3 *)
  assert_that (DS.median [ 3.0; 1.0; 5.0; 2.0; 4.0 ]) (float_equal 3.0)

let test_median_even _ =
  (* sorted [1;2;3;4], mean of 2 and 3 = 2.5 *)
  assert_that (DS.median [ 4.0; 1.0; 3.0; 2.0 ]) (float_equal 2.5)

let test_median_singleton _ = assert_that (DS.median [ 7.0 ]) (float_equal 7.0)
let test_median_empty _ = assert_that (DS.median []) is_nan

let test_percentile_min _ =
  assert_that (DS.percentile [ 4.0; 1.0; 3.0 ] ~p:0.0) (float_equal 1.0)

let test_percentile_max _ =
  assert_that (DS.percentile [ 4.0; 1.0; 3.0 ] ~p:100.0) (float_equal 4.0)

let test_percentile_interpolation _ =
  (* sorted [10;20;30;40;50], n=5. p25 rank = 0.25*4 = 1.0 -> exactly 20.
     p10 rank = 0.10*4 = 0.4 -> 10 + 0.4*(20-10) = 14. *)
  assert_that
    (DS.percentile [ 50.0; 10.0; 40.0; 20.0; 30.0 ] ~p:25.0)
    (float_equal 20.0);
  assert_that
    (DS.percentile [ 50.0; 10.0; 40.0; 20.0; 30.0 ] ~p:10.0)
    (float_equal 14.0)

let test_percentile_p75_interp _ =
  (* sorted [0;1;2;3], n=4. p75 rank = 0.75*3 = 2.25 -> 2 + 0.25*(3-2) = 2.25. *)
  assert_that (DS.percentile [ 3.0; 0.0; 2.0; 1.0 ] ~p:75.0) (float_equal 2.25)

let test_percentile_empty _ = assert_that (DS.percentile [] ~p:50.0) is_nan

let test_percentile_singleton _ =
  assert_that (DS.percentile [ 9.0 ] ~p:33.0) (float_equal 9.0)

let test_percentile_out_of_range_low _ =
  assert_raises (Invalid_argument "percentile: p=-1 out of [0, 100]") (fun () ->
      DS.percentile [ 1.0 ] ~p:(-1.0))

let test_percentile_out_of_range_high _ =
  assert_raises (Invalid_argument "percentile: p=101 out of [0, 100]")
    (fun () -> DS.percentile [ 1.0 ] ~p:101.0)

let test_iqr _ =
  (* sorted [0;1;2;3], p75=2.25, p25=0.75, iqr = 1.5 *)
  assert_that (DS.iqr [ 3.0; 0.0; 2.0; 1.0 ]) (float_equal 1.5)

let test_iqr_constant _ =
  (* all equal -> zero spread *)
  assert_that (DS.iqr [ 5.0; 5.0; 5.0; 5.0 ]) (float_equal 0.0)

let test_iqr_empty _ = assert_that (DS.iqr []) is_nan

let test_summarize_full _ =
  (* sorted [10;20;30;40;50], n=5.
     median(p50)=30; p10 rank 0.4 -> 14; p25=20; p75=40 -> iqr=20; min=10; max=50 *)
  assert_that
    (DS.summarize [ 50.0; 10.0; 40.0; 20.0; 30.0 ])
    (all_of
       [
         field (fun s -> s.DS.n) (equal_to 5);
         field (fun s -> s.DS.median) (float_equal 30.0);
         field (fun s -> s.DS.p10) (float_equal 14.0);
         field (fun s -> s.DS.iqr) (float_equal 20.0);
         field (fun s -> s.DS.min) (float_equal 10.0);
         field (fun s -> s.DS.max) (float_equal 50.0);
       ])

let test_summarize_empty _ =
  assert_that (DS.summarize []) (field (fun s -> s.DS.n) (equal_to 0))

let test_summarize_empty_fields_nan _ =
  let s = DS.summarize [] in
  assert_that s.DS.median is_nan;
  assert_that s.DS.p10 is_nan;
  assert_that s.DS.iqr is_nan;
  assert_that s.DS.min is_nan;
  assert_that s.DS.max is_nan

(* Negative values must be ordered correctly (drawdown metrics can be negative). *)
let test_summarize_negatives _ =
  (* sorted [-50;-30;-10], n=3. median=-30; min=-50; max=-10 *)
  assert_that
    (DS.summarize [ -10.0; -50.0; -30.0 ])
    (all_of
       [
         field (fun s -> s.DS.median) (float_equal (-30.0));
         field (fun s -> s.DS.min) (float_equal (-50.0));
         field (fun s -> s.DS.max) (float_equal (-10.0));
       ])

let suite =
  "dispersion_stats"
  >::: [
         "median_odd" >:: test_median_odd;
         "median_even" >:: test_median_even;
         "median_singleton" >:: test_median_singleton;
         "median_empty" >:: test_median_empty;
         "percentile_min" >:: test_percentile_min;
         "percentile_max" >:: test_percentile_max;
         "percentile_interpolation" >:: test_percentile_interpolation;
         "percentile_p75_interp" >:: test_percentile_p75_interp;
         "percentile_empty" >:: test_percentile_empty;
         "percentile_singleton" >:: test_percentile_singleton;
         "percentile_out_of_range_low" >:: test_percentile_out_of_range_low;
         "percentile_out_of_range_high" >:: test_percentile_out_of_range_high;
         "iqr" >:: test_iqr;
         "iqr_constant" >:: test_iqr_constant;
         "iqr_empty" >:: test_iqr_empty;
         "summarize_full" >:: test_summarize_full;
         "summarize_empty" >:: test_summarize_empty;
         "summarize_empty_fields_nan" >:: test_summarize_empty_fields_nan;
         "summarize_negatives" >:: test_summarize_negatives;
       ]

let () = run_test_tt_main suite
