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
  let manager = create () in
  assert_equal [] (list_portfolios manager) ~msg:"No portfolios initially"

let test_create_portfolio _ =
  let manager = create () in
  let portfolio_id = create_portfolio manager "test_portfolio" 10000.0 in
  assert_equal "test_portfolio" portfolio_id ~msg:"Portfolio ID returned";

  match get_portfolio manager portfolio_id with
  | Some portfolio ->
      assert_equal "test_portfolio" portfolio.id;
      assert_float_equal 10000.0 portfolio.cash ~msg:"Initial cash balance"
  | None -> assert_failure "Portfolio should exist after creation"

let test_multiple_portfolios _ =
  let manager = create () in
  let _ = create_portfolio manager "portfolio1" 5000.0 in
  let _ = create_portfolio manager "portfolio2" 15000.0 in

  let portfolios = list_portfolios manager in
  assert_equal 2 (List.length portfolios) ~msg:"Two portfolios created";

  let portfolio_ids = List.map portfolios ~f:(fun p -> p.id) |> Set.of_list (module String) in
  assert_bool "Portfolio1 exists" (Set.mem portfolio_ids "portfolio1");
  assert_bool "Portfolio2 exists" (Set.mem portfolio_ids "portfolio2")

let test_apply_buy_order _ =
  let manager = create () in
  let portfolio_id = create_portfolio manager "test" 10000.0 in

  let buy_order = make_filled_order ~symbol:"AAPL" ~side:Buy ~quantity:100.0 ~price:150.0 in
  let updated_manager = apply_order_execution manager portfolio_id buy_order in

  match get_portfolio updated_manager portfolio_id with
  | Some portfolio ->
      (* Cash should be reduced by 100 * 150 = 15000 *)
      assert_float_equal (-5000.0) portfolio.cash ~msg:"Cash reduced after buy";

      (* Position should be created *)
      begin match get_position updated_manager portfolio_id "AAPL" with
      | Some position ->
          assert_float_equal 100.0 position.quantity ~msg:"Position quantity";
          assert_float_equal 150.0 position.avg_cost ~msg:"Position average cost"
      | None -> assert_failure "Position should exist after buy order"
      end
  | None -> assert_failure "Portfolio should exist"

let test_apply_sell_order _ =
  let manager = create () in
  let portfolio_id = create_portfolio manager "test" 10000.0 in

  (* First buy some shares *)
  let buy_order = make_filled_order ~symbol:"AAPL" ~side:Buy ~quantity:100.0 ~price:150.0 in
  let manager = apply_order_execution manager portfolio_id buy_order in

  (* Then sell some shares at a higher price *)
  let sell_order = make_filled_order ~symbol:"AAPL" ~side:Sell ~quantity:50.0 ~price:160.0 in
  let updated_manager = apply_order_execution manager portfolio_id sell_order in

  match get_portfolio updated_manager portfolio_id with
  | Some portfolio ->
      (* Cash: 10000 - 15000 + 8000 = 3000 *)
      assert_float_equal 3000.0 portfolio.cash ~msg:"Cash updated after sell";

      (* Position should be reduced *)
      begin match get_position updated_manager portfolio_id "AAPL" with
      | Some position ->
          assert_float_equal 50.0 position.quantity ~msg:"Reduced position quantity"
      | None -> assert_failure "Position should still exist after partial sell"
      end
  | None -> assert_failure "Portfolio should exist"

let test_buying_power_check _ =
  let manager = create () in
  let portfolio_id = create_portfolio manager "test" 10000.0 in

  let affordable_order = make_filled_order ~symbol:"AAPL" ~side:Buy ~quantity:50.0 ~price:150.0 in
  let expensive_order = make_filled_order ~symbol:"AAPL" ~side:Buy ~quantity:100.0 ~price:150.0 in

  assert_bool "Should afford smaller order" (check_buying_power manager portfolio_id affordable_order);
  assert_bool "Should not afford expensive order" (not (check_buying_power manager portfolio_id expensive_order))

