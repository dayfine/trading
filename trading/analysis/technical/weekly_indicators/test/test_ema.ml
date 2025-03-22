open OUnit2
open Core
open Weekly_indicators.Ema

let create_test_data date close =
  {
    Types.Daily_price.date;
    open_price = close;
    (* using close price for all fields for simplicity *)
    high_price = close;
    low_price = close;
    close_price = close;
    volume = 1000;
    adjusted_close = close;
  }

(* Helper function to create a list of dates *)
let create_dates base_date count =
  List.init count ~f:(fun i -> Date.add_days base_date i)

(* Helper function to create test data with specific prices *)
let create_test_data_with_prices dates prices =
  List.map2_exn dates prices ~f:create_test_data

(* Helper function to compare floats with tolerance *)
let float_equal ~tolerance a b =
  Float.(abs (a -. b) <= tolerance)

let test_calculate_ema_from_daily _ =
  (* Create test data with known values for predictable EMA calculation *)
  let base_date = Date.create_exn ~y:2024 ~m:Month.Jan ~d:1 in
  let dates = create_dates base_date 25 in
  (* Using simple values for easier manual verification *)
  let prices = List.init 25 ~f:(fun i -> 100.0 +. float_of_int i) in
  let data = create_test_data_with_prices dates prices in

  (* Test with period=2 *)
  let ema_result_2w = calculate_ema_from_daily data 2 in
  let expected_values = [109.50; 116.50; 121.50] in
  let expected_dates = [
    Date.create_exn ~y:2024 ~m:Month.Jan ~d:14;
    Date.create_exn ~y:2024 ~m:Month.Jan ~d:21;
    Date.create_exn ~y:2024 ~m:Month.Jan ~d:25;
  ] in
  let expected = List.map2_exn expected_dates expected_values ~f:(fun date value -> { date; value }) in

  assert_equal (List.length expected) (List.length ema_result_2w);
  List.iter2_exn expected ema_result_2w ~f:(fun exp act ->
    assert_equal exp act ~cmp:(fun a b ->
      Date.equal a.date b.date && float_equal ~tolerance:0.0001 a.value b.value)
      ~printer:(fun r -> sprintf "{ date = %s; value = %f }" (Date.to_string r.date) r.value));

  (* Verify the last EMA value *)
  match List.rev ema_result_2w with
  | last :: _ ->
      (* Last EMA should be higher than the first value *)
      assert_bool "Last EMA should be > first EMA" (Float.( > ) last.value 100.5);
      assert_equal 2024 (Date.year last.date)
  | [] -> assert_bool "Expected non-empty EMA results" false

let test_calculate_ema_from_weekly _ =
  (* Create test data with known values *)
  let base_date = Date.create_exn ~y:2024 ~m:Month.Jan ~d:1 in
  let dates = List.init 6 ~f:(fun i -> Date.add_days base_date (i * 7)) in
  (* Using simple values for easier manual verification *)
  let prices = [100.0; 101.0; 102.0; 103.0; 104.0; 105.0] in
  let data = create_test_data_with_prices dates prices in

  (* Test with period=2 *)
  let ema_result = calculate_ema_from_weekly data 2 in
  let expected_values = [100.5; 101.5; 102.5; 103.5; 104.5] in
  let expected_dates = List.init 5 ~f:(fun i -> Date.add_days base_date ((i + 1) * 7)) in
  let expected = List.map2_exn expected_dates expected_values ~f:(fun date value -> { date; value }) in

  assert_equal (List.length expected) (List.length ema_result);
  List.iter2_exn expected ema_result ~f:(fun exp act ->
    assert_equal exp act ~cmp:(fun a b ->
      Date.equal a.date b.date && float_equal ~tolerance:0.0001 a.value b.value)
      ~printer:(fun r -> sprintf "{ date = %s; value = %f }" (Date.to_string r.date) r.value));

  (* Verify the first EMA value *)
  match ema_result with
  | first :: _ ->
      (* First EMA should be the average of the first two values *)
      assert_bool "First EMA should be close to 100.5"
        (float_equal ~tolerance:0.0001 100.5 first.value);
      assert_equal (Date.add_days base_date 7) first.date;
      assert_equal { date = Date.add_days base_date 7; value = 100.5 } first ~cmp:(fun a b ->
        Date.equal a.date b.date && float_equal ~tolerance:0.0001 a.value b.value)
        ~printer:(fun r -> sprintf "{ date = %s; value = %f }" (Date.to_string r.date) r.value)
  | [] -> assert_bool "Expected non-empty EMA results" false;

  (* Verify the last EMA value *)
  match List.rev ema_result with
  | last :: _ ->
      (* Last EMA should be higher than the first value *)
      assert_bool "Last EMA should be > first EMA" (Float.( > ) last.value 100.5);
      assert_equal 2024 (Date.year last.date)
  | [] -> assert_bool "Expected non-empty EMA results" false

let test_ema_edge_cases _ =
  (* Test with minimum required data points *)
  let base_date = Date.create_exn ~y:2024 ~m:Month.Jan ~d:1 in
  let dates = create_dates base_date 10 in  (* Need at least 10 points for 2-week EMA *)
  let prices = List.init 10 ~f:(fun i -> 100.0 +. float_of_int i) in
  let data = create_test_data_with_prices dates prices in

  let ema_result = calculate_ema_from_daily data 2 in
  let expected_values = [107.5] in
  let expected_dates = [
    Date.create_exn ~y:2024 ~m:Month.Jan ~d:10;
  ] in
  let expected = List.map2_exn expected_dates expected_values ~f:(fun date value -> { date; value }) in

  assert_equal (List.length expected) (List.length ema_result);
  List.iter2_exn expected ema_result ~f:(fun exp act ->
    assert_equal exp act ~cmp:(fun a b ->
      Date.equal a.date b.date && float_equal ~tolerance:0.0001 a.value b.value)
      ~printer:(fun r -> sprintf "{ date = %s; value = %f }" (Date.to_string r.date) r.value));

  (* Test with identical values *)
  let dates = create_dates base_date 10 in
  let prices = List.init 10 ~f:(fun _ -> 100.0) in
  let data = create_test_data_with_prices dates prices in

  let ema_result = calculate_ema_from_daily data 2 in
  match ema_result with
  | first :: _ ->
      assert_bool "First EMA should be close to 100.0"
        (float_equal ~tolerance:0.0001 100.0 first.value);
      assert_equal { date = Date.create_exn ~y:2024 ~m:Month.Jan ~d:10; value = 100.0 } first ~cmp:(fun a b ->
        Date.equal a.date b.date && float_equal ~tolerance:0.0001 a.value b.value)
        ~printer:(fun r -> sprintf "{ date = %s; value = %f }" (Date.to_string r.date) r.value)
  | [] -> assert_bool "Expected non-empty EMA results" false

let suite =
  "EMA tests"
  >::: [
         "test_calculate_ema_from_daily" >:: test_calculate_ema_from_daily;
         "test_calculate_ema_from_weekly" >:: test_calculate_ema_from_weekly;
         "test_ema_edge_cases" >:: test_ema_edge_cases;
       ]

let () = run_test_tt_main suite
