open Core
open OUnit2
open Trading_base.Types
open Trading_orders.Types
open Trading_orders.Create_order
open Trading_engine.Engine
open Trading_engine.Types
open Matchers
module OrderManager = Trading_orders.Manager

(* Test helpers *)
let test_timestamp = Time_ns_unix.of_string "2024-01-15 10:30:00Z"

let make_config ?(per_share = 0.01) ?(minimum = 1.0) () =
  { commission = { per_share; minimum } }

let make_quote symbol ~bid ~ask ~last = { symbol; bid; ask; last }

let make_order_params ~symbol ~side ~order_type ~quantity ?(time_in_force = Day)
    () =
  { symbol; side; order_type; quantity; time_in_force }

(* Domain-specific matchers *)
let trade_like (expected : trade) (actual : trade) =
  (* Compare entire trade record, ignoring dynamic fields (id, timestamp) *)
  let normalized_actual =
    { actual with id = expected.id; timestamp = expected.timestamp }
  in
  assert_equal ~cmp:equal_trade expected normalized_actual
    ~msg:"Trade should match expected values"

(* Helper to submit a single order and check success *)
let submit_single_order order_mgr order =
  match OrderManager.submit_orders order_mgr [ order ] with
  | [ Ok () ] -> ()
  | [ Error err ] -> failwith ("Failed to submit order: " ^ Status.show err)
  | _ -> failwith "Expected single result from submit_orders"

(* Engine creation tests *)
let test_create_engine _ =
  let config = make_config () in
  let _engine = create config in
  (* Just verify creation succeeds - engine type is opaque *)
  assert_bool "Engine created successfully" true

let test_create_engine_with_custom_commission _ =
  let config = make_config ~per_share:0.02 ~minimum:2.0 () in
  let _engine = create config in
  (* Just verify creation succeeds - engine type is opaque *)
  assert_bool "Engine with custom commission created successfully" true

