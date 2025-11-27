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

(* Common test setup: creates engine, order manager, submits order, updates market *)
let setup_order_test ~order_type ~side ?(symbol = "AAPL") ?(quantity = 100.0)
    ~quote () =
  let config = make_config () in
  let engine = create config in
  let order_mgr = OrderManager.create () in
  let params = make_order_params ~symbol ~side ~order_type ~quantity () in
  let order =
    match create_order ~now_time:test_timestamp params with
    | Ok order -> order
    | Error err -> failwith ("Failed to create order: " ^ Status.show err)
  in
  submit_single_order order_mgr order;
  update_market engine [ quote ];
  (engine, order_mgr, order)

(* Assert that order was not executed and remains pending *)
let assert_order_not_executed engine order_mgr =
  assert_that (process_orders engine order_mgr) (is_ok_and_holds (equal_to []));
  let pending = OrderManager.list_orders order_mgr ~filter:ActiveOnly in
  assert_that pending (size_is 1)

(* Assert that order was executed with expected trade details *)
let assert_order_executed engine order_mgr order ~price =
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
                         symbol = order.symbol;
                         side = order.side;
                         quantity = order.quantity;
                         price;
                         commission = 1.0;
                         timestamp = Time_ns_unix.epoch;
                       }));
             ])))

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
    match create_order ~now_time:test_timestamp params with
    | Ok order -> order
    | Error err -> failwith ("Failed to create order: " ^ Status.show err)
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
    match create_order ~now_time:test_timestamp params with
    | Ok order -> order
    | Error err -> failwith ("Failed to create order: " ^ Status.show err)
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
    match create_order ~now_time:test_timestamp params with
    | Ok order -> order
    | Error err -> failwith ("Failed to create order: " ^ Status.show err)
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
    match create_order ~now_time:test_timestamp params with
    | Ok order -> order
    | Error err -> failwith ("Failed to create order: " ^ Status.show err)
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
    match create_order ~now_time:test_timestamp params with
    | Ok order -> order
    | Error err -> failwith ("Failed to create order: " ^ Status.show err)
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
    match create_order ~now_time:test_timestamp params with
    | Ok order -> order
    | Error err -> failwith ("Failed to create order: " ^ Status.show err)
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
    match create_order ~now_time:test_timestamp params with
    | Ok order -> order
    | Error err -> failwith ("Failed to create order: " ^ Status.show err)
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
        match create_order ~now_time:test_timestamp params with
        | Ok order -> order
        | Error err -> failwith ("Failed to create order: " ^ Status.show err))
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
  let quote =
    make_quote "AAPL" ~bid:(Some 150.0) ~ask:(Some 150.50) ~last:(Some 150.25)
  in
  let engine, order_mgr, order =
    setup_order_test ~order_type:(Limit 150.50) ~side:Buy ~quote ()
  in
  assert_order_executed engine order_mgr order ~price:150.50

let test_buy_limit_executes_when_ask_below_limit _ =
  let quote =
    make_quote "AAPL" ~bid:(Some 150.0) ~ask:(Some 150.50) ~last:(Some 150.25)
  in
  let engine, order_mgr, order =
    setup_order_test ~order_type:(Limit 151.00) ~side:Buy ~quote ()
  in
  (* Should execute at ask price (150.50, better than limit) *)
  assert_order_executed engine order_mgr order ~price:150.50

let test_buy_limit_does_not_execute_when_ask_above_limit _ =
  let quote =
    make_quote "AAPL" ~bid:(Some 150.0) ~ask:(Some 150.50) ~last:(Some 150.25)
  in
  let engine, order_mgr, _ =
    setup_order_test ~order_type:(Limit 150.00) ~side:Buy ~quote ()
  in
  assert_order_not_executed engine order_mgr

let test_sell_limit_executes_when_bid_at_limit _ =
  let quote =
    make_quote "AAPL" ~bid:(Some 150.00) ~ask:(Some 150.50) ~last:(Some 150.25)
  in
  let engine, order_mgr, order =
    setup_order_test ~order_type:(Limit 150.00) ~side:Sell ~quote ()
  in
  assert_order_executed engine order_mgr order ~price:150.00

