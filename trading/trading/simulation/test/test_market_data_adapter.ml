(** Tests for market_data_adapter module *)

open Core
open OUnit2
open Matchers

let date_of_string = Date.of_string

(** Helper to create test price data *)
let make_test_price ~date ~close_price =
  {
    Types.Daily_price.date;
    open_price = close_price;
    high_price = close_price;
    low_price = close_price;
    close_price;
    volume = 1000;
    adjusted_close = close_price;
  }

(** Create sample price data for testing *)
let create_sample_prices () =
  let prices_aapl =
    [
      make_test_price ~date:(date_of_string "2024-01-01") ~close_price:150.0;
      make_test_price ~date:(date_of_string "2024-01-02") ~close_price:151.0;
      make_test_price ~date:(date_of_string "2024-01-03") ~close_price:152.0;
    ]
  in
  let prices_googl =
    [
      make_test_price ~date:(date_of_string "2024-01-01") ~close_price:140.0;
      make_test_price ~date:(date_of_string "2024-01-02") ~close_price:141.0;
    ]
  in
  [
    ({ symbol = "AAPL"; prices = prices_aapl } : Trading_simulation.Simulator.symbol_prices);
    ({ symbol = "GOOGL"; prices = prices_googl } : Trading_simulation.Simulator.symbol_prices);
  ]

(** Test: Create adapter with valid data *)
let test_create_adapter _ =
  let prices = create_sample_prices () in
  let current_date = date_of_string "2024-01-02" in
  let _adapter =
    Trading_simulation.Market_data_adapter.create ~prices ~current_date
  in
  (* Just verify it doesn't crash - adapter is opaque *)
  assert_bool "Adapter created successfully" true

(** Test: get_price returns correct price for valid symbol and date *)
let test_get_price_valid_symbol _ =
  let prices = create_sample_prices () in
  let current_date = date_of_string "2024-01-02" in
  let adapter =
    Trading_simulation.Market_data_adapter.create ~prices ~current_date
  in

  let price_opt = Trading_simulation.Market_data_adapter.get_price adapter "AAPL" in
  assert_that price_opt
    (is_some_and
       (field
          (fun (p : Types.Daily_price.t) -> p.close_price)
          (float_equal 151.0)))

(** Test: get_price returns None for invalid symbol *)
let test_get_price_invalid_symbol _ =
  let prices = create_sample_prices () in
  let current_date = date_of_string "2024-01-02" in
  let adapter =
    Trading_simulation.Market_data_adapter.create ~prices ~current_date
  in

  let price_opt = Trading_simulation.Market_data_adapter.get_price adapter "INVALID" in
  assert_that price_opt is_none

(** Test: get_price returns None for future date *)
let test_get_price_future_date _ =
  let prices = create_sample_prices () in
  (* Current date is 2024-01-02, so 2024-01-05 is in the future *)
  let current_date = date_of_string "2024-01-05" in
  let adapter =
    Trading_simulation.Market_data_adapter.create ~prices ~current_date
  in

  (* No price data exists for 2024-01-05 *)
  let price_opt = Trading_simulation.Market_data_adapter.get_price adapter "AAPL" in
  assert_that price_opt is_none

(** Test: get_price returns None for past date with no data *)
let test_get_price_past_date_no_data _ =
  let prices = create_sample_prices () in
  (* Current date is before any data *)
  let current_date = date_of_string "2023-12-31" in
  let adapter =
    Trading_simulation.Market_data_adapter.create ~prices ~current_date
  in

  let price_opt = Trading_simulation.Market_data_adapter.get_price adapter "AAPL" in
  assert_that price_opt is_none

(** Test: get_price works for multiple symbols independently *)
let test_get_price_multiple_symbols _ =
  let prices = create_sample_prices () in
  let current_date = date_of_string "2024-01-02" in
  let adapter =
    Trading_simulation.Market_data_adapter.create ~prices ~current_date
  in

  (* AAPL has data for 2024-01-02 *)
  let aapl_price = Trading_simulation.Market_data_adapter.get_price adapter "AAPL" in
  assert_that aapl_price
    (is_some_and
       (field (fun (p : Types.Daily_price.t) -> p.close_price) (float_equal 151.0)));

  (* GOOGL also has data for 2024-01-02 *)
  let googl_price = Trading_simulation.Market_data_adapter.get_price adapter "GOOGL" in
  assert_that googl_price
    (is_some_and
       (field (fun (p : Types.Daily_price.t) -> p.close_price) (float_equal 141.0)))

(** Test: get_indicator returns None (stub in Change 1) *)
let test_get_indicator_returns_none _ =
  let prices = create_sample_prices () in
  let current_date = date_of_string "2024-01-02" in
  let adapter =
    Trading_simulation.Market_data_adapter.create ~prices ~current_date
  in

  let indicator_opt =
    Trading_simulation.Market_data_adapter.get_indicator adapter "AAPL" "EMA" 20
  in
  assert_that indicator_opt is_none

let suite =
  "Market_data_adapter tests"
  >::: [
         "test_create_adapter" >:: test_create_adapter;
         "test_get_price_valid_symbol" >:: test_get_price_valid_symbol;
         "test_get_price_invalid_symbol" >:: test_get_price_invalid_symbol;
         "test_get_price_future_date" >:: test_get_price_future_date;
         "test_get_price_past_date_no_data" >:: test_get_price_past_date_no_data;
         "test_get_price_multiple_symbols" >:: test_get_price_multiple_symbols;
         "test_get_indicator_returns_none" >:: test_get_indicator_returns_none;
       ]

let () = run_test_tt_main suite
