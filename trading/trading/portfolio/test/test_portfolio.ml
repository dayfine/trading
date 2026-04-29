open Core
open OUnit2
open Trading_base.Types
open Trading_portfolio.Types
open Trading_portfolio.Portfolio
open Trading_portfolio.Calculations
open Matchers

(* Domain-specific helper using matchers library *)
let apply_trades_exn portfolio trades ~error_msg =
  match apply_trades portfolio trades with
  | Ok value -> value
  | Error err -> OUnit2.assert_failure (error_msg ^ ": " ^ Status.show err)

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

(* ========================================================================== *)
(* Accounting-method agnostic tests - run for both AverageCost and FIFO      *)
(* ========================================================================== *)

let test_create_portfolio _ accounting_method =
  let portfolio = create ~accounting_method ~initial_cash:10000.0 () in
  let expected =
    {
      initial_cash = 10000.0;
      current_cash = 10000.0;
      trade_history = [];
      positions = [];
      accounting_method;
      unrealized_pnl_per_position = [];
    }
  in
  assert_equal expected portfolio ~msg:"Portfolio should match expected state"

let test_apply_buy_trade _ accounting_method =
  let portfolio = create ~accounting_method ~initial_cash:20000.0 () in
  let buy_trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:150.0 ()
  in

  assert_that
    (apply_trades portfolio [ buy_trade ])
    (is_ok_and_holds (fun updated_portfolio ->
         (* Cash should be reduced by 100 * 150 = 15000 *)
         assert_that updated_portfolio.current_cash (float_equal 5000.0);

         (* Trade should be in history *)
         assert_equal 1
           (List.length updated_portfolio.trade_history)
           ~msg:"Trade in history";

         (* Position should be created *)
         assert_that
           (get_position updated_portfolio "AAPL")
           (is_some_and (fun position ->
                assert_that (position_quantity position) (float_equal 100.0);
                assert_that (avg_cost_of_position position) (float_equal 150.0)))))

let test_apply_sell_trade _ accounting_method =
  let portfolio = create ~accounting_method ~initial_cash:20000.0 () in

  (* Buy 100 shares, then sell 50 shares at a higher price *)
  let portfolio =
    apply_trades_exn portfolio
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy
          ~quantity:100.0 ~price:150.0 ();
        make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Sell
          ~quantity:50.0 ~price:160.0 ();
      ]
      ~error_msg:"Trades should succeed"
  in

  (* Cash: 20000 - 15000 + 8000 = 13000 *)
  assert_that portfolio.current_cash (float_equal 13000.0);

  (* Position should be reduced *)
  assert_that
    (get_position portfolio "AAPL")
    (is_some_and (fun position ->
         assert_that (position_quantity position) (float_equal 50.0)))

let test_insufficient_cash _ accounting_method =
  let portfolio = create ~accounting_method ~initial_cash:1000.0 () in
  let expensive_trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:150.0 ()
  in

  assert_that (apply_trades portfolio [ expensive_trade ]) is_error

let test_short_selling_allowed _ accounting_method =
  let portfolio = create ~accounting_method ~initial_cash:10000.0 () in
  let sell_trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell ~quantity:100.0
      ~price:150.0 ()
  in

  assert_that
    (apply_trades portfolio [ sell_trade ])
    (is_ok_and_holds (fun updated_portfolio ->
         (* Short selling should be allowed and create negative position *)
         assert_that
           (get_position updated_portfolio "AAPL")
           (is_some_and (fun position ->
                assert_that (position_quantity position) (float_equal (-100.0))))))

let test_position_close _ accounting_method =
  let portfolio = create ~accounting_method ~initial_cash:20000.0 () in

  (* Buy 100 shares, then sell all shares *)
  let portfolio =
    apply_trades_exn portfolio
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy
          ~quantity:100.0 ~price:150.0 ();
        make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Sell
          ~quantity:100.0 ~price:160.0 ();
      ]
      ~error_msg:"Trades should succeed"
  in

  (* Position should be closed (removed) *)
  assert_that (get_position portfolio "AAPL") is_none;
  assert_equal [] portfolio.positions ~msg:"No positions remaining"

