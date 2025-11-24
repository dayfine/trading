open Core
open OUnit2
open Trading_base.Types
open Trading_orders.Types
open Trading_orders.Create_order
open Trading_orders.Manager
open Matchers

(* Helper functions *)
let compare_orders_by_id a b = String.compare a.id b.id
let sort_orders_by_id orders = List.sort orders ~compare:compare_orders_by_id

let assert_single_ok results ~msg =
  match results with
  | [ Ok _ ] -> ()
  | [ Error err ] -> assert_failure (msg ^ ": " ^ Status.show err)
  | _ -> assert_failure (msg ^ ": Expected single result")

let assert_single_error results ~msg =
  match results with
  | [ Ok _ ] -> assert_failure (msg ^ ": Expected error but got Ok")
  | [ Error err ] -> err
  | _ -> assert_failure (msg ^ ": Expected single result")

(* Helper to create orders with the new API *)
let make_order ~symbol ~side ~order_type ~quantity ~time_in_force =
  let test_time = Time_ns_unix.of_string "2024-01-01 12:00:00Z" in
  match
    create_order ~now_time:test_time
      { symbol; side; order_type; quantity; time_in_force }
  with
  | Ok order -> order
  | Error err -> failwith (Status.show err)

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
  let results = submit_orders manager [ order ] in
  assert_single_ok results ~msg:"Failed to submit order";
  let orders = list_orders manager in
  assert_equal 1 (List.length orders);
  let retrieved_order = List.hd_exn orders in
  assert_equal order retrieved_order

let test_duplicate_order _ =
  let manager = create () in
  let order =
    make_order ~symbol:"MSFT" ~side:Sell ~order_type:(Limit 150.0)
      ~quantity:50.0 ~time_in_force:Day
  in

  let first_results = submit_orders manager [ order ] in
  assert_single_ok first_results ~msg:"Failed to submit first order";
  let duplicate_results = submit_orders manager [ order ] in
  let status =
    assert_single_error duplicate_results
      ~msg:"Expected duplicate order to be rejected"
  in
  assert_equal Status.Invalid_argument status.code
    ~msg:"Expected Status.Invalid_argument error code for duplicate order ID"

let test_duplicate_order_batch _ =
  let manager = create () in
  let order =
    make_order ~symbol:"TSLA" ~side:Buy ~order_type:(Limit 200.0) ~quantity:25.0
      ~time_in_force:GTC
  in

  let results = submit_orders manager [ order; order ] in
  match results with
  | [ Ok _; Error status ] ->
      (* Expected: first succeeds, second fails due to duplicate ID *)
      assert_equal Status.Invalid_argument status.code
        ~msg:
          "Expected Status.Invalid_argument error code for duplicate order ID";
      let orders = list_orders manager in
      assert_equal 1 (List.length orders);
      (* Only one order should be stored *)
      let stored_order = List.hd_exn orders in
      assert_equal order stored_order
  | [ Ok _; Ok _ ] ->
      assert_failure "Expected second order to be rejected due to duplicate ID"
  | [ Error _; Error _ ] -> assert_failure "Expected first order to succeed"
  | _ -> assert_failure "Expected exactly two results"

let test_get_order _ =
  let manager = create () in
  let order =
    make_order ~symbol:"GOOGL" ~side:Buy ~order_type:Market ~quantity:10.0
      ~time_in_force:IOC
  in
  let _ = submit_orders manager [ order ] in
  assert_that
    (get_order manager order.id)
    (is_ok_and_holds (fun retrieved_order -> assert_equal order retrieved_order))

let test_get_nonexistent_order _ =
  let manager = create () in
  assert_that (get_order manager "nonexistent_id") is_error

let test_cancel_order _ =
  let manager = create () in
  let order =
    make_order ~symbol:"TSLA" ~side:Buy ~order_type:Market ~quantity:20.0
      ~time_in_force:GTC
  in

  let _ = submit_orders manager [ order ] in
  let cancel_results = cancel_orders manager [ order.id ] in
  match cancel_results with
  | [ Ok _ ] -> (
      let result = get_order manager order.id in
      match result with
      | Ok cancelled_order ->
          assert_equal Cancelled cancelled_order.status;
          assert_equal false (is_active cancelled_order)
      | Error err -> assert_failure (Status.show err))
  | [ Error err ] -> assert_failure (Status.show err)
  | _ -> assert_failure "Expected single result"

