open Core
open OUnit2
open Trading_orders.Types
open Trading_portfolio.Types
open Trading_portfolio.Manager

(* Helper functions *)
let assert_float_equal expected actual ~msg =
  assert_equal expected actual ~cmp:Float.equal ~msg

(* Helper to create test orders *)
let make_filled_order ~symbol ~side ~quantity ~price =
  let now = Time_ns_unix.now () in
  {
    id = "test_order_" ^ symbol;
    symbol;
    side;
    order_type = Market;
    quantity;
    time_in_force = GTC;
    status = Filled;
    filled_quantity = quantity;
    avg_fill_price = Some price;
    created_at = now;
    updated_at = now;
  }

let test_create_manager _ =
  let manager = create 10000.0 in
  let portfolio = get_portfolio manager in
  assert_float_equal 10000.0 portfolio.cash ~msg:"Initial cash balance";
  assert_equal 0
    (Hashtbl.length portfolio.positions)
    ~msg:"No positions initially"

let test_apply_buy_order _ =
  let manager = create 10000.0 in
  let buy_order =
    make_filled_order ~symbol:"AAPL" ~side:Buy ~quantity:100.0 ~price:150.0
  in
  let updated_manager = apply_order_execution manager buy_order in
  let portfolio = get_portfolio updated_manager in

  (* Cash should be reduced by 100 * 150 = 15000 *)
  assert_float_equal (-5000.0) portfolio.cash ~msg:"Cash reduced after buy";

  (* Position should be created *)
  match get_position updated_manager "AAPL" with
  | Some position ->
      assert_float_equal 100.0 position.quantity ~msg:"Position quantity";
      assert_float_equal 150.0 position.avg_cost ~msg:"Position average cost"
  | None -> assert_failure "Position should exist after buy order"

let test_apply_sell_order _ =
  let manager = create 10000.0 in

  (* First buy some shares *)
  let buy_order =
    make_filled_order ~symbol:"AAPL" ~side:Buy ~quantity:100.0 ~price:150.0
  in
  let manager = apply_order_execution manager buy_order in

  (* Then sell some shares at a higher price *)
  let sell_order =
    make_filled_order ~symbol:"AAPL" ~side:Sell ~quantity:50.0 ~price:160.0
  in
  let updated_manager = apply_order_execution manager sell_order in
  let portfolio = get_portfolio updated_manager in

  (* Cash: 10000 - 15000 + 8000 = 3000 *)
  assert_float_equal 3000.0 portfolio.cash ~msg:"Cash updated after sell";

  (* Position should be reduced *)
  match get_position updated_manager "AAPL" with
  | Some position ->
      assert_float_equal 50.0 position.quantity ~msg:"Reduced position quantity"
  | None -> assert_failure "Position should still exist after partial sell"

let test_buying_power_check _ =
  let manager = create 10000.0 in

  let affordable_order =
    make_filled_order ~symbol:"AAPL" ~side:Buy ~quantity:50.0 ~price:150.0
  in
  let expensive_order =
    make_filled_order ~symbol:"AAPL" ~side:Buy ~quantity:100.0 ~price:150.0
  in

  assert_bool "Should afford smaller order"
    (check_buying_power manager affordable_order);
  assert_bool "Should not afford expensive order"
    (not (check_buying_power manager expensive_order))

let test_list_positions _ =
  let manager = create 10000.0 in

  (* Add two positions *)
  let buy_order1 =
    make_filled_order ~symbol:"AAPL" ~side:Buy ~quantity:100.0 ~price:150.0
  in
  let buy_order2 =
    make_filled_order ~symbol:"MSFT" ~side:Buy ~quantity:50.0 ~price:200.0
  in
  let manager = apply_order_execution manager buy_order1 in
  let manager = apply_order_execution manager buy_order2 in

  let positions = list_positions manager in
  assert_equal 2 (List.length positions) ~msg:"Two positions";

  (* Check that both symbols are present *)
  let symbols =
    List.map positions ~f:(fun p -> p.symbol) |> Set.of_list (module String)
  in
  assert_bool "AAPL position exists" (Set.mem symbols "AAPL");
  assert_bool "MSFT position exists" (Set.mem symbols "MSFT")

let test_nonexistent_position _ =
  let manager = create 10000.0 in
  assert_equal None
    (get_position manager "NONEXISTENT")
    ~msg:"Nonexistent position should return None"

let suite =
  "Portfolio Manager"
  >::: [
         "create_manager" >:: test_create_manager;
         "apply_buy_order" >:: test_apply_buy_order;
         "apply_sell_order" >:: test_apply_sell_order;
         "buying_power_check" >:: test_buying_power_check;
         "list_positions" >:: test_list_positions;
         "nonexistent_position" >:: test_nonexistent_position;
       ]

let () = run_test_tt_main suite