let test_validation _ accounting_method =
  let portfolio = create ~accounting_method ~initial_cash:20000.0 () in
  let trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:150.0 ()
  in

  assert_that
    (apply_trades portfolio [ trade ])
    (is_ok_and_holds (fun updated_portfolio ->
         assert_that
           (validate updated_portfolio)
           (is_ok_and_holds (fun () -> ()))))

let test_multiple_trades_batch _ accounting_method =
  let portfolio = create ~accounting_method ~initial_cash:30000.0 () in
  let trades =
    [
      make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy
        ~quantity:100.0 ~price:150.0 ();
      make_trade ~id:"t2" ~order_id:"o2" ~symbol:"MSFT" ~side:Buy ~quantity:50.0
        ~price:200.0 ();
    ]
  in

  assert_that
    (apply_trades portfolio trades)
    (is_ok_and_holds (fun updated_portfolio ->
         assert_equal 2
           (List.length updated_portfolio.positions)
           ~msg:"Two positions created";
         assert_equal 2
           (List.length updated_portfolio.trade_history)
           ~msg:"Two trades in history";
         (* Cash: 30000 - (100*150) - (50*200) = 30000 - 15000 - 10000 = 5000 *)
         assert_that updated_portfolio.current_cash (float_equal 5000.0)))

let test_short_selling _ accounting_method =
  let portfolio = create ~accounting_method ~initial_cash:10000.0 () in

  (* Short sell 100 shares at $150 *)
  let short_trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell ~quantity:100.0
      ~price:150.0 ()
  in

  match apply_trades portfolio [ short_trade ] with
  | Ok updated_portfolio ->
      (* Cash should increase by 100 * 150 = 15000 *)
      assert_that updated_portfolio.current_cash (float_equal 25000.0);

      (* Position should be negative *)
      assert_that
        (get_position updated_portfolio "AAPL")
        (is_some_and (fun position ->
             assert_that (position_quantity position) (float_equal (-100.0));
             assert_that (avg_cost_of_position position) (float_equal 150.0)))
  | Error err -> assert_failure ("Short sell failed: " ^ Status.show err)

let test_short_cover _ accounting_method =
  let portfolio = create ~accounting_method ~initial_cash:10000.0 () in

  (* Short sell 100 shares at $150 with commission, then buy to cover 50 shares *)
  let portfolio =
    apply_trades_exn portfolio
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell
          ~quantity:100.0 ~price:150.0 ~commission:5.0 ();
        make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Buy
          ~quantity:50.0 ~price:140.0 ~commission:3.0 ();
      ]
      ~error_msg:"Trades should succeed"
  in

  (* Cash: 10000 + (15000 - 5) - (7000 + 3) = 10000 + 14995 - 7003 = 17992 *)
  assert_that portfolio.current_cash (float_equal 17992.0);

  (* Verify realized P&L: covering 50 shares
     P&L = 50 * ($149.95 - $140) - $3 = 50 * $9.95 - $3 = $497.50 - $3 = $494.50 *)
  let history = portfolio.trade_history in
  let cover_pnl = (List.nth_exn history 1).realized_pnl in
  assert_that cover_pnl (float_equal 494.5);

  (* Position should be -50 shares *)
  assert_that
    (get_position portfolio "AAPL")
    (is_some_and (fun position ->
         assert_that (position_quantity position) (float_equal (-50.0));
         assert_that (avg_cost_of_position position) (float_equal 149.95)))

let test_short_to_long _ accounting_method =
  let portfolio = create ~accounting_method ~initial_cash:10000.0 () in

  (* Short sell 50 shares at $150, then buy 100 shares to flip to long *)
  let portfolio =
    apply_trades_exn portfolio
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell
          ~quantity:50.0 ~price:150.0 ();
        make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Buy
          ~quantity:100.0 ~price:140.0 ();
      ]
      ~error_msg:"Trades should succeed"
  in

  (* Cash: 10000 + 7500 - 14000 = 3500 *)
  assert_that portfolio.current_cash (float_equal 3500.0);

  (* Position should be +50 shares at new cost basis *)
  assert_that
    (get_position portfolio "AAPL")
    (is_some_and (fun position ->
         assert_that (position_quantity position) (float_equal 50.0);
         assert_that (avg_cost_of_position position) (float_equal 140.0)))

