open OUnit2
open Trading_base.Types
open Trading_orders.Types

let create_test_order symbol side order_type quantity time_in_force =
  {
    id = "test_order_123";
    symbol;
    side;
    order_type;
    quantity;
    time_in_force;
    status = Pending;
    filled_quantity = 0.0;
    avg_fill_price = None;
    created_at = Time_ns_unix.now ();
    updated_at = Time_ns_unix.now ();
  }

let test_update_status _ =
  let order = create_test_order "MSFT" Sell (Limit 150.0) 50.0 Day in
  let updated_order = update_status order (PartiallyFilled 25.0) in

  assert_equal (PartiallyFilled 25.0) updated_order.status;
  assert_equal true (updated_order.updated_at >= order.updated_at)

let test_is_active _ =
  let pending_order = create_test_order "GOOGL" Buy Market 10.0 GTC in
  assert_equal true (is_active pending_order);

  let partial_order = update_status pending_order (PartiallyFilled 5.0) in
  assert_equal true (is_active partial_order);

  let filled_order = update_status pending_order Filled in
  assert_equal false (is_active filled_order);

  let cancelled_order = update_status pending_order Cancelled in
  assert_equal false (is_active cancelled_order)

let test_is_filled _ =
  let order = create_test_order "TSLA" Buy Market 20.0 IOC in
  assert_equal false (is_filled order);

  let filled_order = update_status order Filled in
  assert_equal true (is_filled filled_order)

let test_remaining_quantity _ =
  let order = create_test_order "NVDA" Buy Market 100.0 FOK in
  assert_equal
    ~cmp:(fun a b -> Float.abs (a -. b) < 0.01)
    100.0 (remaining_quantity order);

  let partial_order = { order with filled_quantity = 30.0 } in
  assert_equal
    ~cmp:(fun a b -> Float.abs (a -. b) < 0.01)
    70.0
    (remaining_quantity partial_order)

let test_order_equality _ =
  let order1 = create_test_order "AAPL" Buy Market 100.0 GTC in
  let order2 = { order1 with id = order1.id } in
  (* Same order *)
  let order3 = create_test_order "AAPL" Buy Market 100.0 GTC in

  assert_equal order1 order2;
  assert_equal false (order1 = order3)

let suite =
  "Order Types"
  >::: [
         "update_status" >:: test_update_status;
         "is_active" >:: test_is_active;
         "is_filled" >:: test_is_filled;
         "remaining_quantity" >:: test_remaining_quantity;
         "order_equality" >:: test_order_equality;
       ]

let () = run_test_tt_main suite
