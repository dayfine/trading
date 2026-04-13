open OUnit2
open Matchers
open Synthetic_adl

let d = Core.Date.of_string

(* ------------------------------------------------------------------ *)
(* compute_daily_changes                                                *)
(* ------------------------------------------------------------------ *)

let test_compute_daily_changes_basic _ =
  let prices_a =
    [
      (d "2024-01-01", 100.0); (d "2024-01-02", 105.0); (d "2024-01-03", 110.0);
    ]
  in
  let prices_b =
    [ (d "2024-01-01", 50.0); (d "2024-01-02", 55.0); (d "2024-01-03", 52.0) ]
  in
  let result = compute_daily_changes ~min_stocks:1 [ prices_a; prices_b ] in
  assert_that result
    (elements_are
       [
         pair
           (equal_to (d "2024-01-02"))
           (all_of
              [
                field (fun c -> c.advances) (equal_to 2);
                field (fun c -> c.declines) (equal_to 0);
                field (fun c -> c.total) (equal_to 2);
              ]);
         pair
           (equal_to (d "2024-01-03"))
           (all_of
              [
                field (fun c -> c.advances) (equal_to 1);
                field (fun c -> c.declines) (equal_to 1);
                field (fun c -> c.total) (equal_to 2);
              ]);
       ])

let test_compute_daily_changes_min_stocks_filter _ =
  let prices_a = [ (d "2024-01-01", 100.0); (d "2024-01-02", 105.0) ] in
  let result = compute_daily_changes ~min_stocks:5 [ prices_a ] in
  assert_that result (size_is 0)

let test_compute_daily_changes_unchanged _ =
  let prices_a = [ (d "2024-01-01", 100.0); (d "2024-01-02", 100.0) ] in
  let result = compute_daily_changes ~min_stocks:1 [ prices_a ] in
  assert_that result
    (elements_are
       [
         pair
           (equal_to (d "2024-01-02"))
           (all_of
              [
                field (fun c -> c.advances) (equal_to 0);
                field (fun c -> c.declines) (equal_to 0);
                field (fun c -> c.total) (equal_to 1);
              ]);
       ])

let test_compute_daily_changes_single_price_skipped _ =
  let prices_a = [ (d "2024-01-01", 100.0) ] in
  let result = compute_daily_changes ~min_stocks:1 [ prices_a ] in
  assert_that result (size_is 0)

(* ------------------------------------------------------------------ *)
(* validate_against_golden                                              *)
(* ------------------------------------------------------------------ *)

(** Helper: build a date map from an association list. *)
let _map_of pairs = Core.Map.of_alist_exn (module Core.Date) pairs

let test_validate_correlation_perfect_positive _ =
  let synthetic =
    _map_of
      [
        (d "2024-01-01", 1);
        (d "2024-01-02", 2);
        (d "2024-01-03", 3);
        (d "2024-01-04", 4);
        (d "2024-01-05", 5);
      ]
  in
  let golden =
    _map_of
      [
        (d "2024-01-01", 2);
        (d "2024-01-02", 4);
        (d "2024-01-03", 6);
        (d "2024-01-04", 8);
        (d "2024-01-05", 10);
      ]
  in
  let result = validate_against_golden ~synthetic ~golden in
  assert_that result.correlation (float_equal 1.0)

let test_validate_correlation_perfect_negative _ =
  let synthetic =
    _map_of
      [
        (d "2024-01-01", 1);
        (d "2024-01-02", 2);
        (d "2024-01-03", 3);
        (d "2024-01-04", 4);
        (d "2024-01-05", 5);
      ]
  in
  let golden =
    _map_of
      [
        (d "2024-01-01", 10);
        (d "2024-01-02", 8);
        (d "2024-01-03", 6);
        (d "2024-01-04", 4);
        (d "2024-01-05", 2);
      ]
  in
  let result = validate_against_golden ~synthetic ~golden in
  assert_that result.correlation (float_equal ~epsilon:1e-10 (-1.0))

