open OUnit2
open Trading_base.Types
open Trading_orders.Types
open Trading_orders.Factory
open Trading_orders.Manager

(* Helper to create orders with the new API *)
let make_order ~symbol ~side ~order_type ~quantity ~time_in_force =
  match create_order { symbol; side; order_type; quantity; time_in_force } with
  | Result.Ok order -> order
  | Result.Error _ -> failwith "Expected successful order creation"

let test_create_manager _ =
  let manager = create () in
  assert_equal 0 (List.length (list_orders manager));
  assert_equal 0 (List.length (list_orders ~filter:ActiveOnly manager))

let test_submit_order _ =
  let manager = create () in
  let order =
    make_order ~symbol:"AAPL" ~side:Buy ~order_type:Market ~quantity:100.0
      ~time_in_force:GTC
  in
  let result = submit_order manager order in
  assert_equal true (match result with Result.Ok _ -> true | Error _ -> false);
  let orders = list_orders manager in
  assert_equal 1 (List.length orders);
  let retrieved_order = List.hd orders in
  assert_equal order.id retrieved_order.id

let test_duplicate_order _ =
  let manager = create () in
  let order =
    make_order ~symbol:"MSFT" ~side:Sell ~order_type:(Limit 150.0)
      ~quantity:50.0 ~time_in_force:Day
  in

  let first_result = submit_order manager order in
  assert_equal true
    (match first_result with Result.Ok _ -> true | Error _ -> false);
  let duplicate_result = submit_order manager order in
  assert_equal true
    (match duplicate_result with Result.Ok _ -> false | Error _ -> true)

let test_get_order _ =
  let manager = create () in
  let order =
    make_order ~symbol:"GOOGL" ~side:Buy ~order_type:Market ~quantity:10.0
      ~time_in_force:IOC
  in
  let _ = submit_order manager order in
  let result = get_order manager order.id in
  match result with
  | Result.Ok retrieved_order ->
      assert_equal order.id retrieved_order.id;
      assert_equal order.symbol retrieved_order.symbol
  | Error _ -> assert_failure "Expected Ok result"

let test_get_nonexistent_order _ =
  let manager = create () in
  let result = get_order manager "nonexistent_id" in
  assert_equal true (match result with Result.Ok _ -> false | Error _ -> true)

let test_cancel_order _ =
  let manager = create () in
  let order =
    make_order ~symbol:"TSLA" ~side:Buy ~order_type:Market ~quantity:20.0
      ~time_in_force:GTC
  in

  let _ = submit_order manager order in
  let cancel_result = cancel_order manager order.id in
  assert_equal true
    (match cancel_result with Result.Ok _ -> true | Error _ -> false);

  let result = get_order manager order.id in
  match result with
  | Result.Ok cancelled_order ->
      assert_equal Cancelled cancelled_order.status;
      assert_equal false (is_active cancelled_order)
  | Error _ -> assert_failure "Expected Ok result"

let test_cancel_already_cancelled_order _ =
  let manager = create () in
  let order =
    make_order ~symbol:"NVDA" ~side:Sell ~order_type:(Limit 500.0)
      ~quantity:15.0 ~time_in_force:FOK
  in

  let _ = submit_order manager order in
  let _ = cancel_order manager order.id in
  let result = cancel_order manager order.id in
  assert_equal true (match result with Result.Ok _ -> false | Error _ -> true)

let test_list_active_orders _ =
  let manager = create () in
  let order1 =
    make_order ~symbol:"AMZN" ~side:Buy ~order_type:Market ~quantity:5.0
      ~time_in_force:Day
  in
  let order2 =
    make_order ~symbol:"META" ~side:Sell ~order_type:(Limit 200.0) ~quantity:8.0
      ~time_in_force:GTC
  in

  let _ = submit_order manager order1 in
  let _ = submit_order manager order2 in
  let _ = cancel_order manager order1.id in

  let active_orders = list_orders ~filter:ActiveOnly manager in
  assert_equal 1 (List.length active_orders);
  let active_order = List.hd active_orders in
  assert_equal order2.id active_order.id