let test_sell_limit_executes_when_bid_above_limit _ =
  let quote =
    make_quote "AAPL" ~bid:(Some 150.50) ~ask:(Some 151.00) ~last:(Some 150.75)
  in
  let engine, order_mgr, order =
    setup_order_test ~order_type:(Limit 150.00) ~side:Sell ~quote ()
  in
  (* Should execute at bid price (150.50, better than limit) *)
  assert_order_executed engine order_mgr order ~price:150.50

let test_sell_limit_does_not_execute_when_bid_below_limit _ =
  let quote =
    make_quote "AAPL" ~bid:(Some 150.00) ~ask:(Some 150.50) ~last:(Some 150.25)
  in
  let engine, order_mgr, _ =
    setup_order_test ~order_type:(Limit 150.50) ~side:Sell ~quote ()
  in
  assert_order_not_executed engine order_mgr

(* Stop order tests *)
let test_buy_stop_executes_when_last_at_stop _ =
  let quote =
    make_quote "AAPL" ~bid:(Some 150.50) ~ask:(Some 151.50) ~last:(Some 151.00)
  in
  let engine, order_mgr, order =
    setup_order_test ~order_type:(Stop 151.00) ~side:Buy ~quote ()
  in
  assert_order_executed engine order_mgr order ~price:151.00

let test_buy_stop_executes_when_last_above_stop _ =
  let quote =
    make_quote "AAPL" ~bid:(Some 150.50) ~ask:(Some 151.50) ~last:(Some 151.00)
  in
  let engine, order_mgr, order =
    setup_order_test ~order_type:(Stop 150.00) ~side:Buy ~quote ()
  in
  (* Should execute at last price (151.00) on breakout *)
  assert_order_executed engine order_mgr order ~price:151.00

let test_buy_stop_does_not_execute_when_last_below_stop _ =
  let quote =
    make_quote "AAPL" ~bid:(Some 150.00) ~ask:(Some 151.00) ~last:(Some 150.50)
  in
  let engine, order_mgr, _ =
    setup_order_test ~order_type:(Stop 151.00) ~side:Buy ~quote ()
  in
  assert_order_not_executed engine order_mgr

let test_sell_stop_executes_when_last_at_stop _ =
  let quote =
    make_quote "AAPL" ~bid:(Some 148.50) ~ask:(Some 149.50) ~last:(Some 149.00)
  in
  let engine, order_mgr, order =
    setup_order_test ~order_type:(Stop 149.00) ~side:Sell ~quote ()
  in
  assert_order_executed engine order_mgr order ~price:149.00

let test_sell_stop_executes_when_last_below_stop _ =
  let quote =
    make_quote "AAPL" ~bid:(Some 147.50) ~ask:(Some 148.50) ~last:(Some 148.00)
  in
  let engine, order_mgr, order =
    setup_order_test ~order_type:(Stop 150.00) ~side:Sell ~quote ()
  in
  (* Should execute at last price (148.00) on stop-loss trigger *)
  assert_order_executed engine order_mgr order ~price:148.00

let test_sell_stop_does_not_execute_when_last_above_stop _ =
  let quote =
    make_quote "AAPL" ~bid:(Some 149.50) ~ask:(Some 150.50) ~last:(Some 150.00)
  in
  let engine, order_mgr, _ =
    setup_order_test ~order_type:(Stop 149.00) ~side:Sell ~quote ()
  in
  assert_order_not_executed engine order_mgr

let test_stop_order_requires_last_price _ =
  let quote =
    make_quote "AAPL" ~bid:(Some 150.00) ~ask:(Some 150.50) ~last:None
  in
  let engine, order_mgr, _ =
    setup_order_test ~order_type:(Stop 150.00) ~side:Buy ~quote ()
  in
  assert_order_not_executed engine order_mgr

(* StopLimit order tests *)

(* Buy StopLimit: triggers when last >= stop_price, executes when ask <= limit_price *)
let test_buy_stop_limit_executes_when_both_conditions_met _ =
  (* last = 151.50 triggers stop at 151.00, ask = 151.75 below limit 152.00 *)
  let quote =
    make_quote "AAPL" ~bid:(Some 151.25) ~ask:(Some 151.75) ~last:(Some 151.50)
  in
  let engine, order_mgr, order =
    setup_order_test
      ~order_type:(StopLimit (151.00, 152.00))
      ~side:Buy ~quote ()
  in
  assert_order_executed engine order_mgr order ~price:151.75

