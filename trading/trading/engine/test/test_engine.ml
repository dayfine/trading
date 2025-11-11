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

let make_order_params ~symbol ~side ~order_type ~quantity ?(time_in_force = Day)
    () =
  { symbol; side; order_type; quantity; time_in_force }

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

(* get_market_data tests *)
let test_get_market_data_returns_none_when_no_data _ =
  let config = make_config () in
  let engine = create config in
  let data = get_market_data engine "AAPL" in
  assert_equal None data ~msg:"Should return None when no market data set"

let test_get_market_data_returns_data_after_update _ =
  let config = make_config () in
  let engine = create config in
  (* Update market data *)
  update_market engine "AAPL" ~bid:(Some 150.0) ~ask:(Some 150.5)
    ~last:(Some 150.25);
  (* Get market data *)
  let data = get_market_data engine "AAPL" in
  match data with
  | None -> assert_failure "Should return market data after update"
  | Some (bid, ask, last) ->
      assert_equal (Some 150.0) bid ~msg:"Bid should be 150.0";
      assert_equal (Some 150.5) ask ~msg:"Ask should be 150.5";
      assert_equal (Some 150.25) last ~msg:"Last should be 150.25"

let test_update_market_with_partial_data _ =
  let config = make_config () in
  let engine = create config in
  (* Update with only last price *)
  update_market engine "AAPL" ~bid:None ~ask:None ~last:(Some 150.0);
  let data = get_market_data engine "AAPL" in
  match data with
  | None -> assert_failure "Should return market data"
  | Some (bid, ask, last) ->
      assert_equal None bid ~msg:"Bid should be None";
      assert_equal None ask ~msg:"Ask should be None";
      assert_equal (Some 150.0) last ~msg:"Last should be 150.0"

let test_update_market_overwrites_previous_data _ =
  let config = make_config () in
  let engine = create config in
  (* First update *)
  update_market engine "AAPL" ~bid:(Some 150.0) ~ask:(Some 150.5)
    ~last:(Some 150.25);
  (* Second update *)
  update_market engine "AAPL" ~bid:(Some 155.0) ~ask:(Some 155.5)
    ~last:(Some 155.25);
  (* Get market data - should have second update *)
  let data = get_market_data engine "AAPL" in
  match data with
  | None -> assert_failure "Should return market data"
  | Some (bid, ask, last) ->
      assert_equal (Some 155.0) bid ~msg:"Bid should be 155.0";
      assert_equal (Some 155.5) ask ~msg:"Ask should be 155.5";
      assert_equal (Some 155.25) last ~msg:"Last should be 155.25"

(* process_orders tests *)
let test_process_orders_empty_manager _ =
  let config = make_config () in
  let engine = create config in
  let order_mgr = OrderManager.create () in
  let result = process_orders engine order_mgr in
  assert_ok_with ~msg:"Should succeed with empty manager" result
    ~f:(fun reports ->
      assert_equal 0 (List.length reports) ~msg:"Should return no reports")

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
  update_market engine "AAPL" ~bid:(Some 150.0) ~ask:(Some 150.5)
    ~last:(Some 150.25);
  (* Process orders *)
  let result = process_orders engine order_mgr in
  assert_ok_with ~msg:"Should process orders" result ~f:(fun reports ->
      assert_equal 1 (List.length reports) ~msg:"Should return 1 report";
      let report = List.hd_exn reports in
      assert_equal order.id report.order_id ~msg:"Should match order ID";
      assert_equal Filled report.status ~msg:"Should be Filled";
      assert_equal 1 (List.length report.trades) ~msg:"Should have 1 trade";
      let trade = List.hd_exn report.trades in
      assert_float_equal 100.0 trade.quantity ~msg:"Quantity should be 100.0";
      assert_float_equal 150.25 trade.price ~msg:"Price should be last price";
      assert_float_equal 1.0 trade.commission
        ~msg:"Commission should be max(100*0.01, 1.0) = 1.0")

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
  update_market engine "AAPL" ~bid:(Some 100.0) ~ask:(Some 100.5)
    ~last:(Some 100.25);
  let result = process_orders engine order_mgr in
  (* For 50 shares at $0.01 per share:
     - Calculated = 50 * 0.01 = 0.50
     - Minimum = 1.0
     - Actual commission should be max(0.50, 1.0) = 1.0 *)
  assert_ok_with ~msg:"Should process orders" result ~f:(fun reports ->
      assert_equal 1 (List.length reports) ~msg:"Should return 1 report";
      let report = List.hd_exn reports in
      let trade = List.hd_exn report.trades in
      assert_float_equal 1.0 trade.commission
        ~msg:"Commission should be max(0.50, 1.0) = 1.0")

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
  assert_equal 1 (List.length orders_before) ~msg:"Should have 1 pending order";
  (* Update market data *)
  update_market engine "AAPL" ~bid:(Some 150.0) ~ask:(Some 150.5)
    ~last:(Some 150.25);
  (* Process orders *)
  let _result = process_orders engine order_mgr in
  (* Verify order status updated:
     - OrderManager.list_orders with ActiveOnly filter should return empty list
     - OrderManager.list_orders without filter should return 1 order with Filled status *)
  let orders_after = OrderManager.list_orders order_mgr ~filter:ActiveOnly in
  assert_equal 0 (List.length orders_after)
    ~msg:"Should have 0 pending orders after execution";
  let all_orders = OrderManager.list_orders order_mgr in
  assert_equal 1 (List.length all_orders) ~msg:"Should have 1 total order";
  let filled_order = List.hd_exn all_orders in
  assert_equal Trading_orders.Types.Filled filled_order.status
    ~msg:"Order should be Filled"

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
  List.iter
    ~f:(fun params ->
      let order =
        assert_ok ~msg:"Failed to create order"
          (create_order ~now_time:test_timestamp params)
      in
      submit_single_order order_mgr order)
    [ params1; params2; params3 ];
  (* Update market data for all symbols *)
  update_market engine "AAPL" ~bid:(Some 150.0) ~ask:(Some 150.5)
    ~last:(Some 150.25);
  update_market engine "GOOGL" ~bid:(Some 2800.0) ~ask:(Some 2805.0)
    ~last:(Some 2802.5);
  update_market engine "MSFT" ~bid:(Some 380.0) ~ask:(Some 380.5)
    ~last:(Some 380.25);
  (* Process all orders *)
  let result = process_orders engine order_mgr in
  assert_ok_with ~msg:"Should process orders" result ~f:(fun reports ->
      assert_equal 3 (List.length reports) ~msg:"Should return 3 reports";
      (* Verify all orders have expected structure *)
      List.iter reports ~f:(fun report ->
          assert_equal Filled report.status ~msg:"All should be Filled";
          assert_equal 1
            (List.length report.trades)
            ~msg:"Each should have 1 trade"))

(* Test suite *)
let suite =
  "Engine Tests"
  >::: [
         "test_create_engine" >:: test_create_engine;
         "test_create_engine_with_custom_commission"
         >:: test_create_engine_with_custom_commission;
         "test_get_market_data_returns_none_when_no_data"
         >:: test_get_market_data_returns_none_when_no_data;
         "test_get_market_data_returns_data_after_update"
         >:: test_get_market_data_returns_data_after_update;
         "test_update_market_with_partial_data"
         >:: test_update_market_with_partial_data;
         "test_update_market_overwrites_previous_data"
         >:: test_update_market_overwrites_previous_data;
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
       ]

let () = run_test_tt_main suite