let test_list_orders_by_symbol _ =
  let manager = create () in
  let order1 =
    make_order ~symbol:"AAPL" ~side:Buy ~order_type:Market ~quantity:10.0
      ~time_in_force:Day
  in
  let order2 =
    make_order ~symbol:"MSFT" ~side:Sell ~order_type:(Limit 300.0)
      ~quantity:20.0 ~time_in_force:GTC
  in
  let order3 =
    make_order ~symbol:"AAPL" ~side:Sell ~order_type:(Limit 180.0)
      ~quantity:15.0 ~time_in_force:IOC
  in

  let _ = submit_order manager order1 in
  let _ = submit_order manager order2 in
  let _ = submit_order manager order3 in

  let aapl_orders = list_orders ~filter:(BySymbol "AAPL") manager in
  let msft_orders = list_orders ~filter:(BySymbol "MSFT") manager in

  assert_equal 2 (List.length aapl_orders);
  assert_equal 1 (List.length msft_orders)

let test_batch_operations _ =
  let manager = create () in
  let order1 =
    make_order ~symbol:"AAPL" ~side:Buy ~order_type:Market ~quantity:10.0
      ~time_in_force:Day
  in
  let order2 =
    make_order ~symbol:"MSFT" ~side:Sell ~order_type:(Limit 300.0)
      ~quantity:20.0 ~time_in_force:GTC
  in

  let results = submit_orders manager [ order1; order2 ] in
  assert_equal 2 (List.length results);
  assert_equal true
    (match List.nth results 0 with Result.Ok _ -> true | Error _ -> false);
  assert_equal true
    (match List.nth results 1 with Result.Ok _ -> true | Error _ -> false);

  let cancel_results = cancel_orders manager [ order1.id; order2.id ] in
  assert_equal 2 (List.length cancel_results);
  assert_equal true
    (match List.nth cancel_results 0 with
    | Result.Ok _ -> true
    | Error _ -> false);
  assert_equal true
    (match List.nth cancel_results 1 with
    | Result.Ok _ -> true
    | Error _ -> false)

let test_cancel_all _ =
  let manager = create () in
  let order1 =
    make_order ~symbol:"AAPL" ~side:Buy ~order_type:Market ~quantity:10.0
      ~time_in_force:Day
  in
  let order2 =
    make_order ~symbol:"MSFT" ~side:Sell ~order_type:(Limit 300.0)
      ~quantity:20.0 ~time_in_force:GTC
  in

  let _ = submit_order manager order1 in
  let _ = submit_order manager order2 in

  cancel_all manager;
  assert_equal 0 (List.length (list_orders ~filter:ActiveOnly manager))

let test_filtering _ =
  let manager = create () in
  let order1 =
    make_order ~symbol:"AAPL" ~side:Buy ~order_type:Market ~quantity:10.0
      ~time_in_force:Day
  in
  let order2 =
    make_order ~symbol:"MSFT" ~side:Sell ~order_type:(Limit 300.0)
      ~quantity:20.0 ~time_in_force:GTC
  in
  let order3 =
    make_order ~symbol:"AAPL" ~side:Sell ~order_type:(Limit 180.0)
      ~quantity:15.0 ~time_in_force:IOC
  in

  let _ = submit_order manager order1 in
  let _ = submit_order manager order2 in
  let _ = submit_order manager order3 in
  let _ = cancel_order manager order1.id in

  let by_symbol = list_orders ~filter:(BySymbol "AAPL") manager in
  let by_side = list_orders ~filter:(BySide Buy) manager in
  let by_status = list_orders ~filter:(ByStatus Cancelled) manager in
  let active_only = list_orders ~filter:ActiveOnly manager in

  assert_equal 2 (List.length by_symbol);
  assert_equal 1 (List.length by_side);
  assert_equal 1 (List.length by_status);
  assert_equal 2 (List.length active_only)

let suite =
  "Order Manager"
  >::: [
         "create_manager" >:: test_create_manager;
         "submit_order" >:: test_submit_order;
         "duplicate_order" >:: test_duplicate_order;
         "get_order" >:: test_get_order;
         "get_nonexistent_order" >:: test_get_nonexistent_order;
         "cancel_order" >:: test_cancel_order;
         "cancel_already_cancelled" >:: test_cancel_already_cancelled_order;
         "list_active_orders" >:: test_list_active_orders;
         "list_orders_by_symbol" >:: test_list_orders_by_symbol;
         "batch_operations" >:: test_batch_operations;
         "cancel_all" >:: test_cancel_all;
         "filtering" >:: test_filtering;
       ]

let () = run_test_tt_main suite