let test_cancel_already_cancelled_order _ =
  let manager = create () in
  let order =
    make_order ~symbol:"NVDA" ~side:Sell ~order_type:(Limit 500.0)
      ~quantity:15.0 ~time_in_force:FOK
  in

  let _ = submit_orders manager [ order ] in
  let _ = cancel_orders manager [ order.id ] in
  let results = cancel_orders manager [ order.id ] in
  match results with
  | [ Ok _ ] ->
      assert_failure "Expected error when cancelling already cancelled order"
  | [ Error status ] ->
      assert_equal Status.Invalid_argument status.code
        ~msg:"Expected Status.Invalid_argument error code for inactive order"
  | _ -> assert_failure "Expected single result"

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

  let _ = submit_orders manager [ order1; order2 ] in
  let _ = cancel_orders manager [ order1.id ] in

  let active_orders = list_orders ~filter:ActiveOnly manager in
  assert_equal 1 (List.length active_orders);
  let active_order = List.hd_exn active_orders in
  assert_equal order2 active_order

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

  let _ = submit_orders manager [ order1; order2; order3 ] in

  let aapl_orders = list_orders ~filter:(BySymbol "AAPL") manager in
  let msft_orders = list_orders ~filter:(BySymbol "MSFT") manager in

  (* Sort both lists by order ID for deterministic comparison *)
  let aapl_orders_sorted = sort_orders_by_id aapl_orders in
  let expected_aapl_orders = sort_orders_by_id [ order1; order3 ] in
  assert_equal expected_aapl_orders aapl_orders_sorted
    ~msg:"AAPL orders should contain order1 and order3";

  let msft_orders_sorted = sort_orders_by_id msft_orders in
  let expected_msft_orders = sort_orders_by_id [ order2 ] in
  assert_equal expected_msft_orders msft_orders_sorted
    ~msg:"MSFT orders should contain order2"

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
  List.iter results ~f:(function
    | Ok _ -> ()
    | Error err -> assert_failure (Status.show err));

  let cancel_results = cancel_orders manager [ order1.id; order2.id ] in
  assert_equal 2 (List.length cancel_results);
  List.iter cancel_results ~f:(function
    | Ok _ -> ()
    | Error err -> assert_failure (Status.show err))

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

  let _ = submit_orders manager [ order1; order2 ] in

  let active_orders = list_orders ~filter:ActiveOnly manager in
  let active_ids = List.map active_orders ~f:(fun order -> order.id) in
  let _ = cancel_orders manager active_ids in
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

  let _ = submit_orders manager [ order1; order2; order3 ] in
  let _ = cancel_orders manager [ order1.id ] in

  (* Get the updated orders from the manager for comparison *)
  let updated_order1 =
    match get_order manager order1.id with
    | Ok order -> order
    | Error err -> failwith ("order1 not found: " ^ Status.show err)
  in
  let updated_order2 =
    match get_order manager order2.id with
    | Ok order -> order
    | Error err -> failwith ("order2 not found: " ^ Status.show err)
  in
  let updated_order3 =
    match get_order manager order3.id with
    | Ok order -> order
    | Error err -> failwith ("order3 not found: " ^ Status.show err)
  in

  let by_symbol = list_orders ~filter:(BySymbol "AAPL") manager in
  let by_side = list_orders ~filter:(BySide Buy) manager in
  let by_status = list_orders ~filter:(ByStatus Cancelled) manager in
  let active_only = list_orders ~filter:ActiveOnly manager in

  (* Sort both lists by order ID for deterministic comparison *)
  let by_symbol_sorted = sort_orders_by_id by_symbol in
  let expected_by_symbol =
    sort_orders_by_id [ updated_order1; updated_order3 ]
  in
  assert_equal expected_by_symbol by_symbol_sorted
    ~msg:"BySymbol AAPL should contain order1 and order3";

  let by_side_sorted = sort_orders_by_id by_side in
  let expected_by_side = sort_orders_by_id [ updated_order1 ] in
  assert_equal expected_by_side by_side_sorted
    ~msg:"BySide Buy should contain order1";

  let by_status_sorted = sort_orders_by_id by_status in
  let expected_by_status = sort_orders_by_id [ updated_order1 ] in
  assert_equal expected_by_status by_status_sorted
    ~msg:"ByStatus Cancelled should contain order1";

  let active_only_sorted = sort_orders_by_id active_only in
  let expected_active_only =
    sort_orders_by_id [ updated_order2; updated_order3 ]
  in
  assert_equal expected_active_only active_only_sorted
    ~msg:"ActiveOnly should contain order2 and order3"