let test_commission_in_cost_basis _ accounting_method =
  let portfolio = create ~accounting_method ~initial_cash:20000.0 () in

  (* Buy 100 shares at $100 with $10 commission *)
  let buy_trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:100.0 ~commission:10.0 ()
  in

  assert_that
    (apply_trades portfolio [ buy_trade ])
    (is_ok_and_holds (fun updated_portfolio ->
         (* Cost basis should be $100.10 per share ($100 + $10/100) *)
         assert_that
           (get_position updated_portfolio "AAPL")
           (is_some_and (fun position ->
                assert_that (position_quantity position) (float_equal 100.0);
                assert_that (avg_cost_of_position position) (float_equal 100.10)))))

let test_realized_pnl_calculation _ accounting_method =
  let portfolio = create ~accounting_method ~initial_cash:20000.0 () in
  let trades =
    [
      (* Buy 100 shares at $150 each with $5 commission *)
      make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy
        ~quantity:100.0 ~price:150.0 ~commission:5.0 ();
      (* Sell 50 shares at $160 each with $3 commission - should realize P&L *)
      make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Sell
        ~quantity:50.0 ~price:160.0 ~commission:3.0 ();
      (* Sell remaining 50 shares at $155 each with $2 commission - should realize P&L *)
      make_trade ~id:"t3" ~order_id:"o3" ~symbol:"AAPL" ~side:Sell
        ~quantity:50.0 ~price:155.0 ~commission:2.0 ();
    ]
  in

  let updated_portfolio =
    match apply_trades portfolio trades with
    | Ok value -> value
    | Error err ->
        OUnit2.assert_failure ("Realized P&L test failed: " ^ Status.show err)
  in

  let trade_history = updated_portfolio.trade_history in
  assert_equal 3 (List.length trade_history) ~msg:"Should have 3 trades";

  let trade1 = List.nth_exn trade_history 0 in
  let trade2 = List.nth_exn trade_history 1 in
  let trade3 = List.nth_exn trade_history 2 in

  assert_that trade1.realized_pnl (float_equal 0.0);

  (* Different P&L expectations based on accounting method *)
  (match accounting_method with
  | AverageCost ->
      (* AverageCost: Both sells use same avg cost of $150.05/share
         Sell 50 @ $160 - $3: P&L = 50 * ($160 - $150.05) - $3 = $494.50
         Sell 50 @ $155 - $2: P&L = 50 * ($155 - $150.05) - $2 = $245.50 *)
      assert_that trade2.realized_pnl (float_equal 494.5);
      assert_that trade3.realized_pnl (float_equal 245.5)
  | FIFO ->
      (* FIFO: Sells consume lots in order (all from same lot in this case)
         Same as AverageCost since there's only one lot
         Sell 50 @ $160 - $3: P&L = 50 * ($160 - $150.05) - $3 = $494.50
         Sell 50 @ $155 - $2: P&L = 50 * ($155 - $150.05) - $2 = $245.50 *)
      assert_that trade2.realized_pnl (float_equal 494.5);
      assert_that trade3.realized_pnl (float_equal 245.5));

  let total_pnl = realized_pnl_from_trades updated_portfolio.trade_history in
  assert_that total_pnl (float_equal 740.0);

  (* Position should be closed *)
  assert_that (get_position updated_portfolio "AAPL") is_none

(* ========================================================================== *)
(* Accounting-method specific tests - parameterized expectations             *)
(* ========================================================================== *)

