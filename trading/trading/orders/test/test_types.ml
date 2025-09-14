open OUnit2
open Trading_base.Types
open Trading_orders.Types
open Trading_orders.Factory

let test_create_order _ =
  let order =
    match
      create_order
        {
          symbol = "AAPL";
          side = Buy;
          order_type = Market;
          quantity = 100.0;
          time_in_force = GTC;
        }
    with
    | Result.Ok order -> order
    | Result.Error _ -> failwith "Expected successful order creation"
  in
  assert_equal order
    {
      id = order.id;
      (* Use the actual generated ID *)
      symbol = "AAPL";
      side = Buy;
      order_type = Market;
      quantity = 100.0;
      time_in_force = GTC;
      status = Pending;
      filled_quantity = 0.0;
      avg_fill_price = None;
      created_at = order.created_at;
      (* Use the actual timestamp *)
      updated_at = order.updated_at;
      (* Use the actual timestamp *)
    }

let test_update_status _ =
  let params =
    {
      symbol = "MSFT";
      side = Sell;
      order_type = Limit 150.0;
      quantity = 50.0;
      time_in_force = Day;
    }
  in
  let order =
    match create_order params with
    | Result.Ok order -> order
    | Result.Error _ -> failwith "Expected successful order creation"
  in
  let updated_order = update_status order (PartiallyFilled 25.0) in

  assert_equal (PartiallyFilled 25.0) updated_order.status;
  assert_equal true (updated_order.updated_at >= order.updated_at)

let test_is_active _ =
  let params =
    {
      symbol = "GOOGL";
      side = Buy;
      order_type = Market;
      quantity = 10.0;
      time_in_force = GTC;
    }
  in
  let pending_order =
    match create_order params with
    | Result.Ok order -> order
    | Result.Error _ -> failwith "Expected successful order creation"
  in
  assert_equal true (is_active pending_order);

  let partial_order = update_status pending_order (PartiallyFilled 5.0) in
  assert_equal true (is_active partial_order);

  let filled_order = update_status pending_order Filled in
  assert_equal false (is_active filled_order);

  let cancelled_order = update_status pending_order Cancelled in
  assert_equal false (is_active cancelled_order)

let test_is_filled _ =
  let params =
    {
      symbol = "TSLA";
      side = Buy;
      order_type = Market;
      quantity = 20.0;
      time_in_force = IOC;
    }
  in
  let order =
    match create_order params with
    | Result.Ok order -> order
    | Result.Error _ -> failwith "Expected successful order creation"
  in
  assert_equal false (is_filled order);

  let filled_order = update_status order Filled in
  assert_equal true (is_filled filled_order)

let test_remaining_quantity _ =
  let params =
    {
      symbol = "NVDA";
      side = Buy;
      order_type = Market;
      quantity = 100.0;
      time_in_force = FOK;
    }
  in
  let order =
    match create_order params with
    | Result.Ok order -> order
    | Result.Error _ -> failwith "Expected successful order creation"
  in
  assert_equal
    ~cmp:(fun a b -> Float.abs (a -. b) < 0.01)
    100.0 (remaining_quantity order);

  let partial_order = { order with filled_quantity = 30.0 } in
  assert_equal
    ~cmp:(fun a b -> Float.abs (a -. b) < 0.01)
    70.0
    (remaining_quantity partial_order)

let test_order_equality _ =
  let params =
    {
      symbol = "AAPL";
      side = Buy;
      order_type = Market;
      quantity = 100.0;
      time_in_force = GTC;
    }
  in
  let order1 =
    match create_order params with
    | Result.Ok order -> order
    | Result.Error _ -> failwith "Expected successful order creation"
  in
  let order2 = { order1 with id = order1.id } in
  (* Same order *)
  let order3 =
    match create_order params with
    | Result.Ok order -> order
    | Result.Error _ -> failwith "Expected successful order creation"
  in

  assert_equal order1 order2;
  assert_equal false (order1 = order3)

let suite =
  "Order Types"
  >::: [
         "create_order" >:: test_create_order;
         "update_status" >:: test_update_status;
         "is_active" >:: test_is_active;
         "is_filled" >:: test_is_filled;
         "remaining_quantity" >:: test_remaining_quantity;
         "order_equality" >:: test_order_equality;
       ]

let () = run_test_tt_main suite
