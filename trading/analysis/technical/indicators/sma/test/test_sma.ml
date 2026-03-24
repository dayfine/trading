open OUnit2
open Core
open Sma
open Indicator_types

let make_values pairs =
  List.map pairs ~f:(fun (d, v) -> { date = Date.of_string d; value = v })

(* --- SMA tests --- *)

let test_sma_basic _ =
  let data = make_values [ ("2024-01-01", 10.0); ("2024-01-02", 20.0); ("2024-01-03", 30.0) ] in
  let result = calculate_sma data 3 in
  assert_equal 1 (List.length result);
  assert_equal (Date.of_string "2024-01-03") (List.hd_exn result).date;
  assert_equal 20.0 (List.hd_exn result).value

let test_sma_window _ =
  (* 5 values, period=3 → 3 results *)
  let data =
    make_values
      [ ("2024-01-01", 10.0)
      ; ("2024-01-02", 20.0)
      ; ("2024-01-03", 30.0)
      ; ("2024-01-04", 40.0)
      ; ("2024-01-05", 50.0)
      ]
  in
  let result = calculate_sma data 3 in
  assert_equal 3 (List.length result);
  (* window [10, 20, 30] = 20.0 *)
  assert_equal 20.0 (List.nth_exn result 0).value;
  (* window [20, 30, 40] = 30.0 *)
  assert_equal 30.0 (List.nth_exn result 1).value;
  (* window [30, 40, 50] = 40.0 *)
  assert_equal 40.0 (List.nth_exn result 2).value

let test_sma_period_1 _ =
  let data = make_values [ ("2024-01-01", 42.0); ("2024-01-02", 84.0) ] in
  let result = calculate_sma data 1 in
  assert_equal 2 (List.length result);
  assert_equal 42.0 (List.nth_exn result 0).value;
  assert_equal 84.0 (List.nth_exn result 1).value

let test_sma_insufficient_data _ =
  let data = make_values [ ("2024-01-01", 10.0); ("2024-01-02", 20.0) ] in
  let result = calculate_sma data 5 in
  assert_equal [] result

let test_sma_empty _ =
  let result = calculate_sma [] 3 in
  assert_equal [] result

let test_sma_preserves_dates _ =
  let data =
    make_values
      [ ("2024-01-01", 10.0); ("2024-01-08", 20.0); ("2024-01-15", 30.0) ]
  in
  let result = calculate_sma data 2 in
  assert_equal 2 (List.length result);
  assert_equal (Date.of_string "2024-01-08") (List.nth_exn result 0).date;
  assert_equal (Date.of_string "2024-01-15") (List.nth_exn result 1).date

(* --- Weighted MA tests --- *)

let test_wma_basic _ =
  (* period=3: weights 1,2,3; sum=6
     values 10,20,30: (10*1 + 20*2 + 30*3)/6 = (10+40+90)/6 = 140/6 = 23.333... *)
  let data = make_values [ ("2024-01-01", 10.0); ("2024-01-02", 20.0); ("2024-01-03", 30.0) ] in
  let result = calculate_weighted_ma data 3 in
  assert_equal 1 (List.length result);
  let v = (List.hd_exn result).value in
  assert_bool "WMA value ~23.33" Float.(abs (v -. (140.0 /. 6.0)) < 1e-9)

let test_wma_equal_weights_period_1 _ =
  (* period=1: single weight → same as identity *)
  let data = make_values [ ("2024-01-01", 42.0); ("2024-01-02", 84.0) ] in
  let result = calculate_weighted_ma data 1 in
  assert_equal 2 (List.length result);
  assert_equal 42.0 (List.nth_exn result 0).value;
  assert_equal 84.0 (List.nth_exn result 1).value

let test_wma_period_2 _ =
  (* period=2: weights 1,2; sum=3
     [10,20] → (10*1 + 20*2)/3 = 50/3
     [20,30] → (20*1 + 30*2)/3 = 80/3 *)
  let data = make_values [ ("2024-01-01", 10.0); ("2024-01-02", 20.0); ("2024-01-03", 30.0) ] in
  let result = calculate_weighted_ma data 2 in
  assert_equal 2 (List.length result);
  assert_bool "WMA[0] ~16.67" Float.(abs ((List.nth_exn result 0).value -. (50.0 /. 3.0)) < 1e-9);
  assert_bool "WMA[1] ~26.67" Float.(abs ((List.nth_exn result 1).value -. (80.0 /. 3.0)) < 1e-9)

let test_wma_ascending_weights _ =
  (* WMA gives higher weight to recent values — test that ascending series
     produces a result > SMA of same data *)
  let data =
    make_values
      [ ("2024-01-01", 10.0)
      ; ("2024-01-02", 20.0)
      ; ("2024-01-03", 30.0)
      ; ("2024-01-04", 40.0)
      ]
  in
  let wma = calculate_weighted_ma data 4 in
  let sma = calculate_sma data 4 in
  let wma_val = (List.hd_exn wma).value in
  let sma_val = (List.hd_exn sma).value in
  assert_bool "WMA > SMA for ascending series" Float.(wma_val > sma_val)

let test_wma_insufficient_data _ =
  let data = make_values [ ("2024-01-01", 10.0) ] in
  let result = calculate_weighted_ma data 3 in
  assert_equal [] result

let suite =
  "sma_tests"
  >::: [ "test_sma_basic" >:: test_sma_basic
       ; "test_sma_window" >:: test_sma_window
       ; "test_sma_period_1" >:: test_sma_period_1
       ; "test_sma_insufficient_data" >:: test_sma_insufficient_data
       ; "test_sma_empty" >:: test_sma_empty
       ; "test_sma_preserves_dates" >:: test_sma_preserves_dates
       ; "test_wma_basic" >:: test_wma_basic
       ; "test_wma_equal_weights_period_1" >:: test_wma_equal_weights_period_1
       ; "test_wma_period_2" >:: test_wma_period_2
       ; "test_wma_ascending_weights" >:: test_wma_ascending_weights
       ; "test_wma_insufficient_data" >:: test_wma_insufficient_data
       ]

let () = run_test_tt_main suite