let test_cash_operations _ =
  let manager = create () in
  let portfolio_id = create_portfolio manager "test" 10000.0 in

  assert_equal (Some 10000.0) (get_cash_balance manager portfolio_id) ~msg:"Initial cash balance";

  let manager = transfer_cash manager portfolio_id 2000.0 in
  assert_equal (Some 12000.0) (get_cash_balance manager portfolio_id) ~msg:"Cash increased";

  let manager = transfer_cash manager portfolio_id (-3000.0) in
  assert_equal (Some 9000.0) (get_cash_balance manager portfolio_id) ~msg:"Cash decreased"

let test_portfolio_valuation _ =
  let manager = create () in
  let portfolio_id = create_portfolio manager "test" 10000.0 in

  (* Add some positions *)
  let buy_order1 = make_filled_order ~symbol:"AAPL" ~side:Buy ~quantity:100.0 ~price:150.0 in
  let buy_order2 = make_filled_order ~symbol:"MSFT" ~side:Buy ~quantity:50.0 ~price:200.0 in
  let manager = apply_order_execution manager portfolio_id buy_order1 in
  let manager = apply_order_execution manager portfolio_id buy_order2 in

  let market_prices = [("AAPL", 160.0); ("MSFT", 210.0)] in
  match get_portfolio_value manager portfolio_id market_prices with
  | Some total_value ->
      (* Cash: 10000 - 15000 - 10000 = -15000 (negative cash)
         Positions: 100*160 + 50*210 = 26500
         Total: -15000 + 26500 = 11500 *)
      assert_float_equal 11500.0 total_value ~msg:"Total portfolio value"
  | None -> assert_failure "Should get portfolio value"

let test_market_price_updates _ =
  let manager = create () in
  let portfolio_id = create_portfolio manager "test" 10000.0 in

  let buy_order = make_filled_order ~symbol:"AAPL" ~side:Buy ~quantity:100.0 ~price:150.0 in
  let manager = apply_order_execution manager portfolio_id buy_order in

  let market_prices = [("AAPL", 160.0)] in
  let updated_manager = update_market_prices manager market_prices in

  match get_position updated_manager portfolio_id "AAPL" with
  | Some position ->
      assert_equal (Some 160.0) position.market_value ~msg:"Market value updated";
      (* Unrealized P&L: (160 - 150) * 100 = 1000 *)
      assert_float_equal 1000.0 position.unrealized_pnl ~msg:"Unrealized P&L calculated"
  | None -> assert_failure "Position should exist"

let test_total_pnl_calculation _ =
  let manager = create () in
  let portfolio_id = create_portfolio manager "test" 10000.0 in

  let buy_order = make_filled_order ~symbol:"AAPL" ~side:Buy ~quantity:100.0 ~price:150.0 in
  let manager = apply_order_execution manager portfolio_id buy_order in

  let market_prices = [("AAPL", 160.0)] in
  match calculate_total_pnl manager portfolio_id market_prices with
  | Some (realized_pnl, unrealized_pnl) ->
      assert_float_equal 0.0 realized_pnl ~msg:"No realized P&L yet";
      assert_float_equal 1000.0 unrealized_pnl ~msg:"Unrealized P&L from market price change"
  | None -> assert_failure "Should calculate P&L"

let test_nonexistent_portfolio _ =
  let manager = create () in

  assert_equal None (get_portfolio manager "nonexistent") ~msg:"Nonexistent portfolio";
  assert_equal None (get_cash_balance manager "nonexistent") ~msg:"No cash for nonexistent portfolio";
  assert_equal [] (list_positions manager "nonexistent") ~msg:"No positions for nonexistent portfolio";
  assert_equal None (get_portfolio_value manager "nonexistent" []) ~msg:"No value for nonexistent portfolio"

let suite =
  "Portfolio Manager" >::: [
    "create_manager" >:: test_create_manager;
    "create_portfolio" >:: test_create_portfolio;
    "multiple_portfolios" >:: test_multiple_portfolios;
    "apply_buy_order" >:: test_apply_buy_order;
    "apply_sell_order" >:: test_apply_sell_order;
    "buying_power_check" >:: test_buying_power_check;
    "cash_operations" >:: test_cash_operations;
    "portfolio_valuation" >:: test_portfolio_valuation;
    "market_price_updates" >:: test_market_price_updates;
    "total_pnl_calculation" >:: test_total_pnl_calculation;
    "nonexistent_portfolio" >:: test_nonexistent_portfolio;
  ]

let () = run_test_tt_main suite