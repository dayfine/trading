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

let _empty_positions = String.Map.empty

let test_inject_extract_roundtrip _ =
  let positions = Portfolio_view.inject_cash ~cash:50000.0 _empty_positions in
  assert_that (Portfolio_view.extract_cash positions) (float_equal 50000.0)

let test_extract_cash_missing_returns_zero _ =
  assert_that (Portfolio_view.extract_cash _empty_positions) (float_equal 0.0)

let test_inject_overwrites _ =
  let positions =
    _empty_positions
    |> Portfolio_view.inject_cash ~cash:10000.0
    |> Portfolio_view.inject_cash ~cash:25000.0
  in
  assert_that (Portfolio_view.extract_cash positions) (float_equal 25000.0)

let test_positions_only_removes_cash _ =
  let aapl =
    _make_holding ~id:"AAPL-1" ~symbol:"AAPL" ~quantity:100.0 ~entry_price:150.0
  in
  let positions =
    _empty_positions
    |> Map.set ~key:"AAPL-1" ~data:aapl
    |> Portfolio_view.inject_cash ~cash:50000.0
  in
  let real = Portfolio_view.positions_only positions in
  assert_that (Map.length real) (equal_to 1);
  assert_that (Map.mem real Portfolio_view.cash_key) (equal_to false);
  assert_that (Map.mem real "AAPL-1") (equal_to true)

let test_compute_portfolio_value_cash_only _ =
  let positions = Portfolio_view.inject_cash ~cash:100000.0 _empty_positions in
  let get_price _ = None in
  assert_that
    (Portfolio_view.compute_portfolio_value positions ~get_price)
    (float_equal 100000.0)

let test_compute_portfolio_value_with_positions _ =
  let aapl =
    _make_holding ~id:"AAPL-1" ~symbol:"AAPL" ~quantity:100.0 ~entry_price:150.0
  in
  let positions =
    _empty_positions
    |> Map.set ~key:"AAPL-1" ~data:aapl
    |> Portfolio_view.inject_cash ~cash:50000.0
  in
  let get_price symbol =
    if String.equal symbol "AAPL" then Some (_make_price 160.0) else None
  in
  (* 50000 cash + 100 shares * 160 = 66000 *)
  assert_that
    (Portfolio_view.compute_portfolio_value positions ~get_price)
    (float_equal 66000.0)

let test_compute_portfolio_value_no_price_excludes _ =
  let aapl =
    _make_holding ~id:"AAPL-1" ~symbol:"AAPL" ~quantity:100.0 ~entry_price:150.0
  in
  let positions =
    _empty_positions
    |> Map.set ~key:"AAPL-1" ~data:aapl
    |> Portfolio_view.inject_cash ~cash:50000.0
  in
  let get_price _ = None in
  (* AAPL has no price, excluded; only cash counted *)
  assert_that
    (Portfolio_view.compute_portfolio_value positions ~get_price)
    (float_equal 50000.0)

let suite =
  "portfolio_view"
  >::: [
         "inject_extract_roundtrip" >:: test_inject_extract_roundtrip;
         "extract_cash_missing_returns_zero"
         >:: test_extract_cash_missing_returns_zero;
         "inject_overwrites" >:: test_inject_overwrites;
         "positions_only_removes_cash" >:: test_positions_only_removes_cash;
         "compute_portfolio_value_cash_only"
         >:: test_compute_portfolio_value_cash_only;
         "compute_portfolio_value_with_positions"
         >:: test_compute_portfolio_value_with_positions;
         "compute_portfolio_value_no_price_excludes"
         >:: test_compute_portfolio_value_no_price_excludes;
       ]

let () = run_test_tt_main suite