(* update_order tests *)
let test_update_order_success _ =
  let manager = create () in
  let order =
    make_order ~symbol:"AAPL" ~side:Buy ~order_type:Market ~quantity:100.0
      ~time_in_force:GTC
  in
  let _ = submit_orders manager [ order ] in

  (* Update the order to Filled status *)
  let filled_order = update_status order Filled in
  let result = update_order manager filled_order in
  assert_that result is_ok;

  (* Verify the order was updated *)
  assert_that
    (get_order manager order.id)
    (is_ok_and_holds (fun retrieved_order ->
         assert_equal Filled retrieved_order.status
           ~msg:"Order status should be Filled"))

let test_update_nonexistent_order _ =
  let manager = create () in
  let order =
    make_order ~symbol:"AAPL" ~side:Buy ~order_type:Market ~quantity:100.0
      ~time_in_force:GTC
  in

  (* Try to update without submitting *)
  let result = update_order manager order in
  match result with
  | Ok _ -> assert_failure "Expected error for nonexistent order"
  | Error status ->
      assert_equal Status.NotFound status.code
        ~msg:"Expected NotFound error code"

let test_update_order_preserves_changes _ =
  let manager = create () in
  let order =
    make_order ~symbol:"AAPL" ~side:Buy ~order_type:Market ~quantity:100.0
      ~time_in_force:GTC
  in
  let _ = submit_orders manager [ order ] in

  (* Update to partially filled *)
  let partially_filled_order =
    {
      order with
      status = PartiallyFilled 50.0;
      filled_quantity = 50.0;
      avg_fill_price = Some 150.0;
    }
  in
  let _ = update_order manager partially_filled_order in

  (* Retrieve and verify all fields updated *)
  assert_that
    (get_order manager order.id)
    (is_ok_and_holds (fun retrieved_order ->
         assert_equal (PartiallyFilled 50.0) retrieved_order.status
           ~msg:"Status should be PartiallyFilled";
         assert_that retrieved_order.filled_quantity (float_equal 50.0);
         assert_equal (Some 150.0) retrieved_order.avg_fill_price
           ~msg:"Average fill price should be Some 150.0"))

let test_update_order_timestamp _ =
  let manager = create () in
  let order =
    make_order ~symbol:"AAPL" ~side:Buy ~order_type:Market ~quantity:100.0
      ~time_in_force:GTC
  in
  let _ = submit_orders manager [ order ] in

  (* Update using update_status which should update timestamp *)
  let filled_order = update_status order Filled in
  assert_bool "Updated timestamp should differ from original"
    (not (Time_ns_unix.equal order.updated_at filled_order.updated_at));

  let _ = update_order manager filled_order in

  (* Verify timestamp was preserved *)
  assert_that
    (get_order manager order.id)
    (is_ok_and_holds (fun retrieved_order ->
         assert_bool "Retrieved order should have updated timestamp"
           (Time_ns_unix.equal filled_order.updated_at
              retrieved_order.updated_at)))

let suite =
  "Order Manager"
  >::: [
         "create_manager" >:: test_create_manager;
         "submit_order" >:: test_submit_order;
         "duplicate_order" >:: test_duplicate_order;
         "duplicate_order_batch" >:: test_duplicate_order_batch;
         "get_order" >:: test_get_order;
         "get_nonexistent_order" >:: test_get_nonexistent_order;
         "cancel_order" >:: test_cancel_order;
         "cancel_already_cancelled" >:: test_cancel_already_cancelled_order;
         "list_active_orders" >:: test_list_active_orders;
         "list_orders_by_symbol" >:: test_list_orders_by_symbol;
         "batch_operations" >:: test_batch_operations;
         "cancel_all" >:: test_cancel_all;
         "filtering" >:: test_filtering;
         "update_order_success" >:: test_update_order_success;
         "update_nonexistent_order" >:: test_update_nonexistent_order;
         "update_order_preserves_changes"
         >:: test_update_order_preserves_changes;
         "update_order_timestamp" >:: test_update_order_timestamp;
       ]

let () = run_test_tt_main suite
