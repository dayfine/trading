open Core
open OUnit2
open Trading_base.Types
open Trading_portfolio.Types
open Trading_portfolio.Calculations
open Matchers

(* Test data builders - simple record constructors *)
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

let make_position ~symbol ~quantity ~avg_cost =
  (* For testing: create a single lot representing the position (AverageCost behavior) *)
  let total_cost_basis = Float.abs quantity *. avg_cost in
  let lot =
    {
      lot_id = "test";
      quantity;
      cost_basis = total_cost_basis;
      acquisition_date = Date.today ~zone:Time_float.Zone.utc;
    }
  in
  { symbol; lots = [ lot ]; accounting_method = AverageCost }

let test_market_value _ =
  let position = make_position ~symbol:"AAPL" ~quantity:100.0 ~avg_cost:150.0 in
  let market_price = 160.0 in
  let expected = 100.0 *. 160.0 in
  let actual = market_value position market_price in
  assert_that actual (float_equal expected)

let test_unrealized_pnl_profit _ =
  let position = make_position ~symbol:"AAPL" ~quantity:100.0 ~avg_cost:150.0 in
  let market_price = 160.0 in
  (* Current value: 100 * 160 = 16000, Cost basis: 100 * 150 = 15000 *)
  let expected_pnl = 1000.0 in
  let actual_pnl = unrealized_pnl position market_price in
  assert_that actual_pnl (float_equal expected_pnl)

let test_unrealized_pnl_loss _ =
  let position = make_position ~symbol:"AAPL" ~quantity:100.0 ~avg_cost:150.0 in
  let market_price = 140.0 in
  (* Current value: 100 * 140 = 14000, Cost basis: 100 * 150 = 15000 *)
  let expected_pnl = -1000.0 in
  let actual_pnl = unrealized_pnl position market_price in
  assert_that actual_pnl (float_equal expected_pnl)

let test_position_cost_basis _ =
  let position = make_position ~symbol:"AAPL" ~quantity:50.0 ~avg_cost:175.0 in
  let expected = 50.0 *. 175.0 in
  let actual = position_cost_basis position in
  assert_that actual (float_equal expected)

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
  assert_that
    (portfolio_value positions cash_value market_prices)
    (is_ok_and_holds (float_equal expected))

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
  (* This should now return an error because MSFT price is missing *)
  assert_that (portfolio_value positions cash_value market_prices) is_error

let test_realized_pnl_from_trades _ =
  (* Create trade_with_pnl records with cash flow P&L for backward compatibility *)
  let trade_history =
    [
      {
        trade =
          make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy
            ~quantity:100.0 ~price:150.0 ~commission:5.0 ();
        realized_pnl = -15005.0;
        (* Cash flow: -(100*150 + 5) *)
      };
      {
        trade =
          make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Sell
            ~quantity:50.0 ~price:160.0 ~commission:3.0 ();
        realized_pnl = 7997.0;
        (* Cash flow: +(50*160 - 3) *)
      };
      {
        trade =
          make_trade ~id:"t3" ~order_id:"o3" ~symbol:"AAPL" ~side:Sell
            ~quantity:50.0 ~price:155.0 ~commission:2.0 ();
        realized_pnl = 7748.0;
        (* Cash flow: +(50*155 - 2) *)
      };
    ]
  in

  (* Total: -15005 + 7997 + 7748 = 740 *)
  let expected_pnl = 740.0 in
  let actual_pnl = realized_pnl_from_trades trade_history in
  assert_that actual_pnl (float_equal expected_pnl)

let test_realized_pnl_no_trades _ =
  let trade_history = [] in
  let expected_pnl = 0.0 in
  let actual_pnl = realized_pnl_from_trades trade_history in
  assert_that actual_pnl (float_equal expected_pnl)

let test_realized_pnl_only_buys _ =
  let trade_history =
    [
      {
        trade =
          make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy
            ~quantity:100.0 ~price:150.0 ~commission:5.0 ();
        realized_pnl = -15005.0;
        (* Cash flow: -(100*150 + 5) *)
      };
      {
        trade =
          make_trade ~id:"t2" ~order_id:"o2" ~symbol:"MSFT" ~side:Buy
            ~quantity:50.0 ~price:200.0 ~commission:3.0 ();
        realized_pnl = -10003.0;
        (* Cash flow: -(50*200 + 3) *)
      };
    ]
  in

  (* Total: -15005 + -10003 = -25008 *)
  let expected_pnl = -25008.0 in
  let actual_pnl = realized_pnl_from_trades trade_history in
  assert_that actual_pnl (float_equal expected_pnl)

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
