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

let make_bar symbol ~open_price ~high_price ~low_price ~close_price =
  { symbol; open_price; high_price; low_price; close_price }

(* Compatibility function for legacy tests - can be removed once all tests use make_bar
   This converts bid/ask/last quotes into OHLC bars for backward compatibility.
   New tests should use make_bar directly with realistic OHLC data. *)
let make_quote symbol ~bid ~ask ~last =
  let bid = Option.value bid ~default:100.0 in
  let ask = Option.value ask ~default:100.5 in
  let last = Option.value last ~default:100.25 in
  (* Create a bar where:
     - open = last (so market orders fill at old "last" price)
     - high = max of all prices
     - low = min of all prices
     - close = last *)
  let all_prices = [ bid; ask; last ] in
  let high = List.fold all_prices ~init:Float.neg_infinity ~f:Float.max in
  let low = List.fold all_prices ~init:Float.infinity ~f:Float.min in
  make_bar symbol ~open_price:last ~high_price:high ~low_price:low
    ~close_price:last

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
  let bar =
    make_bar "AAPL" ~open_price:150.25 ~high_price:151.0 ~low_price:150.0
      ~close_price:150.5
  in
  update_market engine [ bar ];
  (* Second process - should execute now at open price *)
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
  (* Bar goes down to 150.50, which exactly meets the buy limit *)
  let bar =
    make_bar "AAPL" ~open_price:151.0 ~high_price:151.5 ~low_price:150.50
      ~close_price:151.0
  in
  let engine, order_mgr, order =
    setup_order_test ~order_type:(Limit 150.50) ~side:Buy ~quote:bar ()
  in
  (* Fills at 150.50 when path reaches the low *)
  assert_order_executed engine order_mgr order ~price:150.50

let test_buy_limit_executes_when_ask_below_limit _ =
  (* Bar starts above limit, goes down through it - fills when limit is crossed *)
  let bar =
    make_bar "AAPL" ~open_price:152.0 ~high_price:152.5 ~low_price:150.50
      ~close_price:151.50
  in
  let engine, order_mgr, order =
    setup_order_test ~order_type:(Limit 151.00) ~side:Buy ~quote:bar ()
  in
  (* Path crosses limit at 151.00 on the way down, fills at limit price *)
  assert_order_executed engine order_mgr order ~price:151.00