let test_buy_stop_limit_executes_when_ask_at_limit _ =
  (* last = 150.50 triggers stop at 150.00, ask = 151.00 exactly at limit *)
  let quote =
    make_quote "AAPL" ~bid:(Some 150.50) ~ask:(Some 151.00) ~last:(Some 150.50)
  in
  let engine, order_mgr, order =
    setup_order_test
      ~order_type:(StopLimit (150.00, 151.00))
      ~side:Buy ~quote ()
  in
  assert_order_executed engine order_mgr order ~price:151.00

let test_buy_stop_limit_does_not_execute_when_stop_not_triggered _ =
  (* last = 151.00 below stop at 152.00 *)
  let quote =
    make_quote "AAPL" ~bid:(Some 151.00) ~ask:(Some 152.50) ~last:(Some 151.00)
  in
  let engine, order_mgr, _ =
    setup_order_test
      ~order_type:(StopLimit (152.00, 153.00))
      ~side:Buy ~quote ()
  in
  assert_order_not_executed engine order_mgr

let test_buy_stop_limit_does_not_execute_when_ask_above_limit _ =
  (* last = 150.50 triggers stop, but ask = 151.50 above limit 151.00 *)
  let quote =
    make_quote "AAPL" ~bid:(Some 151.00) ~ask:(Some 151.50) ~last:(Some 150.50)
  in
  let engine, order_mgr, _ =
    setup_order_test
      ~order_type:(StopLimit (150.00, 151.00))
      ~side:Buy ~quote ()
  in
  assert_order_not_executed engine order_mgr

(* Sell StopLimit: triggers when last <= stop_price, executes when bid >= limit_price *)
let test_sell_stop_limit_executes_when_both_conditions_met _ =
  (* last = 149.50 triggers stop at 150.00, bid = 149.25 above limit 149.00 *)
  let quote =
    make_quote "AAPL" ~bid:(Some 149.25) ~ask:(Some 149.75) ~last:(Some 149.50)
  in
  let engine, order_mgr, order =
    setup_order_test
      ~order_type:(StopLimit (150.00, 149.00))
      ~side:Sell ~quote ()
  in
  assert_order_executed engine order_mgr order ~price:149.25

let test_sell_stop_limit_executes_when_bid_at_limit _ =
  (* last = 149.50 triggers stop, bid = 149.00 exactly at limit *)
  let quote =
    make_quote "AAPL" ~bid:(Some 149.00) ~ask:(Some 149.50) ~last:(Some 149.50)
  in
  let engine, order_mgr, order =
    setup_order_test
      ~order_type:(StopLimit (150.00, 149.00))
      ~side:Sell ~quote ()
  in
  assert_order_executed engine order_mgr order ~price:149.00

let test_sell_stop_limit_does_not_execute_when_stop_not_triggered _ =
  (* last = 149.00 above stop at 148.00 *)
  let quote =
    make_quote "AAPL" ~bid:(Some 148.50) ~ask:(Some 149.50) ~last:(Some 149.00)
  in
  let engine, order_mgr, _ =
    setup_order_test
      ~order_type:(StopLimit (148.00, 147.00))
      ~side:Sell ~quote ()
  in
  assert_order_not_executed engine order_mgr

let test_sell_stop_limit_does_not_execute_when_bid_below_limit _ =
  (* last = 149.50 triggers stop, but bid = 148.50 below limit 149.00 *)
  let quote =
    make_quote "AAPL" ~bid:(Some 148.50) ~ask:(Some 149.75) ~last:(Some 149.50)
  in
  let engine, order_mgr, _ =
    setup_order_test
      ~order_type:(StopLimit (150.00, 149.00))
      ~side:Sell ~quote ()
  in
  assert_order_not_executed engine order_mgr

let test_stop_limit_requires_last_price _ =
  let quote =
    make_quote "AAPL" ~bid:(Some 150.00) ~ask:(Some 150.50) ~last:None
  in
  let engine, order_mgr, _ =
    setup_order_test
      ~order_type:(StopLimit (150.00, 151.00))
      ~side:Buy ~quote ()
  in
  assert_order_not_executed engine order_mgr