let test_validate_correlation_zero_variance _ =
  let synthetic =
    _map_of [ (d "2024-01-01", 5); (d "2024-01-02", 5); (d "2024-01-03", 5) ]
  in
  let golden =
    _map_of [ (d "2024-01-01", 1); (d "2024-01-02", 2); (d "2024-01-03", 3) ]
  in
  let result = validate_against_golden ~synthetic ~golden in
  assert_that result.correlation (float_equal 0.0)

let test_validate_against_golden_no_overlap _ =
  let synthetic = _map_of [ (d "2024-01-01", 10) ] in
  let golden = _map_of [ (d "2024-02-01", 20) ] in
  let result = validate_against_golden ~synthetic ~golden in
  assert_that result
    (all_of
       [
         field (fun r -> r.overlap_count) (equal_to 0);
         field (fun r -> r.correlation) (float_equal 0.0);
         field (fun r -> r.mae) (float_equal 0.0);
       ])

let test_validate_against_golden_perfect_match _ =
  let data =
    _map_of
      [ (d "2024-01-01", 100); (d "2024-01-02", 200); (d "2024-01-03", 150) ]
  in
  let result = validate_against_golden ~synthetic:data ~golden:data in
  assert_that result
    (all_of
       [
         field (fun r -> r.overlap_count) (equal_to 3);
         field (fun r -> r.correlation) (float_equal 1.0);
         field (fun r -> r.mae) (float_equal 0.0);
       ])

let test_validate_against_golden_partial_overlap _ =
  let synthetic =
    _map_of
      [ (d "2024-01-01", 100); (d "2024-01-02", 200); (d "2024-01-03", 300) ]
  in
  let golden =
    _map_of
      [ (d "2024-01-02", 200); (d "2024-01-03", 300); (d "2024-01-04", 400) ]
  in
  let result = validate_against_golden ~synthetic ~golden in
  assert_that result
    (all_of
       [
         field (fun r -> r.overlap_count) (equal_to 2);
         field (fun r -> r.correlation) (float_equal 1.0);
         field (fun r -> r.mae) (float_equal 0.0);
       ])

let test_validate_against_golden_with_error _ =
  let synthetic =
    _map_of
      [ (d "2024-01-01", 100); (d "2024-01-02", 200); (d "2024-01-03", 300) ]
  in
  let golden =
    _map_of
      [ (d "2024-01-01", 110); (d "2024-01-02", 210); (d "2024-01-03", 310) ]
  in
  let result = validate_against_golden ~synthetic ~golden in
  assert_that result
    (all_of
       [
         field (fun r -> r.overlap_count) (equal_to 3);
         (* Perfect correlation despite constant offset *)
         field (fun r -> r.correlation) (float_equal 1.0);
         field (fun r -> r.mae) (float_equal 10.0);
       ])

(* ------------------------------------------------------------------ *)
(* test suite                                                           *)
(* ------------------------------------------------------------------ *)

let suite =
  "synthetic_adl"
  >::: [
         "compute_daily_changes_basic" >:: test_compute_daily_changes_basic;
         "compute_daily_changes_min_stocks_filter"
         >:: test_compute_daily_changes_min_stocks_filter;
         "compute_daily_changes_unchanged"
         >:: test_compute_daily_changes_unchanged;
         "compute_daily_changes_single_price_skipped"
         >:: test_compute_daily_changes_single_price_skipped;
         "validate_correlation_perfect_positive"
         >:: test_validate_correlation_perfect_positive;
         "validate_correlation_perfect_negative"
         >:: test_validate_correlation_perfect_negative;
         "validate_correlation_zero_variance"
         >:: test_validate_correlation_zero_variance;
         "validate_no_overlap" >:: test_validate_against_golden_no_overlap;
         "validate_perfect_match" >:: test_validate_against_golden_perfect_match;
         "validate_partial_overlap"
         >:: test_validate_against_golden_partial_overlap;
         "validate_with_error" >:: test_validate_against_golden_with_error;
       ]

let () = run_test_tt_main suite
