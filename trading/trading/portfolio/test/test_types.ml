open Core
open OUnit2
open Trading_portfolio.Types

(* Helper functions *)
let assert_float_equal expected actual ~msg =
  assert_equal expected actual ~cmp:Float.equal ~msg

let assert_float_equal_delta expected actual ~delta ~msg =
  let diff = Float.abs (expected -. actual) in
  if Float.(diff > delta) then
    assert_failure (Printf.sprintf "%s: expected %f, got %f (diff %f > delta %f)"
                   msg expected actual diff delta)

let test_create_portfolio _ =
  let portfolio = create_portfolio "test_portfolio" 10000.0 in
  assert_equal "test_portfolio" portfolio.id;
  assert_float_equal 10000.0 portfolio.cash ~msg:"Initial cash balance";
  assert_equal 0 (Hashtbl.length portfolio.positions) ~msg:"Empty positions";
  assert_float_equal 0.0 portfolio.realized_pnl ~msg:"Zero realized P&L"

let test_update_position_new _ =
  let portfolio = create_portfolio "test" 10000.0 in
  let updated_portfolio = update_position portfolio "AAPL" 100.0 150.0 in

  match get_position updated_portfolio "AAPL" with
  | Some position ->
      assert_equal "AAPL" position.symbol;
      assert_float_equal 100.0 position.quantity ~msg:"Position quantity";
      assert_float_equal 150.0 position.avg_cost ~msg:"Average cost";
      assert_equal None position.market_value ~msg:"No market value initially";
      assert_float_equal 0.0 position.unrealized_pnl ~msg:"Zero unrealized P&L"
  | None -> assert_failure "Position should exist after update"

let test_update_position_existing _ =
  let portfolio = create_portfolio "test" 10000.0 in
  let portfolio = update_position portfolio "AAPL" 100.0 150.0 in
  let updated_portfolio = update_position portfolio "AAPL" 50.0 160.0 in

  match get_position updated_portfolio "AAPL" with
  | Some position ->
      assert_float_equal 150.0 position.quantity ~msg:"Combined quantity";
      (* Expected avg cost: (100 * 150 + 50 * 160) / 150 = 153.33 *)
      assert_float_equal_delta 153.33 position.avg_cost ~delta:0.01 ~msg:"Updated average cost"
  | None -> assert_failure "Position should exist after update"

let test_update_position_sell _ =
  let portfolio = create_portfolio "test" 10000.0 in
  let portfolio = update_position portfolio "AAPL" 100.0 150.0 in
  let updated_portfolio = update_position portfolio "AAPL" (-50.0) 160.0 in

  match get_position updated_portfolio "AAPL" with
  | Some position ->
      assert_float_equal 50.0 position.quantity ~msg:"Reduced quantity";
      (* Expected avg cost: (100 * 150 + (-50) * 160) / 50 = 140.0 *)
      assert_float_equal 140.0 position.avg_cost ~msg:"Updated average cost after sell"
  | None -> assert_failure "Position should exist after partial sell"

let test_position_close _ =
  let portfolio = create_portfolio "test" 10000.0 in
  let portfolio = update_position portfolio "AAPL" 100.0 150.0 in
  let updated_portfolio = update_position portfolio "AAPL" (-100.0) 160.0 in

  match get_position updated_portfolio "AAPL" with
  | Some position ->
      assert_float_equal 0.0 position.quantity ~msg:"Zero quantity";
      assert_float_equal 0.0 position.avg_cost ~msg:"Zero average cost"
  | None -> assert_failure "Position should still exist with zero quantity"

let test_cash_operations _ =
  let portfolio = create_portfolio "test" 10000.0 in
  assert_float_equal 10000.0 (get_cash_balance portfolio) ~msg:"Initial cash";

  let updated_portfolio = update_cash portfolio 8500.0 in
  assert_float_equal 8500.0 (get_cash_balance updated_portfolio) ~msg:"Updated cash"

let test_list_positions _ =
  let portfolio = create_portfolio "test" 10000.0 in
  let portfolio = update_position portfolio "AAPL" 100.0 150.0 in
  let portfolio = update_position portfolio "MSFT" 50.0 200.0 in

  let positions = list_positions portfolio in
  assert_equal 2 (List.length positions) ~msg:"Two positions";

  (* Check that both symbols are present *)
  let symbols = List.map positions ~f:(fun p -> p.symbol) |> Set.of_list (module String) in
  assert_bool "AAPL position exists" (Set.mem symbols "AAPL");
  assert_bool "MSFT position exists" (Set.mem symbols "MSFT")

let test_position_types _ =
  let long_position = { symbol = "AAPL"; quantity = 100.0; avg_cost = 150.0;
                       market_value = None; unrealized_pnl = 0.0 } in
  let short_position = { symbol = "MSFT"; quantity = (-50.0); avg_cost = 200.0;
                        market_value = None; unrealized_pnl = 0.0 } in

  assert_bool "Long position check" (is_long long_position);
  assert_bool "Long position is not short" (not (is_short long_position));
  assert_bool "Short position check" (is_short short_position);
  assert_bool "Short position is not long" (not (is_long short_position))

let test_portfolio_valuation _ =
  let portfolio = create_portfolio "test" 10000.0 in
  let portfolio = update_position portfolio "AAPL" 100.0 150.0 in
  let portfolio = update_position portfolio "MSFT" 50.0 200.0 in

  let market_prices = [("AAPL", 160.0); ("MSFT", 210.0)] in
  let total_value = calculate_portfolio_value portfolio market_prices in

  (* Expected: 10000 (cash) + 100*160 (AAPL) + 50*210 (MSFT) = 36500 *)
  assert_float_equal 36500.0 total_value ~msg:"Total portfolio value"

let test_market_price_updates _ =
  let portfolio = create_portfolio "test" 10000.0 in
  let portfolio = update_position portfolio "AAPL" 100.0 150.0 in

  let market_prices = [("AAPL", 160.0)] in
  let updated_portfolio = update_market_prices portfolio market_prices in

  match get_position updated_portfolio "AAPL" with
  | Some position ->
      assert_equal (Some 160.0) position.market_value ~msg:"Market value updated";
      (* Expected unrealized P&L: (160 - 150) * 100 = 1000 *)
      assert_float_equal 1000.0 position.unrealized_pnl ~msg:"Unrealized P&L calculated"
  | None -> assert_failure "Position should exist"

let test_position_market_value _ =
  let position_with_price = { symbol = "AAPL"; quantity = 100.0; avg_cost = 150.0;
                             market_value = Some 160.0; unrealized_pnl = 1000.0 } in
  let position_without_price = { symbol = "MSFT"; quantity = 50.0; avg_cost = 200.0;
                                market_value = None; unrealized_pnl = 0.0 } in

  assert_equal (Some 16000.0) (position_market_value position_with_price) ~msg:"Market value with price";
  assert_equal None (position_market_value position_without_price) ~msg:"No market value without price"

let suite =
  "Portfolio Types" >::: [
    "create_portfolio" >:: test_create_portfolio;
    "update_position_new" >:: test_update_position_new;
    "update_position_existing" >:: test_update_position_existing;
    "update_position_sell" >:: test_update_position_sell;
    "position_close" >:: test_position_close;
    "cash_operations" >:: test_cash_operations;
    "list_positions" >:: test_list_positions;
    "position_types" >:: test_position_types;
    "portfolio_valuation" >:: test_portfolio_valuation;
    "market_price_updates" >:: test_market_price_updates;
    "position_market_value" >:: test_position_market_value;
  ]

let () = run_test_tt_main suite