let test_stop_limit_requires_bid_ask_price _ =
  (* last triggers stop, but no ask price for limit check *)
  let quote =
    make_quote "AAPL" ~bid:(Some 150.00) ~ask:None ~last:(Some 150.50)
  in
  let engine, order_mgr, _ =
    setup_order_test
      ~order_type:(StopLimit (150.00, 151.00))
      ~side:Buy ~quote ()
  in
  assert_order_not_executed engine order_mgr

(* Mini-bar processing tests *)
let make_mini_bar ~time_fraction ~open_price ~close_price =
  { time_fraction; open_price; close_price }

let test_process_mini_bars_market_order _ =
  let config = make_config () in
  let engine = create config in
  let order_mgr = OrderManager.create () in
  (* Submit market order *)
  let params =
    make_order_params ~symbol:"AAPL" ~side:Buy ~order_type:Market
      ~quantity:100.0 ()
  in
  let order =
    match create_order ~now_time:test_timestamp params with
    | Ok order -> order
    | Error err -> failwith ("Failed to create order: " ^ Status.show err)
  in
  submit_single_order order_mgr order;
  (* Process mini-bars: market order should execute at first bar's close *)
  let mini_bars =
    [
      make_mini_bar ~time_fraction:0.0 ~open_price:100.0 ~close_price:100.0;
      make_mini_bar ~time_fraction:0.25 ~open_price:100.0 ~close_price:105.0;
    ]
  in
  assert_that
    (process_mini_bars engine "AAPL" order_mgr mini_bars)
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
                         price = 100.0;
                         commission = 1.0;
                         timestamp = Time_ns_unix.epoch;
                       }));
             ])))

let test_process_mini_bars_buy_limit_crosses_down _ =
  let config = make_config () in
  let engine = create config in
  let order_mgr = OrderManager.create () in
  (* Submit buy limit at 100.0 *)
  let params =
    make_order_params ~symbol:"AAPL" ~side:Buy ~order_type:(Limit 100.0)
      ~quantity:100.0 ()
  in
  let order =
    match create_order ~now_time:test_timestamp params with
    | Ok order -> order
    | Error err -> failwith ("Failed to create order: " ^ Status.show err)
  in
  submit_single_order order_mgr order;
  (* Mini-bars: price crosses down through limit *)
  let mini_bars =
    [
      make_mini_bar ~time_fraction:0.0 ~open_price:105.0 ~close_price:105.0;
      make_mini_bar ~time_fraction:0.25 ~open_price:105.0 ~close_price:95.0;
    ]
  in
  assert_that
    (process_mini_bars engine "AAPL" order_mgr mini_bars)
    (is_ok_and_holds
       (one
          (field
             (fun (r : execution_report) -> r.trades)
             (one (field (fun (t : trade) -> t.price) (equal_to 100.0))))))

let test_process_mini_bars_sell_limit_crosses_up _ =
  let config = make_config () in
  let engine = create config in
  let order_mgr = OrderManager.create () in
  (* Submit sell limit at 110.0 *)
  let params =
    make_order_params ~symbol:"AAPL" ~side:Sell ~order_type:(Limit 110.0)
      ~quantity:100.0 ()
  in
  let order =
    match create_order ~now_time:test_timestamp params with
    | Ok order -> order
    | Error err -> failwith ("Failed to create order: " ^ Status.show err)
  in
  submit_single_order order_mgr order;
  (* Mini-bars: price crosses up through limit *)
  let mini_bars =
    [
      make_mini_bar ~time_fraction:0.0 ~open_price:105.0 ~close_price:105.0;
      make_mini_bar ~time_fraction:0.25 ~open_price:105.0 ~close_price:115.0;
    ]
  in
  assert_that
    (process_mini_bars engine "AAPL" order_mgr mini_bars)
    (is_ok_and_holds
       (one
          (field
             (fun (r : execution_report) -> r.trades)
             (one (field (fun (t : trade) -> t.price) (equal_to 110.0))))))

let test_process_mini_bars_buy_stop_triggers _ =
  let config = make_config () in
  let engine = create config in
  let order_mgr = OrderManager.create () in
  (* Submit buy stop at 105.0 *)
  let params =
    make_order_params ~symbol:"AAPL" ~side:Buy ~order_type:(Stop 105.0)
      ~quantity:100.0 ()
  in
  let order =
    match create_order ~now_time:test_timestamp params with
    | Ok order -> order
    | Error err -> failwith ("Failed to create order: " ^ Status.show err)
  in
  submit_single_order order_mgr order;
  (* Mini-bars: price rises to trigger stop *)
  let mini_bars =
    [
      make_mini_bar ~time_fraction:0.0 ~open_price:100.0 ~close_price:100.0;
      make_mini_bar ~time_fraction:0.25 ~open_price:100.0 ~close_price:105.0;
    ]
  in
  assert_that
    (process_mini_bars engine "AAPL" order_mgr mini_bars)
    (is_ok_and_holds
       (one
          (field
             (fun (r : execution_report) -> r.trades)
             (one (field (fun (t : trade) -> t.price) (equal_to 105.0))))))

