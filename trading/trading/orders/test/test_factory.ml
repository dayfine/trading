open OUnit2
open Trading_base.Types
open Status
open Trading_orders.Types
open Trading_orders.Factory

let test_order_creation_from_params _ =
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
  | Error _ -> assert_failure "Expected successful order creation"

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
  | Error _ -> assert_failure "Expected successful stop-limit order creation"

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
  | Error _ -> assert_failure "Expected successful market order creation"

let test_valid_order_creation _ =
  let valid_params =
    {
      symbol = "AAPL";
      side = Buy;
      order_type = Market;
      quantity = 100.0;
      time_in_force = GTC;
    }
  in
  let test_time = Time_ns_unix.of_string "2024-01-01 12:00:00Z" in
  let result = create_order ~now_time:test_time valid_params in
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
  | Error _ -> assert_failure "Expected valid order creation"

let test_invalid_order_creation _ =
  let invalid_params =
    {
      symbol = "";
      side = Buy;
      order_type = Limit (-10.0);
      quantity = -5.0;
      time_in_force = GTC;
    }
  in
  let result = create_order invalid_params in
  match result with
  | Error status ->
      assert_equal true (is_error status);
      assert_equal true (String.length status.message > 0)
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
  | Error status ->
      assert_equal true (is_error status);
      assert_equal true (String.length status.message > 0)
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
  | Error status ->
      assert_equal true (is_error status);
      assert_equal true (String.length status.message > 0)
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
         "order_creation_from_params" >:: test_order_creation_from_params;
         "stop_orders" >:: test_stop_orders;
         "stop_limit_orders" >:: test_stop_limit_orders;
         "market_orders" >:: test_market_orders;
         "valid_order_creation" >:: test_valid_order_creation;
         "invalid_order_creation" >:: test_invalid_order_creation;
         "valid_buy_stop_limit" >:: test_valid_buy_stop_limit;
         "valid_sell_stop_limit" >:: test_valid_sell_stop_limit;
         "invalid_buy_stop_limit" >:: test_invalid_buy_stop_limit;
         "invalid_sell_stop_limit" >:: test_invalid_sell_stop_limit;
         "equal_prices_stop_limit" >:: test_equal_prices_stop_limit;
       ]

let () = run_test_tt_main suite