let test_complete_offset_and_reversal _ accounting_method =
  let portfolio = create ~accounting_method ~initial_cash:50000.0 () in

  (* Test 1: Long position completely offset to zero *)
  let portfolio =
    apply_trades_exn portfolio
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy
          ~quantity:100.0 ~price:150.0 ();
        make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Sell
          ~quantity:100.0 ~price:160.0 ();
      ]
      ~error_msg:"Complete offset should succeed"
  in
  (* Position should be completely closed *)
  assert_that (get_position portfolio "AAPL") is_none;

  (* Test 2: Long position reversed to short *)
  let portfolio =
    apply_trades_exn portfolio
      [
        make_trade ~id:"t3" ~order_id:"o3" ~symbol:"MSFT" ~side:Buy
          ~quantity:50.0 ~price:200.0 ();
        make_trade ~id:"t4" ~order_id:"o4" ~symbol:"MSFT" ~side:Sell
          ~quantity:150.0 ~price:210.0 ();
      ]
      ~error_msg:"Long to short reversal should succeed"
  in
  (* Position should now be short 100 shares *)
  assert_that
    (get_position portfolio "MSFT")
    (is_some_and (fun position ->
         assert_that (position_quantity position) (float_equal (-100.0));
         assert_that (avg_cost_of_position position) (float_equal 210.0);
         (* FIFO: Only 1 lot, AverageCost: Only 1 lot *)
         let expected_lot_count = 1 in
         assert_equal expected_lot_count
           (List.length position.lots)
           ~msg:"Should have 1 lot"));

  (* Test 3: Short position reversed to long *)
  let portfolio =
    apply_trades_exn portfolio
      [
        make_trade ~id:"t5" ~order_id:"o5" ~symbol:"TSLA" ~side:Sell
          ~quantity:80.0 ~price:300.0 ();
        make_trade ~id:"t6" ~order_id:"o6" ~symbol:"TSLA" ~side:Buy
          ~quantity:120.0 ~price:290.0 ();
      ]
      ~error_msg:"Short to long reversal should succeed"
  in
  (* Position should now be long 40 shares *)
  assert_that
    (get_position portfolio "TSLA")
    (is_some_and (fun position ->
         assert_that (position_quantity position) (float_equal 40.0);
         assert_that (avg_cost_of_position position) (float_equal 290.0);
         (* FIFO: Only 1 lot, AverageCost: Only 1 lot *)
         let expected_lot_count = 1 in
         assert_equal expected_lot_count
           (List.length position.lots)
           ~msg:"Should have 1 lot"))

(* ========================================================================== *)
(* FIFO-specific tests - only run for FIFO accounting                        *)
(* ========================================================================== *)

let test_fifo_basic_buy_sell _ =
  (* Create portfolio with FIFO accounting *)
  let portfolio = create ~accounting_method:FIFO ~initial_cash:30000.0 () in

  (* Buy 100 shares at $100, then buy another 100 shares at $110 *)
  let portfolio =
    apply_trades_exn portfolio
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy
          ~quantity:100.0 ~price:100.0 ();
        make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Buy
          ~quantity:100.0 ~price:110.0 ();
      ]
      ~error_msg:"Buys should succeed"
  in

  (* Verify position has 2 lots *)
  assert_that
    (get_position portfolio "AAPL")
    (is_some_and (fun position ->
         assert_equal 2 (List.length position.lots) ~msg:"Should have 2 lots";
         assert_that (position_quantity position) (float_equal 200.0);

         (* Average cost should be (100*100 + 100*110) / 200 = 105 *)
         assert_that (avg_cost_of_position position) (float_equal 105.0)))

let test_fifo_sell_matches_oldest _ =
  (* Create portfolio with FIFO accounting *)
  let portfolio = create ~accounting_method:FIFO ~initial_cash:50000.0 () in

  (* Buy at $100, buy at $110, sell at $120 - should match against first lot *)
  let portfolio =
    apply_trades_exn portfolio
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy
          ~quantity:100.0 ~price:100.0 ();
        make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Buy
          ~quantity:100.0 ~price:110.0 ();
        make_trade ~id:"t3" ~order_id:"o3" ~symbol:"AAPL" ~side:Sell
          ~quantity:100.0 ~price:120.0 ();
      ]
      ~error_msg:"Trades should succeed"
  in

  (* Should have 1 lot remaining (the second buy at $110) *)
  assert_that
    (get_position portfolio "AAPL")
    (is_some_and (fun position ->
         assert_equal 1
           (List.length position.lots)
           ~msg:"Should have 1 lot left";
         assert_that (position_quantity position) (float_equal 100.0);

         (* Remaining lot should have cost basis of $110 per share *)
         assert_that (avg_cost_of_position position) (float_equal 110.0)))