(* update_market tests - verified through execution behavior *)
let test_orders_skip_when_no_market_data _ =
  let config = make_config () in
  let engine = create config in
  let order_mgr = OrderManager.create () in
  (* Submit order but don't update market data *)
  let params =
    make_order_params ~symbol:"AAPL" ~side:Buy ~order_type:Market
      ~quantity:100.0 ()
  in
  let order =
    assert_ok ~msg:"Failed to create order"
      (create_order ~now_time:test_timestamp params)
  in
  submit_single_order order_mgr order;
  (* Process should return empty - no market data available *)
  assert_that (process_orders engine order_mgr) (is_ok_and_holds (equal_to []));
  (* Order should still be pending *)
  let pending = OrderManager.list_orders order_mgr ~filter:ActiveOnly in
  assert_that pending (size_is 1)

let test_update_market_enables_execution _ =
  let config = make_config () in
  let engine = create config in
  let order_mgr = OrderManager.create () in
  let params =
    make_order_params ~symbol:"AAPL" ~side:Buy ~order_type:Market
      ~quantity:100.0 ()
  in
  let order =
    assert_ok ~msg:"Failed to create order"
      (create_order ~now_time:test_timestamp params)
  in
  submit_single_order order_mgr order;
  (* First process - no market data *)
  assert_that (process_orders engine order_mgr) (is_ok_and_holds (equal_to []));
  (* Update market data *)
  let quote =
    make_quote "AAPL" ~bid:(Some 150.0) ~ask:(Some 150.5) ~last:(Some 150.25)
  in
  update_market engine [ quote ];
  (* Second process - should execute now *)
  assert_that
    (process_orders engine order_mgr)
    (is_ok_and_holds
       (one
          (field
             (fun (r : execution_report) -> r.trades)
             (one (field (fun (t : trade) -> t.price) (equal_to 150.25))))))

let test_update_market_overwrites_prices _ =
  let config = make_config () in
  let engine = create config in
  let order_mgr = OrderManager.create () in
  (* Update with first price *)
  let quote1 =
    make_quote "AAPL" ~bid:(Some 150.0) ~ask:(Some 150.5) ~last:(Some 150.25)
  in
  update_market engine [ quote1 ];
  (* Submit order *)
  let params =
    make_order_params ~symbol:"AAPL" ~side:Buy ~order_type:Market
      ~quantity:100.0 ()
  in
  let order1 =
    assert_ok ~msg:"Failed to create order"
      (create_order ~now_time:test_timestamp params)
  in
  submit_single_order order_mgr order1;
  (* Execute at first price *)
  let _ = process_orders engine order_mgr in
  (* Update with new price *)
  let quote2 =
    make_quote "AAPL" ~bid:(Some 155.0) ~ask:(Some 155.5) ~last:(Some 155.25)
  in
  update_market engine [ quote2 ];
  (* Submit new order *)
  let order2 =
    assert_ok ~msg:"Failed to create order"
      (create_order ~now_time:test_timestamp params)
  in
  submit_single_order order_mgr order2;
  (* Execute at new price *)
  assert_that
    (process_orders engine order_mgr)
    (is_ok_and_holds
       (one
          (field
             (fun (r : execution_report) -> r.trades)
             (one (field (fun (t : trade) -> t.price) (equal_to 155.25))))))

(* process_orders tests *)
let test_process_orders_empty_manager _ =
  let config = make_config () in
  let engine = create config in
  let order_mgr = OrderManager.create () in
  assert_that (process_orders engine order_mgr) (is_ok_and_holds (equal_to []))

let test_process_orders_with_market_order _ =
  let config = make_config () in
  let engine = create config in
  let order_mgr = OrderManager.create () in
  (* Create and submit a market order *)
  let params =
    make_order_params ~symbol:"AAPL" ~side:Buy ~order_type:Market
      ~quantity:100.0 ()
  in
  let order =
    assert_ok ~msg:"Failed to create order"
      (create_order ~now_time:test_timestamp params)
  in
  let () = submit_single_order order_mgr order in
  (* Update market data with price *)
  let quote =
    make_quote "AAPL" ~bid:(Some 150.0) ~ask:(Some 150.5) ~last:(Some 150.25)
  in
  update_market engine [ quote ];
  (* Process orders *)
  assert_that
    (process_orders engine order_mgr)
    (is_ok_and_holds
       (one
          (all_of
             [
               field (fun r -> r.order_id) (equal_to order.id);
               field (fun r -> r.status) (equal_to Filled);
               field
                 (fun (r : execution_report) -> r.trades)
                 (one
                    (trade_like
                       {
                         id = "";
                         order_id = order.id;
                         symbol = "AAPL";
                         side = Buy;
                         quantity = 100.0;
                         price = 150.25;
                         commission = 1.0;
                         timestamp = Time_ns_unix.epoch;
                       }));
             ])))

let test_process_orders_calculates_commission _ =
  let config = make_config ~per_share:0.01 ~minimum:1.0 () in
  let engine = create config in
  let order_mgr = OrderManager.create () in
  let params =
    make_order_params ~symbol:"AAPL" ~side:Buy ~order_type:Market ~quantity:50.0
      ()
  in
  let order =
    assert_ok ~msg:"Failed to create order"
      (create_order ~now_time:test_timestamp params)
  in
  let () = submit_single_order order_mgr order in
  (* Update market data *)
  let quote =
    make_quote "AAPL" ~bid:(Some 100.0) ~ask:(Some 100.5) ~last:(Some 100.25)
  in
  update_market engine [ quote ];
  (* For 50 shares at $0.01 per share:
     - Calculated = 50 * 0.01 = 0.50
     - Minimum = 1.0
     - Actual commission should be max(0.50, 1.0) = 1.0 *)
  assert_that
    (process_orders engine order_mgr)
    (is_ok_and_holds
       (one
          (field
             (fun (r : execution_report) -> r.trades)
             (one
                (trade_like
                   {
                     id = "";
                     order_id = order.id;
                     symbol = "AAPL";
                     side = Buy;
                     quantity = 50.0;
                     price = 100.25;
                     commission = 1.0;
                     timestamp = Time_ns_unix.epoch;
                   })))))

let test_process_orders_updates_order_status _ =
  let config = make_config () in
  let engine = create config in
  let order_mgr = OrderManager.create () in
  let params =
    make_order_params ~symbol:"AAPL" ~side:Buy ~order_type:Market
      ~quantity:100.0 ()
  in
  let order =
    assert_ok ~msg:"Failed to create order"
      (create_order ~now_time:test_timestamp params)
  in
  let () = submit_single_order order_mgr order in
  (* Verify order is initially Pending *)
  let orders_before = OrderManager.list_orders order_mgr ~filter:ActiveOnly in
  assert_that orders_before (size_is 1);
  (* Update market data *)
  let quote =
    make_quote "AAPL" ~bid:(Some 150.0) ~ask:(Some 150.5) ~last:(Some 150.25)
  in
  update_market engine [ quote ];
  (* Process orders *)
  let _result = process_orders engine order_mgr in
  (* Verify order status updated:
     - OrderManager.list_orders with ActiveOnly filter should return empty list
     - OrderManager.list_orders without filter should return 1 order with Filled status *)
  let orders_after = OrderManager.list_orders order_mgr ~filter:ActiveOnly in
  assert_that orders_after (equal_to []);
  let all_orders = OrderManager.list_orders order_mgr in
  assert_that all_orders
    (one
       (field
          (fun (o : Trading_orders.Types.order) -> o.status)
          (equal_to Trading_orders.Types.Filled)))

let test_process_orders_with_multiple_orders _ =
  let config = make_config () in
  let engine = create config in
  let order_mgr = OrderManager.create () in
  (* Submit 3 market orders *)
  let params1 =
    make_order_params ~symbol:"AAPL" ~side:Buy ~order_type:Market
      ~quantity:100.0 ()
  in
  let params2 =
    make_order_params ~symbol:"GOOGL" ~side:Sell ~order_type:Market
      ~quantity:50.0 ()
  in
  let params3 =
    make_order_params ~symbol:"MSFT" ~side:Buy ~order_type:Market ~quantity:75.0
      ()
  in
  let orders =
    List.map
      ~f:(fun params ->
        assert_ok ~msg:"Failed to create order"
          (create_order ~now_time:test_timestamp params))
      [ params1; params2; params3 ]
  in
  List.iter ~f:(submit_single_order order_mgr) orders;
  (* Update market data for all symbols in batch *)
  let quotes =
    [
      make_quote "AAPL" ~bid:(Some 150.0) ~ask:(Some 150.5) ~last:(Some 150.25);
      make_quote "GOOGL" ~bid:(Some 2800.0) ~ask:(Some 2805.0)
        ~last:(Some 2802.5);
      make_quote "MSFT" ~bid:(Some 380.0) ~ask:(Some 380.5) ~last:(Some 380.25);
    ]
  in
  update_market engine quotes;
  (* Process all orders *)
  let order1, order2, order3 =
    (List.nth_exn orders 0, List.nth_exn orders 1, List.nth_exn orders 2)
  in
  assert_that
    (process_orders engine order_mgr)
    (is_ok_and_holds
       (unordered_elements_are
          [
            all_of
              [
                field (fun r -> r.order_id) (equal_to order1.id);
                field (fun r -> r.status) (equal_to Filled);
              ];
            all_of
              [
                field (fun r -> r.order_id) (equal_to order2.id);
                field (fun r -> r.status) (equal_to Filled);
              ];
            all_of
              [
                field (fun r -> r.order_id) (equal_to order3.id);
                field (fun r -> r.status) (equal_to Filled);
              ];
          ]))

(* Limit order tests *)
let test_buy_limit_executes_when_ask_at_limit _ =
  let config = make_config () in
  let engine = create config in
  let order_mgr = OrderManager.create () in
  (* Submit buy limit order at $150.50 *)
  let params =
    make_order_params ~symbol:"AAPL" ~side:Buy ~order_type:(Limit 150.50)
      ~quantity:100.0 ()
  in
  let order =
    assert_ok ~msg:"Failed to create order"
      (create_order ~now_time:test_timestamp params)
  in
  submit_single_order order_mgr order;
  (* Update market with ask = 150.50 (exactly at limit) *)
  let quote =
    make_quote "AAPL" ~bid:(Some 150.0) ~ask:(Some 150.50) ~last:(Some 150.25)
  in
  update_market engine [ quote ];
  (* Should execute at ask price *)
  assert_that
    (process_orders engine order_mgr)
    (is_ok_and_holds
       (one
          (all_of
             [
               field (fun r -> r.order_id) (equal_to order.id);
               field (fun r -> r.status) (equal_to Filled);
               field
                 (fun (r : execution_report) -> r.trades)
                 (one
                    (trade_like
                       {
                         id = "";
                         order_id = order.id;
                         symbol = "AAPL";
                         side = Buy;
                         quantity = 100.0;
                         price = 150.50;
                         commission = 1.0;
                         timestamp = Time_ns_unix.epoch;
                       }));
             ])))

let test_buy_limit_executes_when_ask_below_limit _ =
  let config = make_config () in
  let engine = create config in
  let order_mgr = OrderManager.create () in
  (* Submit buy limit order at $151.00 *)
  let params =
    make_order_params ~symbol:"AAPL" ~side:Buy ~order_type:(Limit 151.00)
      ~quantity:100.0 ()
  in
  let order =
    assert_ok ~msg:"Failed to create order"
      (create_order ~now_time:test_timestamp params)
  in
  submit_single_order order_mgr order;
  (* Update market with ask = 150.50 (below limit) *)
  let quote =
    make_quote "AAPL" ~bid:(Some 150.0) ~ask:(Some 150.50) ~last:(Some 150.25)
  in
  update_market engine [ quote ];
  (* Should execute at ask price (150.50, better than limit) *)
  assert_that
    (process_orders engine order_mgr)
    (is_ok_and_holds
       (one
          (all_of
             [
               field (fun r -> r.order_id) (equal_to order.id);
               field (fun r -> r.status) (equal_to Filled);
               field
                 (fun (r : execution_report) -> r.trades)
                 (one
                    (trade_like
                       {
                         id = "";
                         order_id = order.id;
                         symbol = "AAPL";
                         side = Buy;
                         quantity = 100.0;
                         price = 150.50;
                         commission = 1.0;
                         timestamp = Time_ns_unix.epoch;
                       }));
             ])))

let test_buy_limit_does_not_execute_when_ask_above_limit _ =
  let config = make_config () in
  let engine = create config in
  let order_mgr = OrderManager.create () in
  (* Submit buy limit order at $150.00 *)
  let params =
    make_order_params ~symbol:"AAPL" ~side:Buy ~order_type:(Limit 150.00)
      ~quantity:100.0 ()
  in
  let order =
    assert_ok ~msg:"Failed to create order"
      (create_order ~now_time:test_timestamp params)
  in
  submit_single_order order_mgr order;
  (* Update market with ask = 150.50 (above limit) *)
  let quote =
    make_quote "AAPL" ~bid:(Some 150.0) ~ask:(Some 150.50) ~last:(Some 150.25)
  in
  update_market engine [ quote ];
  (* Should not execute *)
  assert_that (process_orders engine order_mgr) (is_ok_and_holds (equal_to []));
  (* Order should still be pending *)
  let pending = OrderManager.list_orders order_mgr ~filter:ActiveOnly in
  assert_that pending (size_is 1)

let test_sell_limit_executes_when_bid_at_limit _ =
  let config = make_config () in
  let engine = create config in
  let order_mgr = OrderManager.create () in
  (* Submit sell limit order at $150.00 *)
  let params =
    make_order_params ~symbol:"AAPL" ~side:Sell ~order_type:(Limit 150.00)
      ~quantity:100.0 ()
  in
  let order =
    assert_ok ~msg:"Failed to create order"
      (create_order ~now_time:test_timestamp params)
  in
  submit_single_order order_mgr order;
  (* Update market with bid = 150.00 (exactly at limit) *)
  let quote =
    make_quote "AAPL" ~bid:(Some 150.00) ~ask:(Some 150.50) ~last:(Some 150.25)
  in
  update_market engine [ quote ];
  (* Should execute at bid price *)
  assert_that
    (process_orders engine order_mgr)
    (is_ok_and_holds
       (one
          (all_of
             [
               field (fun r -> r.order_id) (equal_to order.id);
               field (fun r -> r.status) (equal_to Filled);
               field
                 (fun (r : execution_report) -> r.trades)
                 (one
                    (trade_like
                       {
                         id = "";
                         order_id = order.id;
                         symbol = "AAPL";
                         side = Sell;
                         quantity = 100.0;
                         price = 150.00;
                         commission = 1.0;
                         timestamp = Time_ns_unix.epoch;
                       }));
             ])))

let test_sell_limit_executes_when_bid_above_limit _ =
  let config = make_config () in
  let engine = create config in
  let order_mgr = OrderManager.create () in
  (* Submit sell limit order at $150.00 *)
  let params =
    make_order_params ~symbol:"AAPL" ~side:Sell ~order_type:(Limit 150.00)
      ~quantity:100.0 ()
  in
  let order =
    assert_ok ~msg:"Failed to create order"
      (create_order ~now_time:test_timestamp params)
  in
  submit_single_order order_mgr order;
  (* Update market with bid = 150.50 (above limit, better price) *)
  let quote =
    make_quote "AAPL" ~bid:(Some 150.50) ~ask:(Some 151.00) ~last:(Some 150.75)
  in
  update_market engine [ quote ];
  (* Should execute at bid price (150.50, better than limit) *)
  assert_that
    (process_orders engine order_mgr)
    (is_ok_and_holds
       (one
          (all_of
             [
               field (fun r -> r.order_id) (equal_to order.id);
               field (fun r -> r.status) (equal_to Filled);
               field
                 (fun (r : execution_report) -> r.trades)
                 (one
                    (trade_like
                       {
                         id = "";
                         order_id = order.id;
                         symbol = "AAPL";
                         side = Sell;
                         quantity = 100.0;
                         price = 150.50;
                         commission = 1.0;
                         timestamp = Time_ns_unix.epoch;
                       }));
             ])))

let test_sell_limit_does_not_execute_when_bid_below_limit _ =
  let config = make_config () in
  let engine = create config in
  let order_mgr = OrderManager.create () in
  (* Submit sell limit order at $150.50 *)
  let params =
    make_order_params ~symbol:"AAPL" ~side:Sell ~order_type:(Limit 150.50)
      ~quantity:100.0 ()
  in
  let order =
    assert_ok ~msg:"Failed to create order"
      (create_order ~now_time:test_timestamp params)
  in
  submit_single_order order_mgr order;
  (* Update market with bid = 150.00 (below limit) *)
  let quote =
    make_quote "AAPL" ~bid:(Some 150.00) ~ask:(Some 150.50) ~last:(Some 150.25)
  in
  update_market engine [ quote ];
  (* Should not execute *)
  assert_that (process_orders engine order_mgr) (is_ok_and_holds (equal_to []));
  (* Order should still be pending *)
  let pending = OrderManager.list_orders order_mgr ~filter:ActiveOnly in
  assert_that pending (size_is 1)

(* Test suite *)
let suite =
  "Engine Tests"
  >::: [
         "test_create_engine" >:: test_create_engine;
         "test_create_engine_with_custom_commission"
         >:: test_create_engine_with_custom_commission;
         "test_orders_skip_when_no_market_data"
         >:: test_orders_skip_when_no_market_data;
         "test_update_market_enables_execution"
         >:: test_update_market_enables_execution;
         "test_update_market_overwrites_prices"
         >:: test_update_market_overwrites_prices;
         "test_process_orders_empty_manager"
         >:: test_process_orders_empty_manager;
         "test_process_orders_with_market_order"
         >:: test_process_orders_with_market_order;
         "test_process_orders_calculates_commission"
         >:: test_process_orders_calculates_commission;
         "test_process_orders_updates_order_status"
         >:: test_process_orders_updates_order_status;
         "test_process_orders_with_multiple_orders"
         >:: test_process_orders_with_multiple_orders;
         "test_buy_limit_executes_when_ask_at_limit"
         >:: test_buy_limit_executes_when_ask_at_limit;
         "test_buy_limit_executes_when_ask_below_limit"
         >:: test_buy_limit_executes_when_ask_below_limit;
         "test_buy_limit_does_not_execute_when_ask_above_limit"
         >:: test_buy_limit_does_not_execute_when_ask_above_limit;
         "test_sell_limit_executes_when_bid_at_limit"
         >:: test_sell_limit_executes_when_bid_at_limit;
         "test_sell_limit_executes_when_bid_above_limit"
         >:: test_sell_limit_executes_when_bid_above_limit;
         "test_sell_limit_does_not_execute_when_bid_below_limit"
         >:: test_sell_limit_does_not_execute_when_bid_below_limit;
       ]

let () = run_test_tt_main suite
