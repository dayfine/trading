open OUnit2
open Weekly_indicators.Types
open Weekly_indicators.Date
open Weekly_indicators.Ema

let create_test_data date close =
  { date;
    open_price = close;  (* using close price for all fields for simplicity *)
    high = close;
    low = close;
    close;
    adjusted_close = close;
    volume = 1000 }

let test_calculate_30_week_ema _ =
  (* Create 35 weeks of test data *)
  let base_date = create ~year:2024 ~month:1 ~day:1 in
  let data = List.init 35 (fun i ->
    let date = add_days base_date (i * 7) in
    create_test_data date (float_of_int (100 + i))
  ) in
  let ema_result = calculate_30_week_ema data in
  assert_equal 5 (List.length ema_result);  (* should have 5 EMA values (35-30) *)
  match List.rev ema_result with
  | (last_date, last_ema) :: _ ->
      assert_bool "Last EMA should be > 100.0" (last_ema > 100.0);
      assert_equal 2024 (year last_date);
      assert_equal 8 (month last_date);  (* Should be around August *)
  | [] -> assert_failure "No EMA results"

let suite =
  "EMA tests" >::: [
    "test_calculate_30_week_ema" >:: test_calculate_30_week_ema;
  ]
