open OUnit2
open Core
open Ema
open Indicator_types

let test_calculate_ema_minimal _ =
  (* Create test data with minimal required points *)
  let data =
    [
      { date = Date.of_string "2024-01-01"; value = 10.0 };
      { date = Date.of_string "2024-01-02"; value = 12.0 };
      { date = Date.of_string "2024-01-03"; value = 11.0 };
    ]
  in
  assert_equal (calculate_ema data 3)
    [ { date = Date.of_string "2024-01-03"; value = 11.0 } ]

let test_calculate_ema _ =
  let data =
    [
      { date = Date.of_string "2024-01-01"; value = 100.0 };
      { date = Date.of_string "2024-01-02"; value = 101.0 };
      { date = Date.of_string "2024-01-03"; value = 102.0 };
      { date = Date.of_string "2024-01-04"; value = 103.0 };
      { date = Date.of_string "2024-01-05"; value = 104.0 };
    ]
  in
  assert_equal (calculate_ema data 2)
    [
      { date = Date.of_string "2024-01-02"; value = 100.5 };
      { date = Date.of_string "2024-01-03"; value = 101.5 };
      { date = Date.of_string "2024-01-04"; value = 102.5 };
      { date = Date.of_string "2024-01-05"; value = 103.5 };
    ]

let test_ema_minimum_points _ =
  (* Test with minimum required data points *)
  let data =
    [
      { date = Date.of_string "2024-01-01"; value = 100.0 };
      { date = Date.of_string "2024-01-02"; value = 101.0 };
      { date = Date.of_string "2024-01-03"; value = 102.0 };
    ]
  in
  assert_equal (calculate_ema data 2)
    [
      { date = Date.of_string "2024-01-02"; value = 100.5 };
      { date = Date.of_string "2024-01-03"; value = 101.5 };
    ]

let test_ema_identical_values _ =
  (* Test with identical values *)
  let data =
    [
      { date = Date.of_string "2024-01-01"; value = 100.0 };
      { date = Date.of_string "2024-01-02"; value = 100.0 };
      { date = Date.of_string "2024-01-03"; value = 100.0 };
    ]
  in
  assert_equal (calculate_ema data 2)
    [
      { date = Date.of_string "2024-01-02"; value = 100.0 };
      { date = Date.of_string "2024-01-03"; value = 100.0 };
    ]

let suite =
  "EMA tests"
  >::: [
         "test_calculate_ema_minimal" >:: test_calculate_ema_minimal;
         "test_calculate_ema" >:: test_calculate_ema;
         "test_ema_minimum_points" >:: test_ema_minimum_points;
         "test_ema_identical_values" >:: test_ema_identical_values;
       ]

let () = run_test_tt_main suite
