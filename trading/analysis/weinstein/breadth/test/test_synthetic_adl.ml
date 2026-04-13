open OUnit2
open Matchers
open Synthetic_adl

(* ------------------------------------------------------------------ *)
(* compute_daily_changes                                                *)
(* ------------------------------------------------------------------ *)

let test_compute_daily_changes_basic _ =
  let prices_a =
    [ ("2024-01-01", 100.0); ("2024-01-02", 105.0); ("2024-01-03", 110.0) ]
  in
  let prices_b =
    [ ("2024-01-01", 50.0); ("2024-01-02", 55.0); ("2024-01-03", 52.0) ]
  in
  let result = compute_daily_changes ~min_stocks:1 [ prices_a; prices_b ] in
  assert_that result
    (elements_are
       [
         (fun (date, counts) ->
           assert_that date (equal_to "2024-01-02");
           assert_that counts.advances (equal_to 2);
           assert_that counts.declines (equal_to 0);
           assert_that counts.total (equal_to 2));
         (fun (date, counts) ->
           assert_that date (equal_to "2024-01-03");
           assert_that counts.advances (equal_to 1);
           assert_that counts.declines (equal_to 1);
           assert_that counts.total (equal_to 2));
       ])

let test_compute_daily_changes_min_stocks_filter _ =
  let prices_a = [ ("2024-01-01", 100.0); ("2024-01-02", 105.0) ] in
  let result = compute_daily_changes ~min_stocks:5 [ prices_a ] in
  assert_that (List.length result) (equal_to 0)

let test_compute_daily_changes_unchanged _ =
  let prices_a = [ ("2024-01-01", 100.0); ("2024-01-02", 100.0) ] in
  let result = compute_daily_changes ~min_stocks:1 [ prices_a ] in
  assert_that result
    (elements_are
       [
         (fun (_date, counts) ->
           assert_that counts.advances (equal_to 0);
           assert_that counts.declines (equal_to 0);
           assert_that counts.total (equal_to 1));
       ])

let test_compute_daily_changes_single_price_skipped _ =
  let prices_a = [ ("2024-01-01", 100.0) ] in
  let result = compute_daily_changes ~min_stocks:1 [ prices_a ] in
  assert_that (List.length result) (equal_to 0)

(* ------------------------------------------------------------------ *)
(* pearson_correlation                                                  *)
(* ------------------------------------------------------------------ *)

let test_pearson_perfect_positive _ =
  let xs = [ 1.0; 2.0; 3.0; 4.0; 5.0 ] in
  let ys = [ 2.0; 4.0; 6.0; 8.0; 10.0 ] in
  assert_that (pearson_correlation xs ys) (float_equal 1.0)

let test_pearson_perfect_negative _ =
  let xs = [ 1.0; 2.0; 3.0; 4.0; 5.0 ] in
  let ys = [ 10.0; 8.0; 6.0; 4.0; 2.0 ] in
  assert_that (pearson_correlation xs ys) (float_equal ~epsilon:1e-10 (-1.0))

let test_pearson_zero_variance _ =
  let xs = [ 5.0; 5.0; 5.0 ] in
  let ys = [ 1.0; 2.0; 3.0 ] in
  assert_that (pearson_correlation xs ys) (float_equal 0.0)

let test_pearson_empty _ =
  assert_that (pearson_correlation [] []) (float_equal 0.0)

let test_pearson_known_value _ =
  let xs = [ 1.0; 2.0; 3.0; 4.0; 5.0 ] in
  let ys = [ 2.0; 3.0; 5.0; 4.0; 6.0 ] in
  assert_that (pearson_correlation xs ys) (float_equal ~epsilon:1e-6 0.9)

(* ------------------------------------------------------------------ *)
(* validate_against_golden                                              *)
(* ------------------------------------------------------------------ *)

let test_validate_against_golden_no_overlap _ =
  let synthetic =
    Core.Map.of_alist_exn (module Core.String) [ ("20240101", 10) ]
  in
  let golden =
    Core.Map.of_alist_exn (module Core.String) [ ("20240201", 20) ]
  in
  let result = validate_against_golden ~synthetic ~golden in
  assert_that result.overlap_count (equal_to 0);
  assert_that result.correlation (float_equal 0.0);
  assert_that result.mae (float_equal 0.0)

let test_validate_against_golden_perfect_match _ =
  let data =
    Core.Map.of_alist_exn
      (module Core.String)
      [ ("20240101", 100); ("20240102", 200); ("20240103", 150) ]
  in
  let result = validate_against_golden ~synthetic:data ~golden:data in
  assert_that result.overlap_count (equal_to 3);
  assert_that result.correlation (float_equal 1.0);
  assert_that result.mae (float_equal 0.0)

let test_validate_against_golden_partial_overlap _ =
  let synthetic =
    Core.Map.of_alist_exn
      (module Core.String)
      [ ("20240101", 100); ("20240102", 200); ("20240103", 300) ]
  in
  let golden =
    Core.Map.of_alist_exn
      (module Core.String)
      [ ("20240102", 200); ("20240103", 300); ("20240104", 400) ]
  in
  let result = validate_against_golden ~synthetic ~golden in
  assert_that result.overlap_count (equal_to 2);
  assert_that result.correlation (float_equal 1.0);
  assert_that result.mae (float_equal 0.0)

let test_validate_against_golden_with_error _ =
  let synthetic =
    Core.Map.of_alist_exn
      (module Core.String)
      [ ("20240101", 100); ("20240102", 200); ("20240103", 300) ]
  in
  let golden =
    Core.Map.of_alist_exn
      (module Core.String)
      [ ("20240101", 110); ("20240102", 210); ("20240103", 310) ]
  in
  let result = validate_against_golden ~synthetic ~golden in
  assert_that result.overlap_count (equal_to 3);
  (* Perfect correlation despite constant offset *)
  assert_that result.correlation (float_equal 1.0);
  assert_that result.mae (float_equal 10.0)

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
         "pearson_perfect_positive" >:: test_pearson_perfect_positive;
         "pearson_perfect_negative" >:: test_pearson_perfect_negative;
         "pearson_zero_variance" >:: test_pearson_zero_variance;
         "pearson_empty" >:: test_pearson_empty;
         "pearson_known_value" >:: test_pearson_known_value;
         "validate_no_overlap" >:: test_validate_against_golden_no_overlap;
         "validate_perfect_match" >:: test_validate_against_golden_perfect_match;
         "validate_partial_overlap"
         >:: test_validate_against_golden_partial_overlap;
         "validate_with_error" >:: test_validate_against_golden_with_error;
       ]

let () = run_test_tt_main suite
