open OUnit2
open Core
open Matchers
open Trading_strategy

let _make_holding ~id ~symbol ~quantity ~entry_price =
  {
    Position.id;
    symbol;
    side = Long;
    entry_reasoning = ManualDecision { description = "test" };
    exit_reason = None;
    state =
      Holding
        {
          quantity;
          entry_price;
          entry_date = Date.of_string "2024-01-01";
          risk_params =
            {
              stop_loss_price = None;
              take_profit_price = None;
              max_hold_days = None;
            };
        };
    last_updated = Date.of_string "2024-01-01";
    portfolio_lot_ids = [];
  }

let _make_price close_price =
  {
    Types.Daily_price.date = Date.of_string "2024-06-01";
    open_price = close_price;
    high_price = close_price;
    low_price = close_price;
    close_price;
    adjusted_close = close_price;
    volume = 1000;
  }

let test_portfolio_value_cash_only _ =
  let pv : Portfolio_view.t =
    { cash = 100000.0; positions = String.Map.empty }
  in
  let get_price _ = None in
  assert_that
    (Portfolio_view.portfolio_value pv ~get_price)
    (float_equal 100000.0)

let test_portfolio_value_with_positions _ =
  let aapl =
    _make_holding ~id:"AAPL-1" ~symbol:"AAPL" ~quantity:100.0 ~entry_price:150.0
  in
  let pv : Portfolio_view.t =
    { cash = 50000.0; positions = String.Map.singleton "AAPL-1" aapl }
  in
  let get_price symbol =
    if String.equal symbol "AAPL" then Some (_make_price 160.0) else None
  in
  (* 50000 cash + 100 shares * 160 = 66000 *)
  assert_that
    (Portfolio_view.portfolio_value pv ~get_price)
    (float_equal 66000.0)

let test_portfolio_value_no_price_excludes _ =
  let aapl =
    _make_holding ~id:"AAPL-1" ~symbol:"AAPL" ~quantity:100.0 ~entry_price:150.0
  in
  let pv : Portfolio_view.t =
    { cash = 50000.0; positions = String.Map.singleton "AAPL-1" aapl }
  in
  let get_price _ = None in
  assert_that
    (Portfolio_view.portfolio_value pv ~get_price)
    (float_equal 50000.0)

let suite =
  "portfolio_view"
  >::: [
         "portfolio_value_cash_only" >:: test_portfolio_value_cash_only;
         "portfolio_value_with_positions"
         >:: test_portfolio_value_with_positions;
         "portfolio_value_no_price_excludes"
         >:: test_portfolio_value_no_price_excludes;
       ]

let () = run_test_tt_main suite
