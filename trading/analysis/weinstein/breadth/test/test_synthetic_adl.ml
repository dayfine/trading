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
(* validate_against_golden                                              *)
(* ------------------------------------------------------------------ *)

(** Helper: build a string map from an association list. *)
let _map_of pairs = Core.Map.of_alist_exn (module Core.String) pairs

let test_validate_correlation_perfect_positive _ =
  let synthetic =
    _map_of [ ("01", 1); ("02", 2); ("03", 3); ("04", 4); ("05", 5) ]
  in
  let golden =
    _map_of [ ("01", 2); ("02", 4); ("03", 6); ("04", 8); ("05", 10) ]
  in
  let result = validate_against_golden ~synthetic ~golden in
  assert_that result.correlation (float_equal 1.0)

let test_validate_correlation_perfect_negative _ =
  let synthetic =
    _map_of [ ("01", 1); ("02", 2); ("03", 3); ("04", 4); ("05", 5) ]
  in
  let golden =
    _map_of [ ("01", 10); ("02", 8); ("03", 6); ("04", 4); ("05", 2) ]
  in
  let result = validate_against_golden ~synthetic ~golden in
  assert_that result.correlation (float_equal ~epsilon:1e-10 (-1.0))

let test_validate_correlation_zero_variance _ =
  let synthetic = _map_of [ ("01", 5); ("02", 5); ("03", 5) ] in
  let golden = _map_of [ ("01", 1); ("02", 2); ("03", 3) ] in
  let result = validate_against_golden ~synthetic ~golden in
  assert_that result.correlation (float_equal 0.0)

let test_validate_against_golden_no_overlap _ =
  let synthetic = _map_of [ ("20240101", 10) ] in
  let golden = _map_of [ ("20240201", 20) ] in
  let result = validate_against_golden ~synthetic ~golden in
  assert_that result.overlap_count (equal_to 0);
  assert_that result.correlation (float_equal 0.0);
  assert_that result.mae (float_equal 0.0)

let test_validate_against_golden_perfect_match _ =
  let data =
    _map_of [ ("20240101", 100); ("20240102", 200); ("20240103", 150) ]
  in
  let result = validate_against_golden ~synthetic:data ~golden:data in
  assert_that result.overlap_count (equal_to 3);
  assert_that result.correlation (float_equal 1.0);
  assert_that result.mae (float_equal 0.0)

let test_validate_against_golden_partial_overlap _ =
  let synthetic =
    _map_of [ ("20240101", 100); ("20240102", 200); ("20240103", 300) ]
  in
  let golden =
    _map_of [ ("20240102", 200); ("20240103", 300); ("20240104", 400) ]
  in
  let result = validate_against_golden ~synthetic ~golden in
  assert_that result.overlap_count (equal_to 2);
  assert_that result.correlation (float_equal 1.0);
  assert_that result.mae (float_equal 0.0)

let test_validate_against_golden_with_error _ =
  let synthetic =
    _map_of [ ("20240101", 100); ("20240102", 200); ("20240103", 300) ]
  in
  let golden =
    _map_of [ ("20240101", 110); ("20240102", 210); ("20240103", 310) ]
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
