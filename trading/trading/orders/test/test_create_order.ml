open Core
open OUnit2
open Trading_base.Types
open Status
open Trading_orders.Types
open Trading_orders.Create_order
open Matchers

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
  assert_that
    (create_order ~now_time:test_time params)
    (is_ok_and_holds (fun order ->
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
           order))

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
  assert_that (create_order invalid_params) is_error

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

(* G6 regression guard: order IDs must be deterministic and free of any
   wall-clock or Random-PRNG component. The previous generator used
   [Time_ns_unix.now ()] for the prefix and [Random.int] for the suffix; that
   scheme produced different IDs across forks, which caused unstable
   [Manager.orders] hashtable iteration and metric drift on long-horizon
   backtests (decade-2014-2023, sp500-2019-2023). See
   dev/notes/g6-decade-nondeterminism-investigation-2026-04-30.md. *)
let _make_market_params () =
  {
    symbol = "AAPL";
    side = Buy;
    order_type = Market;
    quantity = 1.0;
    time_in_force = GTC;
  }

let _ids_for_sequence n =
  List.init n ~f:(fun _ ->
      match create_order (_make_market_params ()) with
      | Ok o -> o.id
      | Error e -> assert_failure (Status.show e))

let test_default_ids_are_deterministic_in_sequence _ =
  (* Within a single sequence of [create_order] calls (no [~id] supplied),
     subsequent IDs must be distinct and have a stable pattern -- the auto-id
     generator must not depend on wall-clock or Random state. We compare each
     ID prefix against "ord-" and assert all distinct. *)
  let ids = _ids_for_sequence 5 in
  let unique = List.dedup_and_sort ~compare:String.compare ids in
  assert_that (List.length unique : int) (equal_to 5);
  List.iter ids ~f:(fun id ->
      assert_bool
        ("Expected id " ^ id ^ " to start with \"ord-\"")
        (String.is_prefix id ~prefix:"ord-"))

let test_default_ids_have_no_wall_clock_or_random _ =
  (* Sample a single ID and assert it does NOT contain a 19-digit
     nanoseconds-since-epoch number. The legacy generator embedded
     [Time_ns_unix.to_int63_ns_since_epoch] (~19 decimal digits in the post-
     2001-09-09 era) followed by "_" and a 4-digit random suffix. If we ever
     regress to that scheme, this test catches it. *)
  let id =
    match create_order (_make_market_params ()) with
    | Ok o -> o.id
    | Error e -> assert_failure (Status.show e)
  in
  assert_bool
    ("Expected id " ^ id
   ^ " to NOT contain '_' (legacy timestamp_random separator)")
    (not (String.contains id '_'));
  (* No long run of digits (>= 13 chars) anywhere in the id -- 13 digits is
     ~milliseconds-since-epoch; legacy used 19. Counter IDs like "ord-12345"
     have at most 5-6 digits in practice and never reach 13. *)
  let max_digit_run =
    String.fold id ~init:(0, 0) ~f:(fun (cur, best) c ->
        if Char.is_digit c then (cur + 1, max best (cur + 1)) else (0, best))
    |> snd
  in
  assert_bool
    (Printf.sprintf "Expected id %s to have no long digit run (got max=%d)" id
       max_digit_run)
    (max_digit_run < 13)

let test_explicit_id_overrides_default _ =
  let result =
    create_order ~id:"custom-id-123"
      {
        symbol = "MSFT";
        side = Sell;
        order_type = Market;
        quantity = 50.0;
        time_in_force = Day;
      }
  in
  assert_that result
    (is_ok_and_holds (field (fun o -> o.id) (equal_to "custom-id-123")))

let suite =
  "Order Factory"
  >::: [
         "default_ids_are_deterministic_in_sequence"
         >:: test_default_ids_are_deterministic_in_sequence;
         "default_ids_have_no_wall_clock_or_random"
         >:: test_default_ids_have_no_wall_clock_or_random;
         "explicit_id_overrides_default" >:: test_explicit_id_overrides_default;
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