let test_fifo_partial_lot_consumption _ =
  (* Create portfolio with FIFO accounting *)
  let portfolio = create ~accounting_method:FIFO ~initial_cash:30000.0 () in

  (* Buy at $100, buy at $110, sell 50 shares - should partially consume first lot *)
  let portfolio =
    apply_trades_exn portfolio
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy
          ~quantity:100.0 ~price:100.0 ();
        make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Buy
          ~quantity:100.0 ~price:110.0 ();
        make_trade ~id:"t3" ~order_id:"o3" ~symbol:"AAPL" ~side:Sell
          ~quantity:50.0 ~price:120.0 ();
      ]
      ~error_msg:"Trades should succeed"
  in

  (* Should have 2 lots: 50 shares at $100, 100 shares at $110 *)
  assert_that
    (get_position portfolio "AAPL")
    (is_some_and (fun position ->
         assert_equal 2
           (List.length position.lots)
           ~msg:"Should have 2 lots (partial + full)";
         assert_that (position_quantity position) (float_equal 150.0);

         (* Average cost: (50*100 + 100*110) / 150 = 106.67 *)
         assert_that
           (avg_cost_of_position position)
           (float_equal 106.666666666667)))

let test_fifo_vs_average_cost _ =
  (* Test that FIFO and AverageCost produce different results *)
  let initial_cash = 50000.0 in

  (* FIFO portfolio *)
  let portfolio_fifo = create ~accounting_method:FIFO ~initial_cash () in
  (* AverageCost portfolio *)
  let portfolio_avg = create ~accounting_method:AverageCost ~initial_cash () in

  (* Same trades for both *)
  let trades =
    [
      make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy
        ~quantity:100.0 ~price:100.0 ();
      make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Buy
        ~quantity:100.0 ~price:110.0 ();
      make_trade ~id:"t3" ~order_id:"o3" ~symbol:"AAPL" ~side:Sell
        ~quantity:100.0 ~price:120.0 ();
    ]
  in

  let portfolio_fifo =
    apply_trades_exn portfolio_fifo trades ~error_msg:"FIFO trades failed"
  in
  let portfolio_avg =
    apply_trades_exn portfolio_avg trades ~error_msg:"AverageCost trades failed"
  in

  (* Get positions *)
  let pos_fifo = get_position portfolio_fifo "AAPL" in
  let pos_avg = get_position portfolio_avg "AAPL" in

  match (pos_fifo, pos_avg) with
  | Some fifo, Some avg ->
      (* Both should have same quantity *)
      let fifo_qty = position_quantity fifo in
      let avg_qty = position_quantity avg in
      assert_that fifo_qty (float_equal avg_qty);

      (* FIFO should have 1 lot, AverageCost should have 1 lot *)
      assert_equal 1 (List.length fifo.lots) ~msg:"FIFO lots count";
      assert_equal 1 (List.length avg.lots) ~msg:"AverageCost lots count";

      (* FIFO remaining cost should be $110 (second lot) *)
      assert_that (avg_cost_of_position fifo) (float_equal 110.0);

      (* AverageCost remaining cost should be $105 (average of both) *)
      assert_that (avg_cost_of_position avg) (float_equal 105.0);

      (* FIFO and AverageCost have different realized P&L *)
      (* FIFO: Sells lot bought @ $100, so P&L = 100*(120-100) = $2000 *)
      (* AverageCost: Avg cost = $105, so P&L = 100*(120-105) = $1500 *)
      let fifo_pnl = realized_pnl_from_trades portfolio_fifo.trade_history in
      let avg_pnl = realized_pnl_from_trades portfolio_avg.trade_history in
      assert_that fifo_pnl (float_equal 2000.0);
      assert_that avg_pnl (float_equal 1500.0);

      (* The key difference is in the REMAINING position cost basis *)
      (* FIFO keeps the $110 lot, AverageCost keeps avg of $105 *)
      let cost_diff =
        Float.abs (avg_cost_of_position fifo -. avg_cost_of_position avg)
      in
      assert_that cost_diff (gt (module Float_ord) 0.01)
  | _ -> assert_failure "Both positions should exist"