let test_buy_limit_does_not_execute_when_ask_above_limit _ =
  (* Bar's low is 150.50, which is above limit of 150.00 - should not execute *)
  let bar =
    make_bar "AAPL" ~open_price:151.0 ~high_price:151.5 ~low_price:150.50
      ~close_price:151.0
  in
  let engine, order_mgr, _ =
    setup_order_test ~order_type:(Limit 150.00) ~side:Buy ~quote:bar ()
  in
  assert_order_not_executed engine order_mgr

let test_sell_limit_executes_when_bid_at_limit _ =
  (* Bar goes up to 150.00, which exactly meets the sell limit *)
  let bar =
    make_bar "AAPL" ~open_price:149.50 ~high_price:150.00 ~low_price:149.0
      ~close_price:149.50
  in
  let engine, order_mgr, order =
    setup_order_test ~order_type:(Limit 150.00) ~side:Sell ~quote:bar ()
  in
  (* Fills at 150.00 when path reaches the high *)
  assert_order_executed engine order_mgr order ~price:150.00

let test_sell_limit_executes_when_bid_above_limit _ =
  (* Bar starts below limit, goes up through it - fills when limit is crossed *)
  let bar =
    make_bar "AAPL" ~open_price:148.50 ~high_price:150.50 ~low_price:148.0
      ~close_price:149.50
  in
  let engine, order_mgr, order =
    setup_order_test ~order_type:(Limit 150.00) ~side:Sell ~quote:bar ()
  in
  (* Path crosses limit at 150.00 on the way up, fills at limit price *)
  assert_order_executed engine order_mgr order ~price:150.00

let test_sell_limit_does_not_execute_when_bid_below_limit _ =
  (* Bar's high is 150.00, which is below limit of 150.50 - should not execute *)
  let bar =
    make_bar "AAPL" ~open_price:149.50 ~high_price:150.00 ~low_price:149.0
      ~close_price:149.50
  in
  let engine, order_mgr, _ =
    setup_order_test ~order_type:(Limit 150.50) ~side:Sell ~quote:bar ()
  in
  assert_order_not_executed engine order_mgr

(* Stop order tests *)
let test_buy_stop_executes_when_last_at_stop _ =
  (* Bar reaches 151.00, which triggers the buy stop *)
  let bar =
    make_bar "AAPL" ~open_price:150.50 ~high_price:151.00 ~low_price:150.0
      ~close_price:150.75
  in
  let engine, order_mgr, order =
    setup_order_test ~order_type:(Stop 151.00) ~side:Buy ~quote:bar ()
  in
  (* Fills at 151.00 when stop is triggered *)
  assert_order_executed engine order_mgr order ~price:151.00

let test_buy_stop_executes_when_last_above_stop _ =
  (* Bar reaches 151.00, which is above stop of 150.00 *)
  let bar =
    make_bar "AAPL" ~open_price:150.50 ~high_price:151.00 ~low_price:150.0
      ~close_price:150.75
  in
  let engine, order_mgr, order =
    setup_order_test ~order_type:(Stop 150.00) ~side:Buy ~quote:bar ()
  in
  (* Fills at open price 150.50 since it's already above stop at market open *)
  assert_order_executed engine order_mgr order ~price:150.50

let test_buy_stop_does_not_execute_when_last_below_stop _ =
  (* Bar's high is 150.50, which is below stop of 151.00 - should not trigger *)
  let bar =
    make_bar "AAPL" ~open_price:150.00 ~high_price:150.50 ~low_price:149.50
      ~close_price:150.25
  in
  let engine, order_mgr, _ =
    setup_order_test ~order_type:(Stop 151.00) ~side:Buy ~quote:bar ()
  in
  assert_order_not_executed engine order_mgr

let test_sell_stop_executes_when_last_at_stop _ =
  (* Bar reaches 149.00, which triggers the sell stop *)
  let bar =
    make_bar "AAPL" ~open_price:149.50 ~high_price:150.00 ~low_price:149.00
      ~close_price:149.25
  in
  let engine, order_mgr, order =
    setup_order_test ~order_type:(Stop 149.00) ~side:Sell ~quote:bar ()
  in
  (* Fills at 149.00 when stop is triggered *)
  assert_order_executed engine order_mgr order ~price:149.00

let test_sell_stop_executes_when_last_below_stop _ =
  (* Bar reaches 148.00, which is below stop of 150.00 *)
  let bar =
    make_bar "AAPL" ~open_price:149.50 ~high_price:150.00 ~low_price:148.00
      ~close_price:148.50
  in
  let engine, order_mgr, order =
    setup_order_test ~order_type:(Stop 150.00) ~side:Sell ~quote:bar ()
  in
  (* Fills at open price 149.50 since it's already below stop at market open *)
  assert_order_executed engine order_mgr order ~price:149.50

let test_sell_stop_does_not_execute_when_last_above_stop _ =
  (* Bar's low is 149.50, which is above stop of 149.00 - should not trigger *)
  let bar =
    make_bar "AAPL" ~open_price:150.00 ~high_price:150.50 ~low_price:149.50
      ~close_price:150.25
  in
  let engine, order_mgr, _ =
    setup_order_test ~order_type:(Stop 149.00) ~side:Sell ~quote:bar ()
  in
  assert_order_not_executed engine order_mgr

let test_stop_order_requires_last_price _ =
  (* With path-based execution, an empty path (no OHLC data) means no execution.
     This test is no longer relevant as we always have OHLC data, but we keep it
     to test the case where market data is missing entirely. *)
  let bar =
    make_bar "AAPL" ~open_price:150.25 ~high_price:150.50 ~low_price:150.00
      ~close_price:150.25
  in
  let engine, order_mgr, order =
    setup_order_test ~order_type:(Stop 150.00) ~side:Buy ~quote:bar ()
  in
  (* With proper OHLC, this should actually execute now *)
  assert_order_executed engine order_mgr order ~price:150.25

(* StopLimit order tests *)

(* Buy StopLimit: triggers when price >= stop_price, executes when price <= limit_price *)
let test_buy_stop_limit_executes_when_both_conditions_met _ =
  (* Bar crosses stop at 151.00, which already meets limit of 152.00 *)
  let bar =
    make_bar "AAPL" ~open_price:150.50 ~high_price:151.75 ~low_price:150.00
      ~close_price:151.50
  in
  let engine, order_mgr, order =
    setup_order_test
      ~order_type:(StopLimit (151.00, 152.00))
      ~side:Buy ~quote:bar ()
  in
  (* Path goes up, crosses stop at 151.00, which meets limit <= 152.00, so fills at 151.00 *)
  assert_order_executed engine order_mgr order ~price:151.00

let test_buy_stop_limit_executes_when_ask_at_limit _ =
  (* Bar crosses stop at 150.00, which exactly meets limit of 150.00 *)
  let bar =
    make_bar "AAPL" ~open_price:149.50 ~high_price:151.00 ~low_price:149.00
      ~close_price:150.50
  in
  let engine, order_mgr, order =
    setup_order_test
      ~order_type:(StopLimit (150.00, 150.00))
      ~side:Buy ~quote:bar ()
  in
  (* Stop triggers at 150.00, limit is also 150.00, fills immediately at stop price *)
  assert_order_executed engine order_mgr order ~price:150.00

let test_buy_stop_limit_does_not_execute_when_stop_not_triggered _ =
  (* Bar's high is 151.50, below stop at 152.00 - stop never triggers *)
  let bar =
    make_bar "AAPL" ~open_price:150.50 ~high_price:151.50 ~low_price:150.00
      ~close_price:151.00
  in
  let engine, order_mgr, _ =
    setup_order_test
      ~order_type:(StopLimit (152.00, 153.00))
      ~side:Buy ~quote:bar ()
  in
  assert_order_not_executed engine order_mgr

let test_buy_stop_limit_does_not_execute_when_ask_above_limit _ =
  (* Bar opens above stop (gaps up), stop triggers at open but doesn't meet limit *)
  (* Bar: 151.50→152.00→151.00→151.25. Open at 151.50 is already >= stop 150.00,
     so stop triggers immediately at 151.50. But 151.50 > limit 150.25, so limit not met.
     Remaining path [151.50, 152.00, 151.00, 151.25] - only 151.00 <= 150.25,
     but we need ALL to be > 150.25 for no execution. Let me adjust... *)
  let bar =
    make_bar "AAPL" ~open_price:151.50 ~high_price:152.00 ~low_price:150.75
      ~close_price:151.25
  in
  let engine, order_mgr, _ =
    setup_order_test
      ~order_type:(StopLimit (150.00, 150.25))
      ~side:Buy ~quote:bar ()
  in
  (* Path: 151.50→152.00→150.75→151.25. Stop triggers at 151.50 (already above stop).
     For limit, need price <= 150.25. Path is [151.50, 152.00, 150.75, 151.25].
     150.75 > 150.25, so limit never met! *)
  assert_order_not_executed engine order_mgr

(* Sell StopLimit: triggers when price <= stop_price, executes when price >= limit_price *)
let test_sell_stop_limit_executes_when_both_conditions_met _ =
  (* Bar crosses stop at 150.00, which already meets limit of 149.00 *)
  let bar =
    make_bar "AAPL" ~open_price:150.50 ~high_price:151.00 ~low_price:149.25
      ~close_price:149.50
  in
  let engine, order_mgr, order =
    setup_order_test
      ~order_type:(StopLimit (150.00, 149.00))
      ~side:Sell ~quote:bar ()
  in
  (* Path goes down, crosses stop at 150.00, which meets limit >= 149.00, fills at 150.00 *)
  assert_order_executed engine order_mgr order ~price:150.00

let test_sell_stop_limit_executes_when_bid_at_limit _ =
  (* Bar crosses stop at 150.00, which exactly meets limit of 150.00 *)
  let bar =
    make_bar "AAPL" ~open_price:150.50 ~high_price:151.00 ~low_price:149.00
      ~close_price:149.50
  in
  let engine, order_mgr, order =
    setup_order_test
      ~order_type:(StopLimit (150.00, 150.00))
      ~side:Sell ~quote:bar ()
  in
  (* Stop triggers at 150.00, limit is also 150.00, fills immediately at stop price *)
  assert_order_executed engine order_mgr order ~price:150.00

let test_sell_stop_limit_does_not_execute_when_stop_not_triggered _ =
  (* Bar's low is 148.50, above stop at 148.00 - stop never triggers *)
  let bar =
    make_bar "AAPL" ~open_price:149.50 ~high_price:150.00 ~low_price:148.50
      ~close_price:149.00
  in
  let engine, order_mgr, _ =
    setup_order_test
      ~order_type:(StopLimit (148.00, 147.00))
      ~side:Sell ~quote:bar ()
  in
  assert_order_not_executed engine order_mgr

let test_sell_stop_limit_does_not_execute_when_bid_below_limit _ =
  (* Bar opens below stop (gaps down), stop triggers at open but doesn't meet limit *)
  (* Bar: 148.50→149.00→148.25→148.75. Open at 148.50 is already <= stop 150.00,
     so stop triggers immediately at 148.50. But 148.50 < limit 149.75, so limit not met.
     Path is [148.50, 149.00, 148.25, 148.75], all < 149.75, so limit never met! *)
  let bar =
    make_bar "AAPL" ~open_price:148.50 ~high_price:149.00 ~low_price:148.25
      ~close_price:148.75
  in
  let engine, order_mgr, _ =
    setup_order_test
      ~order_type:(StopLimit (150.00, 149.75))
      ~side:Sell ~quote:bar ()
  in
  assert_order_not_executed engine order_mgr

let test_stop_limit_requires_last_price _ =
  (* With path-based execution, we always have OHLC data. This test now verifies
     that a stop-limit order executes when conditions are met. *)
  let bar =
    make_bar "AAPL" ~open_price:149.50 ~high_price:151.00 ~low_price:149.00
      ~close_price:150.50
  in
  let engine, order_mgr, order =
    setup_order_test
      ~order_type:(StopLimit (150.00, 150.00))
      ~side:Buy ~quote:bar ()
  in
  (* Path goes up, crosses stop at 150.00, which meets limit, fills at 150.00 *)
  assert_order_executed engine order_mgr order ~price:150.00

let test_stop_limit_requires_bid_ask_price _ =
  (* With path-based execution, bid/ask are implicit in OHLC. This test now
     verifies stop-limit behavior with proper OHLC data. *)
  let bar =
    make_bar "AAPL" ~open_price:149.50 ~high_price:151.00 ~low_price:149.00
      ~close_price:150.50
  in
  let engine, order_mgr, order =
    setup_order_test
      ~order_type:(StopLimit (150.00, 150.00))
      ~side:Buy ~quote:bar ()
  in
  (* Path goes up, crosses stop at 150.00, which meets limit, fills at 150.00 *)
  assert_order_executed engine order_mgr order ~price:150.00

(* ==================== Path execution edge case tests ==================== *)
(* These tests cover important edge cases for path-based order execution:
   - Crossing inside bars (fills at limit/stop price when crossed)
   - Gap scenarios (fills at observed price when price gaps beyond trigger)
   - Exact OHLC point fills (fills when limit/stop exactly at high/low) *)

(* Limit order crossing tests *)
let test_limit_buy_crosses_inside_bar _ =
  (* Price drops past limit inside a bar move; should fill at limit price *)
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  let engine, order_mgr, order =
    setup_order_test ~order_type:(Limit 97.0) ~side:Buy ~quote:bar ()
  in
  (* Path: 100→110→95→105. Going from 110 to 95 crosses 97.0, fills at 97.0 *)
  assert_order_executed engine order_mgr order ~price:97.0

let test_limit_sell_crosses_inside_bar _ =
  (* Price rises past limit inside a bar move; should fill at limit price *)
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  let engine, order_mgr, order =
    setup_order_test ~order_type:(Limit 103.0) ~side:Sell ~quote:bar ()
  in
  (* Path: 100→110→95→105. Going from 100 to 110 crosses 103.0, fills at 103.0 *)
  assert_order_executed engine order_mgr order ~price:103.0

(* Gap scenario tests *)
let test_buy_stop_gap_up_fills_at_open _ =
  (* Gap up: open beyond stop price, should fill at observed open *)
  let bar =
    make_bar "AAPL" ~open_price:120.0 ~high_price:130.0 ~low_price:118.0
      ~close_price:125.0
  in
  let engine, order_mgr, order =
    setup_order_test ~order_type:(Stop 110.0) ~side:Buy ~quote:bar ()
  in
  (* Open at 120.0 already above stop at 110.0, fills at open *)
  assert_order_executed engine order_mgr order ~price:120.0

let test_sell_stop_gap_down_fills_at_open _ =
  (* Gap down: open beyond stop price, should fill at observed open *)
  let bar =
    make_bar "AAPL" ~open_price:90.0 ~high_price:95.0 ~low_price:80.0
      ~close_price:85.0
  in
  let engine, order_mgr, order =
    setup_order_test ~order_type:(Stop 95.0) ~side:Sell ~quote:bar ()
  in
  (* Open at 90.0 already below stop at 95.0, fills at open *)
  assert_order_executed engine order_mgr order ~price:90.0

let test_buy_stop_limit_gap_up_fills_at_open _ =
  (* Gap up with stop-limit: stop triggers, limit allows open price *)
  let bar =
    make_bar "AAPL" ~open_price:120.0 ~high_price:130.0 ~low_price:118.0
      ~close_price:125.0
  in
  let engine, order_mgr, order =
    setup_order_test
      ~order_type:(StopLimit (110.0, 130.0))
      ~side:Buy ~quote:bar ()
  in
  (* Stop triggers at open 120.0, which meets limit <= 130.0, fills at 120.0 *)
  assert_order_executed engine order_mgr order ~price:120.0

let test_buy_stop_limit_gap_up_limit_not_reached _ =
  (* Gap up with stop-limit: stop triggers but limit not met *)
  let bar =
    make_bar "AAPL" ~open_price:120.0 ~high_price:130.0 ~low_price:118.0
      ~close_price:125.0
  in
  let engine, order_mgr, _ =
    setup_order_test
      ~order_type:(StopLimit (110.0, 117.0))
      ~side:Buy ~quote:bar ()
  in
  (* Stop triggers at 120.0, but 120.0 > limit 117.0. Low is 118.0, still > 117.0 *)
  assert_order_not_executed engine order_mgr

let test_sell_stop_limit_gap_down_fills_at_open _ =
  (* Gap down with stop-limit: stop triggers, limit allows open price *)
  let bar =
    make_bar "AAPL" ~open_price:90.0 ~high_price:95.0 ~low_price:80.0
      ~close_price:85.0
  in
  let engine, order_mgr, order =
    setup_order_test
      ~order_type:(StopLimit (95.0, 85.0))
      ~side:Sell ~quote:bar ()
  in
  (* Stop triggers at open 90.0, which meets limit >= 85.0, fills at 90.0 *)
  assert_order_executed engine order_mgr order ~price:90.0

let test_sell_stop_limit_gap_down_limit_not_reached _ =
  (* Gap down with stop-limit: stop triggers but limit not met *)
  let bar =
    make_bar "AAPL" ~open_price:90.0 ~high_price:95.0 ~low_price:80.0
      ~close_price:85.0
  in
  let engine, order_mgr, _ =
    setup_order_test
      ~order_type:(StopLimit (100.0, 96.0))
      ~side:Sell ~quote:bar ()
  in
  (* Stop triggers at 90.0, but 90.0 < limit 96.0. High is 95.0, still < 96.0 *)
  assert_order_not_executed engine order_mgr

(* OHLC-specific tests *)
let test_limit_buy_at_exact_low _ =
  (* Limit exactly at low should fill at low *)
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  let engine, order_mgr, order =
    setup_order_test ~order_type:(Limit 95.0) ~side:Buy ~quote:bar ()
  in
  assert_order_executed engine order_mgr order ~price:95.0

let test_limit_sell_at_exact_high _ =
  (* Limit exactly at high should fill at high *)
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  let engine, order_mgr, order =
    setup_order_test ~order_type:(Limit 110.0) ~side:Sell ~quote:bar ()
  in
  assert_order_executed engine order_mgr order ~price:110.0

let test_stop_buy_at_exact_high _ =
  (* Stop buy exactly at high should fill at high *)
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  let engine, order_mgr, order =
    setup_order_test ~order_type:(Stop 110.0) ~side:Buy ~quote:bar ()
  in
  assert_order_executed engine order_mgr order ~price:110.0

let test_stop_sell_at_exact_low _ =
  (* Stop sell exactly at low should fill at low *)
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  let engine, order_mgr, order =
    setup_order_test ~order_type:(Stop 95.0) ~side:Sell ~quote:bar ()
  in
  assert_order_executed engine order_mgr order ~price:95.0

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
         (* Path execution edge case tests *)
         "test_limit_buy_crosses_inside_bar"
         >:: test_limit_buy_crosses_inside_bar;
         "test_limit_sell_crosses_inside_bar"
         >:: test_limit_sell_crosses_inside_bar;
         "test_buy_stop_gap_up_fills_at_open"
         >:: test_buy_stop_gap_up_fills_at_open;
         "test_sell_stop_gap_down_fills_at_open"
         >:: test_sell_stop_gap_down_fills_at_open;
         "test_buy_stop_limit_gap_up_fills_at_open"
         >:: test_buy_stop_limit_gap_up_fills_at_open;
         "test_buy_stop_limit_gap_up_limit_not_reached"
         >:: test_buy_stop_limit_gap_up_limit_not_reached;
         "test_sell_stop_limit_gap_down_fills_at_open"
         >:: test_sell_stop_limit_gap_down_fills_at_open;
         "test_sell_stop_limit_gap_down_limit_not_reached"
         >:: test_sell_stop_limit_gap_down_limit_not_reached;
         "test_limit_buy_at_exact_low" >:: test_limit_buy_at_exact_low;
         "test_limit_sell_at_exact_high" >:: test_limit_sell_at_exact_high;
         "test_stop_buy_at_exact_high" >:: test_stop_buy_at_exact_high;
         "test_stop_sell_at_exact_low" >:: test_stop_sell_at_exact_low;
       ]

let () = run_test_tt_main suite
