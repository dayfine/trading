open Core
open OUnit2
open Trading_base.Types
open Trading_portfolio.Types
open Trading_portfolio.Calculations

(* Helper functions *)
let assert_float_equal expected actual ~msg =
  assert_equal expected actual ~cmp:Float.equal ~msg

let make_trade ~id ~order_id ~symbol ~side ~quantity ~price ?(commission = 0.0)
    () =
  {
    id;
    order_id;
    symbol;
    side;
    quantity;
    price;
    commission;
    timestamp = Time_ns_unix.now ();
  }

let make_position ~symbol ~quantity ~avg_cost = { symbol; quantity; avg_cost }

let test_market_value _ =
  let position = make_position ~symbol:"AAPL" ~quantity:100.0 ~avg_cost:150.0 in
  let market_price = 160.0 in
  let expected = 100.0 *. 160.0 in
  let actual = market_value position market_price in
  assert_float_equal expected actual ~msg:"Market value calculation"

let test_unrealized_pnl_profit _ =
  let position = make_position ~symbol:"AAPL" ~quantity:100.0 ~avg_cost:150.0 in
  let market_price = 160.0 in
  (* Current value: 100 * 160 = 16000, Cost basis: 100 * 150 = 15000 *)
  let expected_pnl = 1000.0 in
  let actual_pnl = unrealized_pnl position market_price in
  assert_float_equal expected_pnl actual_pnl ~msg:"Unrealized profit"

let test_unrealized_pnl_loss _ =
  let position = make_position ~symbol:"AAPL" ~quantity:100.0 ~avg_cost:150.0 in
  let market_price = 140.0 in
  (* Current value: 100 * 140 = 14000, Cost basis: 100 * 150 = 15000 *)
  let expected_pnl = -1000.0 in
  let actual_pnl = unrealized_pnl position market_price in
  assert_float_equal expected_pnl actual_pnl ~msg:"Unrealized loss"

let test_position_cost_basis _ =
  let position = make_position ~symbol:"AAPL" ~quantity:50.0 ~avg_cost:175.0 in
  let expected = 50.0 *. 175.0 in
  let actual = position_cost_basis position in
  assert_float_equal expected actual ~msg:"Position cost basis"

let test_portfolio_value_with_market_prices _ =
  let positions =
    [
      make_position ~symbol:"AAPL" ~quantity:100.0 ~avg_cost:150.0;
      make_position ~symbol:"MSFT" ~quantity:50.0 ~avg_cost:200.0;
    ]
  in
  let cash_value = 5000.0 in
  let market_prices = [ ("AAPL", 160.0); ("MSFT", 210.0) ] in
  (* AAPL: 100 * 160 = 16000, MSFT: 50 * 210 = 10500, Cash: 5000 *)
  let expected = 16000.0 +. 10500.0 +. 5000.0 in
  let actual = portfolio_value [] positions cash_value market_prices in
  assert_float_equal expected actual ~msg:"Portfolio value with market prices"

let test_portfolio_value_missing_prices _ =
  let positions =
    [
      make_position ~symbol:"AAPL" ~quantity:100.0 ~avg_cost:150.0;
      make_position ~symbol:"MSFT" ~quantity:50.0 ~avg_cost:200.0;
    ]
  in
  let cash_value = 5000.0 in
  let market_prices = [ ("AAPL", 160.0) ] in
  (* Missing MSFT price *)
  (* AAPL: 100 * 160 = 16000, MSFT: 50 * 200 = 10000 (fallback), Cash: 5000 *)
  let expected = 16000.0 +. 10000.0 +. 5000.0 in
  let actual = portfolio_value [] positions cash_value market_prices in
  assert_float_equal expected actual ~msg:"Portfolio value with missing prices"

let test_realized_pnl_from_trades _ =
  let trades =
    [
      (* Buy 100 shares at $150 each with $5 commission *)
      make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy
        ~quantity:100.0 ~price:150.0 ~commission:5.0 ();
      (* Sell 50 shares at $160 each with $3 commission *)
      make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Sell
        ~quantity:50.0 ~price:160.0 ~commission:3.0 ();
      (* Sell remaining 50 shares at $155 each with $2 commission *)
      make_trade ~id:"t3" ~order_id:"o3" ~symbol:"AAPL" ~side:Sell
        ~quantity:50.0 ~price:155.0 ~commission:2.0 ();
    ]
  in

  (* Realized P&L calculation:
     Buy:  -(100*150 + 5) = -15005
     Sell: +(50*160 - 3) = +7997
     Sell: +(50*155 - 2) = +7748
     Total: -15005 + 7997 + 7748 = 740 *)
  let expected_pnl = 740.0 in
  let actual_pnl = realized_pnl_from_trades trades in
  assert_float_equal expected_pnl actual_pnl ~msg:"Realized P&L calculation"

let test_realized_pnl_no_trades _ =
  let trades = [] in
  let expected_pnl = 0.0 in
  let actual_pnl = realized_pnl_from_trades trades in
  assert_float_equal expected_pnl actual_pnl
    ~msg:"No trades should give zero P&L"

let test_realized_pnl_only_buys _ =
  let trades =
    [
      make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy
        ~quantity:100.0 ~price:150.0 ~commission:5.0 ();
      make_trade ~id:"t2" ~order_id:"o2" ~symbol:"MSFT" ~side:Buy ~quantity:50.0
        ~price:200.0 ~commission:3.0 ();
    ]
  in

  (* Only buys: -(100*150 + 5) - (50*200 + 3) = -15005 - 10003 = -25008 *)
  let expected_pnl = -25008.0 in
  let actual_pnl = realized_pnl_from_trades trades in
  assert_float_equal expected_pnl actual_pnl ~msg:"Only buy trades"

let suite =
  "Calculations"
  >::: [
         "market_value" >:: test_market_value;
         "unrealized_pnl_profit" >:: test_unrealized_pnl_profit;
         "unrealized_pnl_loss" >:: test_unrealized_pnl_loss;
         "position_cost_basis" >:: test_position_cost_basis;
         "portfolio_value_with_market_prices"
         >:: test_portfolio_value_with_market_prices;
         "portfolio_value_missing_prices"
         >:: test_portfolio_value_missing_prices;
         "realized_pnl_from_trades" >:: test_realized_pnl_from_trades;
         "realized_pnl_no_trades" >:: test_realized_pnl_no_trades;
         "realized_pnl_only_buys" >:: test_realized_pnl_only_buys;
       ]

let () = run_test_tt_main suite
