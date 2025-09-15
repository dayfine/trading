open Core
open OUnit2
open Trading_base.Types
open Status
open Trading_orders.Types
open Trading_orders.Create_order

let test_create_limit_order _ =
  let params =
    {
      symbol = "MSFT";
      side = Sell;
      order_type = Limit 150.0;
      quantity = 50.0;
      time_in_force = Day;
    }
  in
  let test_time = Time_ns_unix.of_string "2024-01-01 12:00:00Z" in
  let result = create_order ~now_time:test_time params in
  match result with
  | Ok order ->
      assert_equal
        {
          id = order.id;
          symbol = "MSFT";
          side = Sell;
          order_type = Limit 150.0;
          quantity = 50.0;
          time_in_force = Day;
          status = Pending;
          filled_quantity = 0.0;
          avg_fill_price = None;
          created_at = test_time;
          updated_at = test_time;
        }
        order
  | Error err -> assert_failure (Status.show err)

let test_stop_orders _ =
  let stop_buy_params =
    {
      symbol = "NVDA";
      side = Buy;
      order_type = Stop 900.0;
      quantity = 15.0;
      time_in_force = GTC;
    }
  in
  let test_time = Time_ns_unix.of_string "2024-01-01 12:00:00Z" in
  let result = create_order ~now_time:test_time stop_buy_params in
  match result with
  | Ok order ->
      assert_equal
        {
          id = order.id;
          symbol = "NVDA";
          side = Buy;
          order_type = Stop 900.0;
          quantity = 15.0;
          time_in_force = GTC;
          status = Pending;
          filled_quantity = 0.0;
          avg_fill_price = None;
          created_at = test_time;
          updated_at = test_time;
        }
        order
  | Error _ -> assert_failure "Expected successful stop order creation"

let test_stop_limit_orders _ =
  let stop_limit_buy_params =
    {
      symbol = "META";
      side = Buy;
      order_type = StopLimit (300.0, 305.0);
      quantity = 20.0;
      time_in_force = GTC;
    }
  in
  let test_time = Time_ns_unix.of_string "2024-01-01 12:00:00Z" in
  let result = create_order ~now_time:test_time stop_limit_buy_params in
  match result with
  | Ok order ->
      assert_equal
        {
          id = order.id;
          symbol = "META";
          side = Buy;
          order_type = StopLimit (300.0, 305.0);
          quantity = 20.0;
          time_in_force = GTC;
          status = Pending;
          filled_quantity = 0.0;
          avg_fill_price = None;
          created_at = test_time;
          updated_at = test_time;
        }
        order
  | Error e -> assert_failure (Status.show e)

let test_market_orders _ =
  let market_buy_params =
    {
      symbol = "AAPL";
      side = Buy;
      order_type = Market;
      quantity = 100.0;
      time_in_force = GTC;
    }
  in
  let test_time = Time_ns_unix.of_string "2024-01-01 12:00:00Z" in
  let result = create_order ~now_time:test_time market_buy_params in
  match result with
  | Ok order ->
      assert_equal
        {
          id = order.id;
          symbol = "AAPL";
          side = Buy;
          order_type = Market;
          quantity = 100.0;
          time_in_force = GTC;
          status = Pending;
          filled_quantity = 0.0;
          avg_fill_price = None;
          created_at = test_time;
          updated_at = test_time;
        }
        order
  | Error e -> assert_failure (Status.show e)

let test_negative_quantiy_is_invalid _ =
  let invalid_params =
    {
      symbol = "XYZ";
      side = Buy;
      order_type = Limit 110.0;
      quantity = -5.0;
      time_in_force = GTC;
    }
  in
  let result = create_order invalid_params in
  match result with
  | Error status -> assert_equal status.code Invalid_argument
  | Ok _ -> assert_failure "Expected validation to fail"

let test_zero_quantiy_is_invalid _ =
  let invalid_params =
    {
      symbol = "XYZ";
      side = Buy;
      order_type = Limit 110.0;
      quantity = 0.0;
      time_in_force = GTC;
    }
  in
  let result = create_order invalid_params in
  match result with
  | Error status -> assert_equal status.code Invalid_argument
  | Ok _ -> assert_failure "Expected validation to fail"

let test_empty_symbol_is_invalid _ =
  let invalid_params =
    {
      symbol = "";
      side = Buy;
      order_type = Limit 100.0;
      quantity = 10.0;
      time_in_force = GTC;
    }
  in
  let result = create_order invalid_params in
  match result with
  | Error status -> assert_equal status.code Invalid_argument
  | Ok _ -> assert_failure "Expected validation to fail"

let test_negative_price_is_invalid _ =
  let invalid_params =
    {
      symbol = "AAPL";
      side = Buy;
      order_type = Limit (-50.0);
      quantity = 10.0;
      time_in_force = GTC;
    }
  in
  let result = create_order invalid_params in
  match result with
  | Error status -> assert_equal status.code Invalid_argument
  | Ok _ -> assert_failure "Expected validation to fail"

let test_zero_price_is_invalid _ =
  let invalid_params =
    {
      symbol = "AAPL";
      side = Buy;
      order_type = Limit 0.0;
      quantity = 10.0;
      time_in_force = GTC;
    }
  in
  let result = create_order invalid_params in
  match result with
  | Error status -> assert_equal status.code Invalid_argument
  | Ok _ -> assert_failure "Expected validation to fail"

let test_negative_stop_price_is_invalid _ =
  let invalid_params =
    {
      symbol = "AAPL";
      side = Buy;
      order_type = Stop (-10.0);
      quantity = 10.0;
      time_in_force = GTC;
    }
  in
  let result = create_order invalid_params in
  match result with
  | Error status -> assert_equal status.code Invalid_argument
  | Ok _ -> assert_failure "Expected validation to fail"

