open OUnit2
open Core
open Ema
open Indicator_types

(* Helper function to create a list of dates *)
let create_dates base_date count =
  List.init count ~f:(fun i -> Date.add_days base_date i)

(* Helper function to create test data with specific values *)
let create_test_data_with_values dates values =
  List.map2_exn dates values ~f:(fun date value -> { date; value })

(* Helper function to compare floats with tolerance *)
let float_equal ~tolerance a b = Float.(abs (a -. b) <= tolerance)

let test_calculate_ema _ =
  (* Create test data with known values for predictable EMA calculation *)
  let base_date = Date.create_exn ~y:2024 ~m:Month.Jan ~d:1 in
  let dates = create_dates base_date 5 in
  (* Using simple values for easier manual verification *)
  let values = [ 100.0; 101.0; 102.0; 103.0; 104.0 ] in
  let data = create_test_data_with_values dates values in

  (* Test with period=2 *)
  let ema_result = calculate_ema data 2 in
  let expected_values = [ 100.5; 101.5; 102.5; 103.5 ] in
  let expected_dates = List.drop dates 1 in
  let expected =
    List.map2_exn expected_dates expected_values ~f:(fun date value ->
        { date; value })
  in

  assert_equal (List.length expected) (List.length ema_result);
  List.iter2_exn expected ema_result ~f:(fun exp act ->
      assert_equal exp act
        ~cmp:(fun a b ->
          Date.equal a.date b.date
          && float_equal ~tolerance:0.0001 a.value b.value)
        ~printer:(fun r ->
          sprintf "{ date = %s; value = %f }" (Date.to_string r.date) r.value));

  (* Verify the first EMA value *)
  match ema_result with
  | first :: _ ->
      (* First EMA should be the average of the first two values *)
      assert_bool "First EMA should be close to 100.5"
        (float_equal ~tolerance:0.0001 100.5 first.value);
      assert_equal (Date.add_days base_date 1) first.date;
      assert_equal
        { date = Date.add_days base_date 1; value = 100.5 }
        first
        ~cmp:(fun a b ->
          Date.equal a.date b.date
          && float_equal ~tolerance:0.0001 a.value b.value)
        ~printer:(fun r ->
          sprintf "{ date = %s; value = %f }" (Date.to_string r.date) r.value)
  | [] -> assert_bool "Expected non-empty EMA results" false

let test_ema_edge_cases _ =
  (* Test with minimum required data points *)
  let base_date = Date.create_exn ~y:2024 ~m:Month.Jan ~d:1 in
  let dates = create_dates base_date 3 in
  (* Need at least period+1 points for EMA *)
  let values = [ 100.0; 101.0; 102.0 ] in
  let data = create_test_data_with_values dates values in

  let ema_result = calculate_ema data 2 in
  let expected_values = [ 100.5; 101.5 ] in
  let expected_dates = List.drop dates 1 in
  let expected =
    List.map2_exn expected_dates expected_values ~f:(fun date value ->
        { date; value })
  in

  assert_equal (List.length expected) (List.length ema_result);
  List.iter2_exn expected ema_result ~f:(fun exp act ->
      assert_equal exp act
        ~cmp:(fun a b ->
          Date.equal a.date b.date
          && float_equal ~tolerance:0.0001 a.value b.value)
        ~printer:(fun r ->
          sprintf "{ date = %s; value = %f }" (Date.to_string r.date) r.value));

  (* Test with identical values *)
  let dates = create_dates base_date 3 in
  let values = List.init 3 ~f:(fun _ -> 100.0) in
  let data = create_test_data_with_values dates values in

  let ema_result = calculate_ema data 2 in
  let expected_values = [ 100.0; 100.0 ] in
  let expected_dates = List.drop dates 1 in
  let expected =
    List.map2_exn expected_dates expected_values ~f:(fun date value ->
        { date; value })
  in

  assert_equal (List.length expected) (List.length ema_result);
  List.iter2_exn expected ema_result ~f:(fun exp act ->
      assert_equal exp act
        ~cmp:(fun a b ->
          Date.equal a.date b.date
          && float_equal ~tolerance:0.0001 a.value b.value)
        ~printer:(fun r ->
          sprintf "{ date = %s; value = %f }" (Date.to_string r.date) r.value))

let suite =
  "EMA tests"
  >::: [
         "test_calculate_ema" >:: test_calculate_ema;
         "test_ema_edge_cases" >:: test_ema_edge_cases;
       ]

let () = run_test_tt_main suite
