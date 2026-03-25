open OUnit2
open Core
open Sma
open Indicator_types
open Matchers

let make_values pairs =
  List.map pairs ~f:(fun (d, v) -> { date = Date.of_string d; value = v })

let has_date d = field (fun v -> v.date) (equal_to (Date.of_string d))
let has_value f = field (fun v -> v.value) (float_equal f)

let has_date_value d f = all_of [ has_date d; has_value f ]

(* --- SMA tests --- *)

let test_sma_basic _ =
  let data = make_values [ ("2024-01-01", 10.0); ("2024-01-02", 20.0); ("2024-01-03", 30.0) ] in
  assert_that (calculate_sma data 3)
    (elements_are [ has_date_value "2024-01-03" 20.0 ])

let test_sma_window _ =
  (* 5 values, period=3 → 3 results: windows average to 20, 30, 40 *)
  let data =
    make_values
      [ ("2024-01-01", 10.0)
      ; ("2024-01-02", 20.0)
      ; ("2024-01-03", 30.0)
      ; ("2024-01-04", 40.0)
      ; ("2024-01-05", 50.0)
      ]
  in
  assert_that (calculate_sma data 3)
    (elements_are
       [ has_value 20.0
       ; has_value 30.0
       ; has_value 40.0
       ])

let test_sma_period_1 _ =
  let data = make_values [ ("2024-01-01", 42.0); ("2024-01-02", 84.0) ] in
  assert_that (calculate_sma data 1)
    (elements_are [ has_value 42.0; has_value 84.0 ])

let test_sma_insufficient_data _ =
  let data = make_values [ ("2024-01-01", 10.0); ("2024-01-02", 20.0) ] in
  assert_that (calculate_sma data 5) is_empty

let test_sma_empty _ =
  assert_that (calculate_sma [] 3) is_empty

let test_sma_preserves_dates _ =
  let data =
    make_values
      [ ("2024-01-01", 10.0); ("2024-01-08", 20.0); ("2024-01-15", 30.0) ]
  in
  assert_that (calculate_sma data 2)
    (elements_are
       [ has_date "2024-01-08"
       ; has_date "2024-01-15"
       ])

(* --- Weighted MA tests --- *)

let test_wma_basic _ =
  (* period=3: weights 1,2,3; sum=6
     values 10,20,30: (10*1 + 20*2 + 30*3)/6 = 140/6 ≈ 23.333 *)
  let data = make_values [ ("2024-01-01", 10.0); ("2024-01-02", 20.0); ("2024-01-03", 30.0) ] in
  assert_that (calculate_weighted_ma data 3)
    (elements_are [ has_value (140.0 /. 6.0) ])

let test_wma_equal_weights_period_1 _ =
  (* period=1: single weight → same as identity *)
  let data = make_values [ ("2024-01-01", 42.0); ("2024-01-02", 84.0) ] in
  assert_that (calculate_weighted_ma data 1)
    (elements_are [ has_value 42.0; has_value 84.0 ])

let test_wma_period_2 _ =
  (* period=2: weights 1,2; sum=3
     [10,20] → (10*1 + 20*2)/3 = 50/3
     [20,30] → (20*1 + 30*2)/3 = 80/3 *)
  let data = make_values [ ("2024-01-01", 10.0); ("2024-01-02", 20.0); ("2024-01-03", 30.0) ] in
  assert_that (calculate_weighted_ma data 2)
    (elements_are [ has_value (50.0 /. 3.0); has_value (80.0 /. 3.0) ])

let test_wma_ascending_weights _ =
  (* WMA gives higher weight to recent values — result > SMA for ascending series *)
  let data =
    make_values
      [ ("2024-01-01", 10.0)
      ; ("2024-01-02", 20.0)
      ; ("2024-01-03", 30.0)
      ; ("2024-01-04", 40.0)
      ]
  in
  let wma_val = (List.hd_exn (calculate_weighted_ma data 4)).value in
  let sma_val = (List.hd_exn (calculate_sma data 4)).value in
  assert_that Float.(wma_val > sma_val) (equal_to true)

let test_wma_insufficient_data _ =
  let data = make_values [ ("2024-01-01", 10.0) ] in
  assert_that (calculate_weighted_ma data 3) is_empty

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
