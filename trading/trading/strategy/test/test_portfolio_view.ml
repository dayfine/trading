open OUnit2
open Core
open Matchers
open Trading_strategy

let _make_holding ~id ~symbol ~side ~quantity ~entry_price =
  {
    Position.id;
    symbol;
    side;
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

let test_portfolio_value_with_long_position _ =
  let aapl =
    _make_holding ~id:"AAPL-1" ~symbol:"AAPL" ~side:Long ~quantity:100.0
      ~entry_price:150.0
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
    _make_holding ~id:"AAPL-1" ~symbol:"AAPL" ~side:Long ~quantity:100.0
      ~entry_price:150.0
  in
  let pv : Portfolio_view.t =
    { cash = 50000.0; positions = String.Map.singleton "AAPL-1" aapl }
  in
  let get_price _ = None in
  assert_that
    (Portfolio_view.portfolio_value pv ~get_price)
    (float_equal 50000.0)

(* G8 — short positions must subtract from portfolio value, not add.

   Setup: $1M cash already reflects the short proceeds (entry $100 * 100 sh =
   $10K credited, so cash = $1.01M post-entry under broker model). At current
   price $90 (short profit), the liability to buy back is 100 * $90 = $9K.

   Correct portfolio_value = cash - liability = $1,010,000 - $9,000 =
   $1,001,000. *)
let test_portfolio_value_short_position_at_profit _ =
  let xyz =
    _make_holding ~id:"XYZ-1" ~symbol:"XYZ" ~side:Short ~quantity:100.0
      ~entry_price:100.0
  in
  let pv : Portfolio_view.t =
    { cash = 1_010_000.0; positions = String.Map.singleton "XYZ-1" xyz }
  in
  let get_price symbol =
    if String.equal symbol "XYZ" then Some (_make_price 90.0) else None
  in
  assert_that
    (Portfolio_view.portfolio_value pv ~get_price)
    (float_equal 1_001_000.0)

(* G8 — short at a loss: cash $1.01M (post-entry), current $110 → liability
   $11K. portfolio_value = $1,010,000 - $11,000 = $999,000. *)
let test_portfolio_value_short_position_at_loss _ =
  let xyz =
    _make_holding ~id:"XYZ-1" ~symbol:"XYZ" ~side:Short ~quantity:100.0
      ~entry_price:100.0
  in
  let pv : Portfolio_view.t =
    { cash = 1_010_000.0; positions = String.Map.singleton "XYZ-1" xyz }
  in
  let get_price symbol =
    if String.equal symbol "XYZ" then Some (_make_price 110.0) else None
  in
  assert_that
    (Portfolio_view.portfolio_value pv ~get_price)
    (float_equal 999_000.0)

(* G8 — mixed long + short. Long AAPL 100 sh entry $150, current $160 → +$16K
   asset. Short XYZ 100 sh entry $100, current $110 → -$11K liability. Cash
   $50K. Total = $50K + $16K - $11K = $55K. *)
let test_portfolio_value_mixed_long_and_short _ =
  let aapl =
    _make_holding ~id:"AAPL-1" ~symbol:"AAPL" ~side:Long ~quantity:100.0
      ~entry_price:150.0
  in
  let xyz =
    _make_holding ~id:"XYZ-1" ~symbol:"XYZ" ~side:Short ~quantity:100.0
      ~entry_price:100.0
  in
  let positions =
    String.Map.of_alist_exn [ ("AAPL-1", aapl); ("XYZ-1", xyz) ]
  in
  let pv : Portfolio_view.t = { cash = 50_000.0; positions } in
  let get_price symbol =
    match symbol with
    | "AAPL" -> Some (_make_price 160.0)
    | "XYZ" -> Some (_make_price 110.0)
    | _ -> None
  in
  assert_that
    (Portfolio_view.portfolio_value pv ~get_price)
    (float_equal 55_000.0)

let suite =
  "portfolio_view"
  >::: [
         "portfolio_value_cash_only" >:: test_portfolio_value_cash_only;
         "portfolio_value_with_long_position"
         >:: test_portfolio_value_with_long_position;
         "portfolio_value_no_price_excludes"
         >:: test_portfolio_value_no_price_excludes;
         "portfolio_value_short_position_at_profit"
         >:: test_portfolio_value_short_position_at_profit;
         "portfolio_value_short_position_at_loss"
         >:: test_portfolio_value_short_position_at_loss;
         "portfolio_value_mixed_long_and_short"
         >:: test_portfolio_value_mixed_long_and_short;
       ]

let () = run_test_tt_main suite