let test_process_mini_bars_sell_stop_triggers _ =
  let config = make_config () in
  let engine = create config in
  let order_mgr = OrderManager.create () in
  (* Submit sell stop at 95.0 *)
  let params =
    make_order_params ~symbol:"AAPL" ~side:Sell ~order_type:(Stop 95.0)
      ~quantity:100.0 ()
  in
  let order =
    match create_order ~now_time:test_timestamp params with
    | Ok order -> order
    | Error err -> failwith ("Failed to create order: " ^ Status.show err)
  in
  submit_single_order order_mgr order;
  (* Mini-bars: price drops to trigger stop *)
  let mini_bars =
    [
      make_mini_bar ~time_fraction:0.0 ~open_price:100.0 ~close_price:100.0;
      make_mini_bar ~time_fraction:0.25 ~open_price:100.0 ~close_price:95.0;
    ]
  in
  assert_that
    (process_mini_bars engine "AAPL" order_mgr mini_bars)
    (is_ok_and_holds
       (one
          (field
             (fun (r : execution_report) -> r.trades)
             (one (field (fun (t : trade) -> t.price) (equal_to 95.0))))))

let test_process_mini_bars_stop_limit_triggers_and_fills _ =
  let config = make_config () in
  let engine = create config in
  let order_mgr = OrderManager.create () in
  (* Submit buy stop-limit: stop at 105.0, limit at 110.0 *)
  let params =
    make_order_params ~symbol:"AAPL" ~side:Buy
      ~order_type:(StopLimit (105.0, 110.0))
      ~quantity:100.0 ()
  in
  let order =
    match create_order ~now_time:test_timestamp params with
    | Ok order -> order
    | Error err -> failwith ("Failed to create order: " ^ Status.show err)
  in
  submit_single_order order_mgr order;
  (* Mini-bars: stop triggers at 105.0, fills immediately since 105.0 <= 110.0 *)
  let mini_bars =
    [
      make_mini_bar ~time_fraction:0.0 ~open_price:100.0 ~close_price:100.0;
      make_mini_bar ~time_fraction:0.25 ~open_price:100.0 ~close_price:105.0;
    ]
  in
  assert_that
    (process_mini_bars engine "AAPL" order_mgr mini_bars)
    (is_ok_and_holds
       (one
          (field
             (fun (r : execution_report) -> r.trades)
             (one (field (fun (t : trade) -> t.price) (equal_to 105.0))))))

let test_process_mini_bars_stop_limit_waits_for_limit _ =
  let config = make_config () in
  let engine = create config in
  let order_mgr = OrderManager.create () in
  (* Submit sell stop-limit: stop at 100.0, limit at 98.0 *)
  let params =
    make_order_params ~symbol:"AAPL" ~side:Sell
      ~order_type:(StopLimit (100.0, 98.0))
      ~quantity:100.0 ()
  in
  let order =
    match create_order ~now_time:test_timestamp params with
    | Ok order -> order
    | Error err -> failwith ("Failed to create order: " ^ Status.show err)
  in
  submit_single_order order_mgr order;
  (* Mini-bars: stop triggers at 95.0 (below limit), then limit fills at 99.0 *)
  let mini_bars =
    [
      make_mini_bar ~time_fraction:0.0 ~open_price:105.0 ~close_price:105.0;
      make_mini_bar ~time_fraction:0.25 ~open_price:105.0 ~close_price:95.0;
      make_mini_bar ~time_fraction:0.5 ~open_price:95.0 ~close_price:99.0;
    ]
  in
  assert_that
    (process_mini_bars engine "AAPL" order_mgr mini_bars)
    (is_ok_and_holds
       (one
          (field
             (fun (r : execution_report) -> r.trades)
             (one (field (fun (t : trade) -> t.price) (equal_to 98.0))))))