let test_fifo_multiple_partial_sells _ =
  (* Create portfolio with FIFO accounting *)
  let portfolio = create ~accounting_method:FIFO ~initial_cash:50000.0 () in

  (* Buy 3 lots, sell 150 - should consume first lot fully and half of second lot *)
  let portfolio =
    apply_trades_exn portfolio
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy
          ~quantity:100.0 ~price:100.0 ();
        make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Buy
          ~quantity:100.0 ~price:110.0 ();
        make_trade ~id:"t3" ~order_id:"o3" ~symbol:"AAPL" ~side:Buy
          ~quantity:100.0 ~price:120.0 ();
        make_trade ~id:"t4" ~order_id:"o4" ~symbol:"AAPL" ~side:Sell
          ~quantity:150.0 ~price:130.0 ();
      ]
      ~error_msg:"Trades should succeed"
  in

  (* Should have 2 lots: 50 shares at $110, 100 shares at $120 *)
  assert_that
    (get_position portfolio "AAPL")
    (is_some_and (fun position ->
         assert_equal 2 (List.length position.lots) ~msg:"Should have 2 lots";
         assert_that (position_quantity position) (float_equal 150.0);

         (* Average cost: (50*110 + 100*120) / 150 = 116.67 *)
         assert_that
           (avg_cost_of_position position)
           (float_equal 116.666666666667)))

(* ========================================================================== *)
(* Soft cash-floor checks on shorts (G3 from short-side-gaps-2026-04-29.md)  *)
(* ========================================================================== *)

(* Effective cash floor =
     current_cash + cash_change + sum(min(0, unrealized_pnl_per_position))
   Sell entries (opening shorts) and Buy covers both go through this check.
   Unrealized losses on open positions count as drag against the floor.
   See [Portfolio.apply_single_trade] docstring. *)

let test_short_entry_against_sufficient_cash _ accounting_method =
  (* Empty portfolio with $10k cash; first short entry should succeed. *)
  let portfolio = create ~accounting_method ~initial_cash:10_000.0 () in
  let short_entry =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell ~quantity:100.0
      ~price:50.0 ()
  in
  assert_that
    (apply_single_trade portfolio short_entry)
    (is_ok_and_holds
       (all_of
          [
            (* Cash should rise by 100 * 50 = 5000 *)
            field (fun p -> p.current_cash) (float_equal 15_000.0);
            (* New short position should seed accumulator at 0.0 *)
            field
              (fun p -> p.unrealized_pnl_per_position)
              (elements_are [ equal_to (("AAPL", 0.0) : string * float) ]);
          ]))

let test_short_cover_within_budget_succeeds _ accounting_method =
  (* Open short, mark-to-market at a small adverse move, then cover. The
     unrealized drag is counted, but cash-on-hand is enough to absorb it
     plus the cover cash outflow. *)
  let portfolio = create ~accounting_method ~initial_cash:10_000.0 () in
  let portfolio =
    apply_trades_exn portfolio
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell
          ~quantity:100.0 ~price:50.0 ();
      ]
      ~error_msg:"Short entry should succeed"
  in
  (* Mark price at $60 → unrealized P&L = (60 - 50) * (-100) = -1000 *)
  let portfolio = mark_to_market portfolio [ ("AAPL", 60.0) ] in
  let cover =
    make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:60.0 ()
  in
  assert_that
    (apply_single_trade portfolio cover)
    (is_ok_and_holds
       (all_of
          [
            (* Cash: 10000 + 5000 - 6000 = 9000 *)
            field (fun p -> p.current_cash) (float_equal 9_000.0);
            (* Position closed → accumulator pruned *)
            field (fun p -> p.unrealized_pnl_per_position) is_empty;
          ]))

