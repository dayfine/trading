open OUnit2
open Matchers
open Synthetic_adl

(* ------------------------------------------------------------------ *)
(* parse_symbols                                                        *)
(* ------------------------------------------------------------------ *)

let test_parse_symbols_basic _ =
  let rows = [ "AAPL, Technology"; "MSFT, Technology"; "JPM, Financials" ] in
  let result = parse_symbols rows in
  assert_that result
    (elements_are [ equal_to "AAPL"; equal_to "MSFT"; equal_to "JPM" ])

let test_parse_symbols_skips_blank _ =
  let rows = [ "AAPL, Technology"; ", Technology"; "  , Financials" ] in
  let result = parse_symbols rows in
  assert_that result (elements_are [ equal_to "AAPL" ])

let test_parse_symbols_empty _ =
  let result = parse_symbols [] in
  assert_that (List.length result) (equal_to 0)

(* ------------------------------------------------------------------ *)
(* parse_close_prices                                                   *)
(* ------------------------------------------------------------------ *)

let test_parse_close_prices_basic _ =
  let rows =
    [
      "2024-01-02, 100.0, 105.0, 99.0, 102.0, 1000";
      "2024-01-03, 102.0, 106.0, 101.0, 104.0, 1200";
    ]
  in
  let result = parse_close_prices rows in
  assert_that result
    (elements_are
       [
         (fun (d, c) ->
           assert_that d (equal_to "2024-01-02");
           assert_that c (float_equal 102.0));
         (fun (d, c) ->
           assert_that d (equal_to "2024-01-03");
           assert_that c (float_equal 104.0));
       ])

let test_parse_close_prices_skips_invalid _ =
  let rows =
    [
      "2024-01-02, 100.0, 105.0, 99.0, 102.0, 1000";
      "2024-01-03, 102.0, 106.0, 101.0, N/A, 1200";
    ]
  in
  let result = parse_close_prices rows in
  assert_that result (size_is 1)

let test_parse_close_prices_sorts_by_date _ =
  let rows =
    [
      "2024-01-05, 0, 0, 0, 110.0, 0";
      "2024-01-02, 0, 0, 0, 100.0, 0";
      "2024-01-03, 0, 0, 0, 105.0, 0";
    ]
  in
  let result = parse_close_prices rows in
  assert_that result
    (elements_are
       [
         (fun (d, _) -> assert_that d (equal_to "2024-01-02"));
         (fun (d, _) -> assert_that d (equal_to "2024-01-03"));
         (fun (d, _) -> assert_that d (equal_to "2024-01-05"));
       ])

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
(* mean_absolute_error                                                  *)
(* ------------------------------------------------------------------ *)

let test_mae_zero _ =
  let xs = [ 1.0; 2.0; 3.0 ] in
  assert_that (mean_absolute_error xs xs) (float_equal 0.0)

let test_mae_basic _ =
  let xs = [ 1.0; 2.0; 3.0 ] in
  let ys = [ 2.0; 3.0; 5.0 ] in
  assert_that (mean_absolute_error xs ys) (float_equal ~epsilon:1e-3 1.333)

let test_mae_empty _ = assert_that (mean_absolute_error [] []) (float_equal 0.0)

(* ------------------------------------------------------------------ *)
(* format_date_yyyymmdd / format_breadth_row                            *)
(* ------------------------------------------------------------------ *)

let test_format_date _ =
  assert_that (format_date_yyyymmdd "2024-01-15") (equal_to "20240115")

let test_format_date_no_dashes _ =
  assert_that (format_date_yyyymmdd "20240115") (equal_to "20240115")

let test_format_breadth_row _ =
  assert_that (format_breadth_row ("2024-01-15", 42)) (equal_to "20240115, 42")

(* ------------------------------------------------------------------ *)
(* test suite                                                           *)
(* ------------------------------------------------------------------ *)

let suite =
  "synthetic_adl"
  >::: [
         "parse_symbols_basic" >:: test_parse_symbols_basic;
         "parse_symbols_skips_blank" >:: test_parse_symbols_skips_blank;
         "parse_symbols_empty" >:: test_parse_symbols_empty;
         "parse_close_prices_basic" >:: test_parse_close_prices_basic;
         "parse_close_prices_skips_invalid"
         >:: test_parse_close_prices_skips_invalid;
         "parse_close_prices_sorts_by_date"
         >:: test_parse_close_prices_sorts_by_date;
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
         "mae_zero" >:: test_mae_zero;
         "mae_basic" >:: test_mae_basic;
         "mae_empty" >:: test_mae_empty;
         "format_date" >:: test_format_date;
         "format_date_no_dashes" >:: test_format_date_no_dashes;
         "format_breadth_row" >:: test_format_breadth_row;
       ]

let () = run_test_tt_main suite