let test_negative_stop_limit_prices_are_invalid _ =
  let invalid_params =
    {
      symbol = "AAPL";
      side = Buy;
      order_type = StopLimit (-10.0, -5.0);
      quantity = 10.0;
      time_in_force = GTC;
    }
  in
  let result = create_order invalid_params in
  match result with
  | Error status -> assert_equal status.code Invalid_argument
  | Ok _ -> assert_failure "Expected validation to fail"

let test_valid_buy_stop_limit _ =
  let valid_buy_stop_limit =
    {
      symbol = "AAPL";
      side = Buy;
      order_type = StopLimit (95.0, 100.0);
      quantity = 10.0;
      time_in_force = GTC;
    }
  in
  let test_time = Time_ns_unix.of_string "2024-01-01 12:00:00Z" in
  let result = create_order ~now_time:test_time valid_buy_stop_limit in
  match result with
  | Ok order ->
      assert_equal
        {
          id = order.id;
          symbol = "AAPL";
          side = Buy;
          order_type = StopLimit (95.0, 100.0);
          quantity = 10.0;
          time_in_force = GTC;
          status = Pending;
          filled_quantity = 0.0;
          avg_fill_price = None;
          created_at = test_time;
          updated_at = test_time;
        }
        order
  | Error _ -> assert_failure "Expected valid buy stop-limit order creation"

let test_valid_sell_stop_limit _ =
  let valid_sell_stop_limit =
    {
      symbol = "MSFT";
      side = Sell;
      order_type = StopLimit (200.0, 195.0);
      quantity = 5.0;
      time_in_force = GTC;
    }
  in
  let test_time = Time_ns_unix.of_string "2024-01-01 12:00:00Z" in
  let result = create_order ~now_time:test_time valid_sell_stop_limit in
  match result with
  | Ok order ->
      assert_equal
        {
          id = order.id;
          symbol = "MSFT";
          side = Sell;
          order_type = StopLimit (200.0, 195.0);
          quantity = 5.0;
          time_in_force = GTC;
          status = Pending;
          filled_quantity = 0.0;
          avg_fill_price = None;
          created_at = test_time;
          updated_at = test_time;
        }
        order
  | Error _ -> assert_failure "Expected valid sell stop-limit order creation"

let test_invalid_buy_stop_limit _ =
  let invalid_buy_stop_limit =
    {
      symbol = "GOOGL";
      side = Buy;
      order_type = StopLimit (100.0, 95.0);
      quantity = 10.0;
      time_in_force = GTC;
    }
  in
  let result = create_order invalid_buy_stop_limit in
  match result with
  | Error status -> assert_equal status.code Invalid_argument
  | Ok _ -> assert_failure "Expected invalid buy stop-limit to be rejected"

let test_invalid_sell_stop_limit _ =
  let invalid_sell_stop_limit =
    {
      symbol = "TSLA";
      side = Sell;
      order_type = StopLimit (200.0, 205.0);
      quantity = 5.0;
      time_in_force = GTC;
    }
  in
  let result = create_order invalid_sell_stop_limit in
  match result with
  | Error status -> assert_equal status.code Invalid_argument
  | Ok _ -> assert_failure "Expected invalid sell stop-limit to be rejected"

let test_equal_prices_stop_limit _ =
  let equal_prices_buy =
    {
      symbol = "META";
      side = Buy;
      order_type = StopLimit (100.0, 100.0);
      quantity = 10.0;
      time_in_force = GTC;
    }
  in
  let test_time = Time_ns_unix.of_string "2024-01-01 12:00:00Z" in
  let result = create_order ~now_time:test_time equal_prices_buy in
  match result with
  | Ok order ->
      assert_equal
        {
          id = order.id;
          symbol = "META";
          side = Buy;
          order_type = StopLimit (100.0, 100.0);
          quantity = 10.0;
          time_in_force = GTC;
          status = Pending;
          filled_quantity = 0.0;
          avg_fill_price = None;
          created_at = test_time;
          updated_at = test_time;
        }
        order
  | Error _ -> assert_failure "Expected equal prices buy stop-limit to be valid"

let suite =
  "Order Factory"
  >::: [
         "create_limit_order" >:: test_create_limit_order;
         "stop_orders" >:: test_stop_orders;
         "stop_limit_orders" >:: test_stop_limit_orders;
         "market_orders" >:: test_market_orders;
         "negative_quantiy_is_invalid" >:: test_negative_quantiy_is_invalid;
         "zero_quantiy_is_invalid" >:: test_zero_quantiy_is_invalid;
         "empty_symbol_is_invalid" >:: test_empty_symbol_is_invalid;
         "negative_price_is_invalid" >:: test_negative_price_is_invalid;
         "zero_price_is_invalid" >:: test_zero_price_is_invalid;
         "negative_stop_price_is_invalid"
         >:: test_negative_stop_price_is_invalid;
         "negative_stop_limit_prices_are_invalid"
         >:: test_negative_stop_limit_prices_are_invalid;
         "valid_buy_stop_limit" >:: test_valid_buy_stop_limit;
         "valid_sell_stop_limit" >:: test_valid_sell_stop_limit;
         "invalid_buy_stop_limit" >:: test_invalid_buy_stop_limit;
         "invalid_sell_stop_limit" >:: test_invalid_sell_stop_limit;
         "equal_prices_stop_limit" >:: test_equal_prices_stop_limit;
       ]

let () = run_test_tt_main suite
