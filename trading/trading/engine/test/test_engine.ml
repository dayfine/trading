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
let test_get_market_data_returns_none _ =
  let config = make_config () in
  let engine = create config in
  let data = get_market_data engine "AAPL" in
  assert_equal None data ~msg:"Should return None until Phase 6"

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
  (* Process orders *)
  let result = process_orders engine order_mgr in
  (* TODO: Phase 3 - Implement market order execution
     Expected behavior:
     - Should return 1 execution_report
     - report.order_id should be "order_1"
     - report.status should be Filled
     - report.trades should have 1 trade with:
       - quantity = 100.0
       - price = execution price (TBD how to pass this in)
       - commission = max(100.0 * 0.01, 1.0) = 1.0
     - Order in order_mgr should be updated to Filled status *)
  assert_ok_with ~msg:"Should process orders" result ~f:(fun reports ->
      assert_equal 0 (List.length reports)
        ~msg:"TODO: Should return 1 report after Phase 3 implementation")

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
  let result = process_orders engine order_mgr in
  (* TODO: Phase 3 - Verify commission calculation
     For 50 shares at $0.01 per share:
     - Calculated = 50 * 0.01 = 0.50
     - Minimum = 1.0
     - Actual commission should be max(0.50, 1.0) = 1.0 *)
  assert_ok_with ~msg:"Should process orders" result ~f:(fun reports ->
      assert_equal 0 (List.length reports)
        ~msg:"TODO: Verify commission in trade after Phase 3")

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
  (* Process orders *)
  let _result = process_orders engine order_mgr in
  (* TODO: Phase 3 - Verify order status updated
     After execution:
     - Order with ID "order_1" should be updated to Filled status
     - OrderManager.list_orders with ActiveOnly filter should return empty list
     - OrderManager.list_orders with AllOrders filter should return 1 order with Filled status *)
  let orders_after = OrderManager.list_orders order_mgr ~filter:ActiveOnly in
  assert_equal 1 (List.length orders_after)
    ~msg:"TODO: Should have 0 pending orders after Phase 3"

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
  (* Process all orders *)
  let result = process_orders engine order_mgr in
  (* TODO: Phase 3 - Handle multiple orders
     Should return 3 execution_reports, one for each order *)
  assert_ok_with ~msg:"Should process orders" result ~f:(fun reports ->
      assert_equal 0 (List.length reports)
        ~msg:"TODO: Should return 3 reports after Phase 3")

(* Test suite *)
let suite =
  "Engine Tests"
  >::: [
         "test_create_engine" >:: test_create_engine;
         "test_create_engine_with_custom_commission"
         >:: test_create_engine_with_custom_commission;
         "test_get_market_data_returns_none"
         >:: test_get_market_data_returns_none;
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
