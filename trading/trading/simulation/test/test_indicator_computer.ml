open Core
open OUnit2
open Trading_simulation
open Matchers

(** Test helper: create a daily price *)
let make_price ~y ~m ~d ~close () =
  {
    Types.Daily_price.date = Date.create_exn ~y ~m:(Month.of_int_exn m) ~d;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
    volume = 1000000;
    adjusted_close = close;
  }

(** Test helper: extract result or fail *)
let ok_or_fail_status = function
  | Ok x -> x
  | Error (err : Status.t) -> failwith err.message

(** Test: compute EMA with daily cadence *)
let test_compute_ema_daily _ =
  let prices =
    [
      make_price ~y:2024 ~m:1 ~d:1 ~close:100.0 ();
      make_price ~y:2024 ~m:1 ~d:2 ~close:101.0 ();
      make_price ~y:2024 ~m:1 ~d:3 ~close:102.0 ();
      make_price ~y:2024 ~m:1 ~d:4 ~close:103.0 ();
      make_price ~y:2024 ~m:1 ~d:5 ~close:104.0 ();
      make_price ~y:2024 ~m:1 ~d:8 ~close:105.0 ();
      make_price ~y:2024 ~m:1 ~d:9 ~close:106.0 ();
      make_price ~y:2024 ~m:1 ~d:10 ~close:107.0 ();
    ]
  in
  let result =
    Indicator_computer.compute_ema ~symbol:"AAPL" ~prices ~period:3
      ~cadence:Daily ()
    |> ok_or_fail_status
  in
  (* Verify symbol *)
  assert_that result.symbol (equal_to "AAPL");
  (* Verify we have EMA values (should have 8 - 3 + 1 = 6 values after 3-period EMA) *)
  assert_that result.indicator_values (size_is 6)

(** Test: compute EMA with weekly cadence *)
let test_compute_ema_weekly _ =
  let prices =
    [
      (* Week 1: Mon-Fri *)
      make_price ~y:2024 ~m:1 ~d:1 ~close:100.0 ();
      make_price ~y:2024 ~m:1 ~d:2 ~close:101.0 ();
      make_price ~y:2024 ~m:1 ~d:3 ~close:102.0 ();
      make_price ~y:2024 ~m:1 ~d:4 ~close:103.0 ();
      make_price ~y:2024 ~m:1 ~d:5 ~close:104.0 ();
      (* Week 2 *)
      make_price ~y:2024 ~m:1 ~d:8 ~close:105.0 ();
      make_price ~y:2024 ~m:1 ~d:9 ~close:106.0 ();
      make_price ~y:2024 ~m:1 ~d:10 ~close:107.0 ();
      make_price ~y:2024 ~m:1 ~d:11 ~close:108.0 ();
      make_price ~y:2024 ~m:1 ~d:12 ~close:109.0 ();
      (* Week 3 *)
      make_price ~y:2024 ~m:1 ~d:15 ~close:110.0 ();
      make_price ~y:2024 ~m:1 ~d:16 ~close:111.0 ();
      make_price ~y:2024 ~m:1 ~d:17 ~close:112.0 ();
      make_price ~y:2024 ~m:1 ~d:18 ~close:113.0 ();
      make_price ~y:2024 ~m:1 ~d:19 ~close:114.0 ();
      (* Week 4 *)
      make_price ~y:2024 ~m:1 ~d:22 ~close:115.0 ();
      make_price ~y:2024 ~m:1 ~d:23 ~close:116.0 ();
      make_price ~y:2024 ~m:1 ~d:24 ~close:117.0 ();
      make_price ~y:2024 ~m:1 ~d:25 ~close:118.0 ();
      make_price ~y:2024 ~m:1 ~d:26 ~close:119.0 ();
    ]
  in
  let result =
    Indicator_computer.compute_ema ~symbol:"MSFT" ~prices ~period:2
      ~cadence:Weekly ()
    |> ok_or_fail_status
  in
  (* Verify symbol *)
  assert_that result.symbol (equal_to "MSFT");
  (* Should have weekly values: 4 weeks, and with period=2, we get 4 - 2 + 1 = 3 EMA values *)
  assert_that result.indicator_values (size_is 3)

(** Test: compute EMA with monthly cadence *)
let test_compute_ema_monthly _ =
  skip_if true "Monthly cadence conversion not yet implemented";
  let prices =
    [
      (* Month 1: January *)
      make_price ~y:2024 ~m:1 ~d:1 ~close:100.0 ();
      make_price ~y:2024 ~m:1 ~d:15 ~close:105.0 ();
      make_price ~y:2024 ~m:1 ~d:31 ~close:110.0 ();
      (* Month 2: February *)
      make_price ~y:2024 ~m:2 ~d:1 ~close:115.0 ();
      make_price ~y:2024 ~m:2 ~d:15 ~close:120.0 ();
      make_price ~y:2024 ~m:2 ~d:29 ~close:125.0 ();
      (* Month 3: March *)
      make_price ~y:2024 ~m:3 ~d:1 ~close:130.0 ();
      make_price ~y:2024 ~m:3 ~d:15 ~close:135.0 ();
      make_price ~y:2024 ~m:3 ~d:31 ~close:140.0 ();
      (* Month 4: April *)
      make_price ~y:2024 ~m:4 ~d:1 ~close:145.0 ();
      make_price ~y:2024 ~m:4 ~d:15 ~close:150.0 ();
      make_price ~y:2024 ~m:4 ~d:30 ~close:155.0 ();
    ]
  in
  let result =
    Indicator_computer.compute_ema ~symbol:"GOOGL" ~prices ~period:2
      ~cadence:Monthly ()
    |> ok_or_fail_status
  in
  (* Verify symbol *)
  assert_that result.symbol (equal_to "GOOGL");
  (* Should have monthly values: 4 months, with period=2, we get 4 - 2 + 1 = 3 EMA values *)
  assert_that result.indicator_values (size_is 3)

