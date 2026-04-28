open Core
open OUnit2
open Trading_base.Types
open Trading_portfolio.Types
open Trading_portfolio.Calculations
module Portfolio = Trading_portfolio.Portfolio
module Split_event = Trading_portfolio.Split_event
open Matchers

(* Re-declare the production records to get exhaustive matcher generation
   via [ppx_test_matcher]. If a field is added or removed in
   [Trading_portfolio.Types], these declarations stop compiling — that's
   the exhaustiveness guarantee, and every call to [match_*] below has to
   handle the new field explicitly (or with [__]). *)
type position_lot = Trading_portfolio.Types.position_lot = {
  lot_id : lot_id;
  quantity : quantity;
  cost_basis : float;
  acquisition_date : Date.t;
}
[@@deriving test_matcher]

type portfolio_position = Trading_portfolio.Types.portfolio_position = {
  symbol : symbol;
  lots : position_lot list;
  accounting_method : accounting_method;
}
[@@deriving test_matcher]

(* Test fixture: synthesize a single-lot position with the given quantity and
   per-share cost. Mirrors the helper in test_calculations.ml. *)
let make_position ~symbol ~quantity ~avg_cost =
  let total_cost_basis = Float.abs quantity *. avg_cost in
  let lot =
    {
      lot_id = "lot1";
      quantity;
      cost_basis = total_cost_basis;
      acquisition_date = Date.create_exn ~y:2024 ~m:Jan ~d:15;
    }
  in
  { symbol; lots = [ lot ]; accounting_method = AverageCost }

let split_date = Date.create_exn ~y:2024 ~m:Jun ~d:10

(* Forward 4:1 split on a held position: quantity ×4, per-share cost ÷4,
   total cost basis preserved. Lot metadata (lot_id, acquisition_date)
   unchanged. *)
let test_forward_4_to_1 _ =
  let position = make_position ~symbol:"AAPL" ~quantity:100.0 ~avg_cost:150.0 in
  let event =
    { Split_event.symbol = "AAPL"; date = split_date; factor = 4.0 }
  in
  let result = Split_event.apply_to_position event position in
  assert_that result
    (match_portfolio_position ~symbol:(equal_to "AAPL")
       ~accounting_method:(equal_to AverageCost)
       ~lots:
         (elements_are
            [
              match_position_lot ~lot_id:(equal_to "lot1")
                ~quantity:(float_equal 400.0) ~cost_basis:(float_equal 15000.0)
                ~acquisition_date:
                  (equal_to (Date.create_exn ~y:2024 ~m:Jan ~d:15));
            ]))

(* Reverse 1:5 split: 500 → 100 shares; per-share cost $10 → $50; total
   cost basis preserved at $5,000. *)
let test_reverse_1_to_5 _ =
  let position = make_position ~symbol:"BRKB" ~quantity:500.0 ~avg_cost:10.0 in
  let event =
    { Split_event.symbol = "BRKB"; date = split_date; factor = 0.2 }
  in
  let result = Split_event.apply_to_position event position in
  assert_that result
    (all_of
       [
         field position_quantity (float_equal 100.0);
         field avg_cost_of_position (float_equal 50.0);
         field position_cost_basis (float_equal 5000.0);
       ])

(* Split applied to a portfolio that does not hold the symbol: portfolio is
   returned unchanged (cash, positions, trade history, accounting method
   all preserved). *)
let test_no_op_when_symbol_not_held _ =
  let portfolio =
    Portfolio.create ~accounting_method:AverageCost ~initial_cash:10000.0 ()
  in
  let buy_trade =
    {
      id = "t1";
      order_id = "o1";
      symbol = "MSFT";
      side = Buy;
      quantity = 50.0;
      price = 200.0;
      commission = 0.0;
      timestamp = Time_ns_unix.now ();
    }
  in
  let portfolio_with_msft =
    match Portfolio.apply_trades portfolio [ buy_trade ] with
    | Ok p -> p
    | Error err -> assert_failure ("Failed to apply trade: " ^ Status.show err)
  in
  let event =
    { Split_event.symbol = "AAPL"; date = split_date; factor = 4.0 }
  in
  let result = Split_event.apply_to_portfolio event portfolio_with_msft in
  assert_that result (equal_to portfolio_with_msft)

(* Fractional 3:2 split (factor 1.5): 100 shares → 150 shares (integer in
   this case), per-share cost $60 → $40. Pin a non-integer outcome too:
   75 shares × 1.5 = 112.5 fractional shares, with cost basis preserved. *)
let test_fractional_3_to_2_split _ =
  let position = make_position ~symbol:"GOOG" ~quantity:75.0 ~avg_cost:60.0 in
  let event =
    { Split_event.symbol = "GOOG"; date = split_date; factor = 1.5 }
  in
  let result = Split_event.apply_to_position event position in
  assert_that result
    (all_of
       [
         field position_quantity (float_equal 112.5);
         field avg_cost_of_position (float_equal 40.0);
         field position_cost_basis (float_equal 4500.0);
       ])

(* End-to-end portfolio adjustment: held position is rescaled, cash
   unchanged, trade_history unchanged, accounting_method unchanged. *)
let test_apply_to_portfolio_rescales_held_position _ =
  let portfolio =
    Portfolio.create ~accounting_method:AverageCost ~initial_cash:20000.0 ()
  in
  let buy_trade =
    {
      id = "t1";
      order_id = "o1";
      symbol = "AAPL";
      side = Buy;
      quantity = 100.0;
      price = 150.0;
      commission = 0.0;
      timestamp = Time_ns_unix.now ();
    }
  in
  let portfolio_with_aapl =
    match Portfolio.apply_trades portfolio [ buy_trade ] with
    | Ok p -> p
    | Error err -> assert_failure ("Failed to apply trade: " ^ Status.show err)
  in
  let event =
    { Split_event.symbol = "AAPL"; date = split_date; factor = 4.0 }
  in
  let result = Split_event.apply_to_portfolio event portfolio_with_aapl in
  assert_that result
    (all_of
       [
         field
           (fun (p : Portfolio.t) -> p.current_cash)
           (float_equal portfolio_with_aapl.current_cash);
         field
           (fun (p : Portfolio.t) -> p.initial_cash)
           (float_equal portfolio_with_aapl.initial_cash);
         field
           (fun (p : Portfolio.t) -> p.accounting_method)
           (equal_to AverageCost);
         field
           (fun (p : Portfolio.t) -> List.length p.trade_history)
           (equal_to (List.length portfolio_with_aapl.trade_history));
         field
           (fun (p : Portfolio.t) ->
             Portfolio.get_position p "AAPL"
             |> Option.value_map ~default:0.0 ~f:position_quantity)
           (float_equal 400.0);
         field
           (fun (p : Portfolio.t) ->
             Portfolio.get_position p "AAPL"
             |> Option.value_map ~default:0.0 ~f:avg_cost_of_position)
           (float_equal 37.5);
       ])

let suite =
  "test_split_event"
  >::: [
         "test_forward_4_to_1" >:: test_forward_4_to_1;
         "test_reverse_1_to_5" >:: test_reverse_1_to_5;
         "test_no_op_when_symbol_not_held" >:: test_no_op_when_symbol_not_held;
         "test_fractional_3_to_2_split" >:: test_fractional_3_to_2_split;
         "test_apply_to_portfolio_rescales_held_position"
         >:: test_apply_to_portfolio_rescales_held_position;
       ]

let () = run_test_tt_main suite