let test_short_entry_rejected_when_unrealized_drag_exceeds_cash _
    accounting_method =
  (* Existing short with massive unrealized loss leaves no room for
     a new short entry, even though Sell adds cash. *)
  let portfolio = create ~accounting_method ~initial_cash:1_000.0 () in
  let portfolio =
    apply_trades_exn portfolio
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell
          ~quantity:100.0 ~price:50.0 ();
      ]
      ~error_msg:"First short should succeed"
  in
  (* Cash now $6000. Mark AAPL at $200 → unrealized = (200 - 50) * -100 = -15000. *)
  let portfolio = mark_to_market portfolio [ ("AAPL", 200.0) ] in
  (* Effective floor before new short: 6000 + (-15000) = -9000 already.
     A new Sell adds cash but not enough: 100 * 50 = 5000 → -4000. *)
  let new_short =
    make_trade ~id:"t2" ~order_id:"o2" ~symbol:"MSFT" ~side:Sell ~quantity:100.0
      ~price:50.0 ()
  in
  assert_that (apply_single_trade portfolio new_short) is_error

let test_sequence_of_shorts_hits_cumulative_floor _ accounting_method =
  (* Walk through multiple shorts, mark-to-market between each, and confirm
     a final entry fails once cumulative unrealized losses outpace cash. *)
  let portfolio = create ~accounting_method ~initial_cash:2_000.0 () in
  (* 1) Short A — succeeds, cash +1000 → 3000 *)
  let portfolio =
    apply_trades_exn portfolio
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"A" ~side:Sell
          ~quantity:100.0 ~price:10.0 ();
      ]
      ~error_msg:"Short A should succeed"
  in
  (* Mark A @ $30 → unrealized = -2000. Effective floor: 3000 - 2000 = 1000. *)
  let portfolio = mark_to_market portfolio [ ("A", 30.0) ] in
  (* 2) Short B — succeeds (effective floor 1000 + 500 = 1500). *)
  let portfolio =
    apply_trades_exn portfolio
      [
        make_trade ~id:"t2" ~order_id:"o2" ~symbol:"B" ~side:Sell
          ~quantity:100.0 ~price:5.0 ();
      ]
      ~error_msg:"Short B should succeed"
  in
  (* Cash 3500. Mark A @ $30 still, mark B @ $40 → A: -2000, B: -3500.
     Sum of negatives = -5500. Effective floor: 3500 - 5500 = -2000. *)
  let portfolio = mark_to_market portfolio [ ("A", 30.0); ("B", 40.0) ] in
  (* 3) A new short, even bringing cash, can't escape the floor.
     Try Short C @ $1, qty 100 → cash_change +100. Effective:
     3500 + 100 - 5500 = -1900 < 0 → ERROR. *)
  let final_short =
    make_trade ~id:"t3" ~order_id:"o3" ~symbol:"C" ~side:Sell ~quantity:100.0
      ~price:1.0 ()
  in
  assert_that (apply_single_trade portfolio final_short) is_error

let test_mark_to_market_drops_positions_without_price _ accounting_method =
  (* mark_to_market wipes the accumulator and rebuilds only from supplied
     prices — symbols with no price feed do NOT carry forward stale
     unrealized values. *)
  let portfolio = create ~accounting_method ~initial_cash:10_000.0 () in
  let portfolio =
    apply_trades_exn portfolio
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell
          ~quantity:100.0 ~price:50.0 ();
        make_trade ~id:"t2" ~order_id:"o2" ~symbol:"MSFT" ~side:Sell
          ~quantity:50.0 ~price:100.0 ();
      ]
      ~error_msg:"Shorts should succeed"
  in
  let portfolio =
    mark_to_market portfolio [ ("AAPL", 60.0); ("MSFT", 110.0) ]
  in
  (* Now mark only AAPL — MSFT should be dropped. *)
  let portfolio = mark_to_market portfolio [ ("AAPL", 70.0) ] in
  assert_that portfolio.unrealized_pnl_per_position
    (elements_are [ equal_to (("AAPL", -2000.0) : string * float) ])