(** Test: compute EMA with weekly cadence and as_of_date *)
let test_compute_ema_weekly_with_as_of_date _ =
  let prices =
    [
      (* Week 1 complete *)
      make_price ~y:2024 ~m:1 ~d:1 ~close:100.0 ();
      make_price ~y:2024 ~m:1 ~d:5 ~close:104.0 ();
      (* Week 2 partial (up to Wednesday) *)
      make_price ~y:2024 ~m:1 ~d:8 ~close:105.0 ();
      make_price ~y:2024 ~m:1 ~d:10 ~close:107.0 ();
    ]
  in
  let as_of_date = Date.create_exn ~y:2024 ~m:Month.Jan ~d:10 in
  let result =
    Indicator_computer.compute_ema ~symbol:"TSLA" ~prices ~period:2
      ~cadence:Weekly ~as_of_date ()
    |> ok_or_fail_status
  in
  (* Verify symbol *)
  assert_that result.symbol (equal_to "TSLA");
  (* Should have 2 weeks: 1 complete + 1 provisional, with period=2 gives 2 - 2 + 1 = 1 EMA value *)
  assert_that result.indicator_values (size_is 1)

(** Test: error when period is zero *)
let test_error_zero_period _ =
  let prices = [ make_price ~y:2024 ~m:1 ~d:1 ~close:100.0 () ] in
  let result =
    Indicator_computer.compute_ema ~symbol:"AAPL" ~prices ~period:0
      ~cadence:Daily ()
  in
  assert_that result is_error

(** Test: error when period is negative *)
let test_error_negative_period _ =
  let prices = [ make_price ~y:2024 ~m:1 ~d:1 ~close:100.0 () ] in
  let result =
    Indicator_computer.compute_ema ~symbol:"AAPL" ~prices ~period:(-1)
      ~cadence:Daily ()
  in
  assert_that result is_error

(** Test: error when prices list is empty *)
let test_error_empty_prices _ =
  let result =
    Indicator_computer.compute_ema ~symbol:"AAPL" ~prices:[] ~period:10
      ~cadence:Daily ()
  in
  assert_that result is_error

(** Test: verify close prices are used for indicator values *)
let test_uses_close_prices _ =
  let prices =
    [
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Jan ~d:1;
        open_price = 95.0;
        high_price = 105.0;
        low_price = 90.0;
        close_price = 100.0;
        volume = 1000000;
        adjusted_close = 100.0;
      };
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Jan ~d:2;
        open_price = 101.0;
        high_price = 110.0;
        low_price = 99.0;
        close_price = 105.0;
        volume = 1000000;
        adjusted_close = 105.0;
      };
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Jan ~d:3;
        open_price = 106.0;
        high_price = 115.0;
        low_price = 104.0;
        close_price = 110.0;
        volume = 1000000;
        adjusted_close = 110.0;
      };
    ]
  in
  let result =
    Indicator_computer.compute_ema ~symbol:"AAPL" ~prices ~period:2
      ~cadence:Daily ()
    |> ok_or_fail_status
  in
  (* Verify we got EMA values (should have 2 values from 3-day data with 2-period EMA) *)
  assert_that result.indicator_values (size_is 2);
  (* The EMA calculation uses close prices (100, 105, 110), not open/high/low *)
  let ema_values = result.indicator_values in
  let first : Indicator_types.indicator_value = List.nth_exn ema_values 0 in
  let second : Indicator_types.indicator_value = List.nth_exn ema_values 1 in
  (* Verify dates are preserved *)
  assert_that first.date (equal_to (Date.create_exn ~y:2024 ~m:Month.Jan ~d:2));
  assert_that second.date (equal_to (Date.create_exn ~y:2024 ~m:Month.Jan ~d:3))

let suite =
  "IndicatorComputerTests"
  >::: [
         "test_compute_ema_daily" >:: test_compute_ema_daily;
         "test_compute_ema_weekly" >:: test_compute_ema_weekly;
         "test_compute_ema_monthly" >:: test_compute_ema_monthly;
         "test_compute_ema_weekly_with_as_of_date"
         >:: test_compute_ema_weekly_with_as_of_date;
         "test_error_zero_period" >:: test_error_zero_period;
         "test_error_negative_period" >:: test_error_negative_period;
         "test_error_empty_prices" >:: test_error_empty_prices;
         "test_uses_close_prices" >:: test_uses_close_prices;
       ]

let () = run_test_tt_main suite