let test_process_mini_bars_no_fill_for_different_symbol _ =
  let config = make_config () in
  let engine = create config in
  let order_mgr = OrderManager.create () in
  (* Submit order for AAPL *)
  let params =
    make_order_params ~symbol:"AAPL" ~side:Buy ~order_type:Market
      ~quantity:100.0 ()
  in
  let order =
    match create_order ~now_time:test_timestamp params with
    | Ok order -> order
    | Error err -> failwith ("Failed to create order: " ^ Status.show err)
  in
  submit_single_order order_mgr order;
  (* Process mini-bars for GOOGL (different symbol) *)
  let mini_bars =
    [ make_mini_bar ~time_fraction:0.0 ~open_price:100.0 ~close_price:100.0 ]
  in
  assert_that
    (process_mini_bars engine "GOOGL" order_mgr mini_bars)
    (is_ok_and_holds (equal_to []))

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
         "test_buy_stop_executes_when_last_at_stop"
         >:: test_buy_stop_executes_when_last_at_stop;
         "test_buy_stop_executes_when_last_above_stop"
         >:: test_buy_stop_executes_when_last_above_stop;
         "test_buy_stop_does_not_execute_when_last_below_stop"
         >:: test_buy_stop_does_not_execute_when_last_below_stop;
         "test_sell_stop_executes_when_last_at_stop"
         >:: test_sell_stop_executes_when_last_at_stop;
         "test_sell_stop_executes_when_last_below_stop"
         >:: test_sell_stop_executes_when_last_below_stop;
         "test_sell_stop_does_not_execute_when_last_above_stop"
         >:: test_sell_stop_does_not_execute_when_last_above_stop;
         "test_stop_order_requires_last_price"
         >:: test_stop_order_requires_last_price;
         "test_buy_stop_limit_executes_when_both_conditions_met"
         >:: test_buy_stop_limit_executes_when_both_conditions_met;
         "test_buy_stop_limit_executes_when_ask_at_limit"
         >:: test_buy_stop_limit_executes_when_ask_at_limit;
         "test_buy_stop_limit_does_not_execute_when_stop_not_triggered"
         >:: test_buy_stop_limit_does_not_execute_when_stop_not_triggered;
         "test_buy_stop_limit_does_not_execute_when_ask_above_limit"
         >:: test_buy_stop_limit_does_not_execute_when_ask_above_limit;
         "test_sell_stop_limit_executes_when_both_conditions_met"
         >:: test_sell_stop_limit_executes_when_both_conditions_met;
         "test_sell_stop_limit_executes_when_bid_at_limit"
         >:: test_sell_stop_limit_executes_when_bid_at_limit;
         "test_sell_stop_limit_does_not_execute_when_stop_not_triggered"
         >:: test_sell_stop_limit_does_not_execute_when_stop_not_triggered;
         "test_sell_stop_limit_does_not_execute_when_bid_below_limit"
         >:: test_sell_stop_limit_does_not_execute_when_bid_below_limit;
         "test_stop_limit_requires_last_price"
         >:: test_stop_limit_requires_last_price;
         "test_stop_limit_requires_bid_ask_price"
         >:: test_stop_limit_requires_bid_ask_price;
         (* Mini-bar processing tests *)
         "test_process_mini_bars_market_order"
         >:: test_process_mini_bars_market_order;
         "test_process_mini_bars_buy_limit_crosses_down"
         >:: test_process_mini_bars_buy_limit_crosses_down;
         "test_process_mini_bars_sell_limit_crosses_up"
         >:: test_process_mini_bars_sell_limit_crosses_up;
         "test_process_mini_bars_buy_stop_triggers"
         >:: test_process_mini_bars_buy_stop_triggers;
         "test_process_mini_bars_sell_stop_triggers"
         >:: test_process_mini_bars_sell_stop_triggers;
         "test_process_mini_bars_stop_limit_triggers_and_fills"
         >:: test_process_mini_bars_stop_limit_triggers_and_fills;
         "test_process_mini_bars_stop_limit_waits_for_limit"
         >:: test_process_mini_bars_stop_limit_waits_for_limit;
         "test_process_mini_bars_no_fill_for_different_symbol"
         >:: test_process_mini_bars_no_fill_for_different_symbol;
       ]

let () = run_test_tt_main suite