let test_positive_unrealized_pnl_does_not_inflate_floor _ accounting_method =
  (* Profitable shorts reduce neither the floor nor (importantly) inflate
     it. The drag term clamps positive PnL to 0. *)
  let portfolio = create ~accounting_method ~initial_cash:1_000.0 () in
  let portfolio =
    apply_trades_exn portfolio
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell
          ~quantity:100.0 ~price:50.0 ();
      ]
      ~error_msg:"Short should succeed"
  in
  (* Mark AAPL @ $40 → short profitable, unrealized = +1000. *)
  let portfolio = mark_to_market portfolio [ ("AAPL", 40.0) ] in
  (* Try to spend more than cash; profitable unrealized P&L MUST NOT
     extend the floor. Cash is 6000 (1000 + 5000 from short).
     Buy MSFT at 100*60 = 6500 → cash_change -6500.
     Effective = 6000 - 6500 + 0 = -500 < 0 → ERROR. *)
  let oversized_buy =
    make_trade ~id:"t2" ~order_id:"o2" ~symbol:"MSFT" ~side:Buy ~quantity:100.0
      ~price:65.0 ()
  in
  assert_that (apply_single_trade portfolio oversized_buy) is_error

(* ========================================================================== *)
(* Test suite organization                                                   *)
(* ========================================================================== *)

(* Helper to create parameterized tests for both accounting methods *)
let make_parameterized_tests test_name test_fn =
  [
    (test_name ^ "_average_cost" >:: fun ctx -> test_fn ctx AverageCost);
    (test_name ^ "_fifo" >:: fun ctx -> test_fn ctx FIFO);
  ]

let suite =
  "Portfolio"
  >::: List.concat
         [
           (* Parameterized tests - run for both accounting methods *)
           make_parameterized_tests "create_portfolio" test_create_portfolio;
           make_parameterized_tests "apply_buy_trade" test_apply_buy_trade;
           make_parameterized_tests "apply_sell_trade" test_apply_sell_trade;
           make_parameterized_tests "insufficient_cash" test_insufficient_cash;
           make_parameterized_tests "short_selling_allowed"
             test_short_selling_allowed;
           make_parameterized_tests "position_close" test_position_close;
           make_parameterized_tests "validation" test_validation;
           make_parameterized_tests "multiple_trades_batch"
             test_multiple_trades_batch;
           make_parameterized_tests "short_selling" test_short_selling;
           make_parameterized_tests "short_cover" test_short_cover;
           make_parameterized_tests "short_to_long" test_short_to_long;
           make_parameterized_tests "commission_in_cost_basis"
             test_commission_in_cost_basis;
           make_parameterized_tests "complete_offset_and_reversal"
             test_complete_offset_and_reversal;
           make_parameterized_tests "realized_pnl_calculation"
             test_realized_pnl_calculation;
           (* Soft cash-floor on shorts (G3) *)
           make_parameterized_tests "short_entry_against_sufficient_cash"
             test_short_entry_against_sufficient_cash;
           make_parameterized_tests "short_cover_within_budget_succeeds"
             test_short_cover_within_budget_succeeds;
           make_parameterized_tests
             "short_entry_rejected_when_unrealized_drag_exceeds_cash"
             test_short_entry_rejected_when_unrealized_drag_exceeds_cash;
           make_parameterized_tests "sequence_of_shorts_hits_cumulative_floor"
             test_sequence_of_shorts_hits_cumulative_floor;
           make_parameterized_tests
             "mark_to_market_drops_positions_without_price"
             test_mark_to_market_drops_positions_without_price;
           make_parameterized_tests
             "positive_unrealized_pnl_does_not_inflate_floor"
             test_positive_unrealized_pnl_does_not_inflate_floor;
           (* FIFO-specific tests - only run for FIFO *)
           [
             "fifo_basic_buy_sell" >:: test_fifo_basic_buy_sell;
             "fifo_sell_matches_oldest" >:: test_fifo_sell_matches_oldest;
             "fifo_partial_lot_consumption"
             >:: test_fifo_partial_lot_consumption;
             "fifo_vs_average_cost" >:: test_fifo_vs_average_cost;
             "fifo_multiple_partial_sells" >:: test_fifo_multiple_partial_sells;
           ];
         ]

let () = run_test_tt_main suite
