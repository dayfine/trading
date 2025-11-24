open Core
open OUnit2
open Trading_base.Types
open Trading_portfolio.Types
open Trading_portfolio.Portfolio
open Trading_portfolio.Calculations
open Matchers

(* Domain-specific helper using matchers library *)
let apply_trades_exn portfolio trades ~error_msg =
  assert_ok ~msg:error_msg (apply_trades portfolio trades)

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
  assert_float_equal 10000.0 (get_cash portfolio) ~msg:"Initial cash";
  assert_float_equal 10000.0
    (get_initial_cash portfolio)
    ~msg:"Initial cash preserved";
  assert_equal [] (get_trade_history portfolio) ~msg:"Empty trade history";
  assert_equal [] (list_positions portfolio) ~msg:"No positions initially"

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
         assert_float_equal 5000.0
           (get_cash updated_portfolio)
           ~msg:"Cash reduced after buy";

         (* Trade should be in history *)
         assert_equal 1
           (List.length (get_trade_history updated_portfolio))
           ~msg:"Trade in history";

         (* Position should be created *)
         assert_some_with ~msg:"Position should exist after buy trade"
           (get_position updated_portfolio "AAPL") ~f:(fun position ->
             assert_float_equal 100.0
               (position_quantity position)
               ~msg:"Position quantity";
             assert_float_equal 150.0
               (avg_cost_of_position position)
               ~msg:"Position average cost (no commission)")))

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
  assert_float_equal 13000.0 (get_cash portfolio) ~msg:"Cash updated after sell";

  (* Position should be reduced *)
  assert_some_with ~msg:"Position should still exist after partial sell"
    (get_position portfolio "AAPL") ~f:(fun position ->
      assert_float_equal 50.0
        (position_quantity position)
        ~msg:"Reduced position quantity")

let test_insufficient_cash _ accounting_method =
  let portfolio = create ~accounting_method ~initial_cash:1000.0 () in
  let expensive_trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:150.0 ()
  in

  assert_error ~msg:"Should fail due to insufficient cash"
    (apply_trades portfolio [ expensive_trade ])

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
         assert_some_with ~msg:"Short position should exist"
           (get_position updated_portfolio "AAPL") ~f:(fun position ->
             assert_float_equal (-100.0)
               (position_quantity position)
               ~msg:"Short position created")))

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
  assert_none ~msg:"Position should be closed" (get_position portfolio "AAPL");
  assert_equal [] (list_positions portfolio) ~msg:"No positions remaining"

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
           (List.length (list_positions updated_portfolio))
           ~msg:"Two positions created";
         assert_equal 2
           (List.length (get_trade_history updated_portfolio))
           ~msg:"Two trades in history";
         (* Cash: 30000 - (100*150) - (50*200) = 30000 - 15000 - 10000 = 5000 *)
         assert_float_equal 5000.0
           (get_cash updated_portfolio)
           ~msg:"Cash after both trades"))

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
      assert_float_equal 25000.0
        (get_cash updated_portfolio)
        ~msg:"Cash increased after short sell";

      (* Position should be negative *)
      assert_some_with ~msg:"Short position should exist"
        (get_position updated_portfolio "AAPL") ~f:(fun position ->
          assert_float_equal (-100.0)
            (position_quantity position)
            ~msg:"Short position quantity";
          assert_float_equal 150.0
            (avg_cost_of_position position)
            ~msg:"Short position cost")
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
  assert_float_equal 17992.0 (get_cash portfolio)
    ~msg:"Cash after partial cover (with commissions)";

  (* Verify realized P&L: covering 50 shares
     P&L = 50 * ($149.95 - $140) - $3 = 50 * $9.95 - $3 = $497.50 - $3 = $494.50 *)
  let history = get_trade_history portfolio in
  let cover_pnl = (List.nth_exn history 1).realized_pnl in
  assert_float_equal 494.5 cover_pnl ~msg:"Cover P&L should be $494.50";

  (* Position should be -50 shares *)
  assert_some_with ~msg:"Remaining short position should exist"
    (get_position portfolio "AAPL") ~f:(fun position ->
      assert_float_equal (-50.0)
        (position_quantity position)
        ~msg:"Remaining short position";
      assert_float_equal 149.95
        (avg_cost_of_position position)
        ~msg:"Avg cost should remain $149.95 on partial cover")

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
  assert_float_equal 3500.0 (get_cash portfolio) ~msg:"Cash after going long";

  (* Position should be +50 shares at new cost basis *)
  assert_some_with ~msg:"Long position should exist after flip"
    (get_position portfolio "AAPL") ~f:(fun position ->
      assert_float_equal 50.0
        (position_quantity position)
        ~msg:"Long position after flip";
      assert_float_equal 140.0
        (avg_cost_of_position position)
        ~msg:"New avg cost after direction change")

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
         assert_some_with ~msg:"Position should exist after buy trade"
           (get_position updated_portfolio "AAPL") ~f:(fun position ->
             assert_float_equal 100.0
               (position_quantity position)
               ~msg:"Position quantity";
             assert_float_equal 100.10
               (avg_cost_of_position position)
               ~msg:
                 "Cost basis should include commission ($100 + $10/100 = \
                  $100.10)")))

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
    assert_ok ~msg:"Realized P&L test failed" (apply_trades portfolio trades)
  in

  let trade_history = get_trade_history updated_portfolio in
  assert_equal 3 (List.length trade_history) ~msg:"Should have 3 trades";

  let trade1 = List.nth_exn trade_history 0 in
  let trade2 = List.nth_exn trade_history 1 in
  let trade3 = List.nth_exn trade_history 2 in

  assert_float_equal 0.0 trade1.realized_pnl
    ~msg:"Buy trade should have no realized P&L";

  (* Different P&L expectations based on accounting method *)
  (match accounting_method with
  | AverageCost ->
      (* AverageCost: Both sells use same avg cost of $150.05/share
         Sell 50 @ $160 - $3: P&L = 50 * ($160 - $150.05) - $3 = $494.50
         Sell 50 @ $155 - $2: P&L = 50 * ($155 - $150.05) - $2 = $245.50 *)
      assert_float_equal 494.5 trade2.realized_pnl
        ~msg:"AverageCost: First sell P&L";
      assert_float_equal 245.5 trade3.realized_pnl
        ~msg:"AverageCost: Second sell P&L"
  | FIFO ->
      (* FIFO: Sells consume lots in order (all from same lot in this case)
         Same as AverageCost since there's only one lot
         Sell 50 @ $160 - $3: P&L = 50 * ($160 - $150.05) - $3 = $494.50
         Sell 50 @ $155 - $2: P&L = 50 * ($155 - $150.05) - $2 = $245.50 *)
      assert_float_equal 494.5 trade2.realized_pnl ~msg:"FIFO: First sell P&L";
      assert_float_equal 245.5 trade3.realized_pnl ~msg:"FIFO: Second sell P&L");

  let total_pnl = get_total_realized_pnl updated_portfolio in
  assert_float_equal 740.0 total_pnl
    ~msg:"Total realized P&L should be $740 (buy commission reduces P&L)";

  (* Position should be closed *)
  assert_none ~msg:"Position should be closed after selling all shares"
    (get_position updated_portfolio "AAPL")

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
  assert_none ~msg:"Position should be closed after complete offset"
    (get_position portfolio "AAPL");

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
  assert_some_with ~msg:"Position should exist after reversal"
    (get_position portfolio "MSFT") ~f:(fun position ->
      assert_float_equal (-100.0)
        (position_quantity position)
        ~msg:"Position should be short 100 after reversal";
      assert_float_equal 210.0
        (avg_cost_of_position position)
        ~msg:"Short position cost basis";
      (* FIFO: Only 1 lot, AverageCost: Only 1 lot *)
      let expected_lot_count = 1 in
      assert_equal expected_lot_count
        (List.length position.lots)
        ~msg:"Should have 1 lot");

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
  assert_some_with ~msg:"Position should exist after short to long reversal"
    (get_position portfolio "TSLA") ~f:(fun position ->
      assert_float_equal 40.0
        (position_quantity position)
        ~msg:"Position should be long 40 after reversal";
      assert_float_equal 290.0
        (avg_cost_of_position position)
        ~msg:"Long position cost basis after reversal";
      (* FIFO: Only 1 lot, AverageCost: Only 1 lot *)
      let expected_lot_count = 1 in
      assert_equal expected_lot_count
        (List.length position.lots)
        ~msg:"Should have 1 lot")

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
  assert_some_with ~msg:"Position should exist" (get_position portfolio "AAPL")
    ~f:(fun position ->
      assert_equal 2 (List.length position.lots) ~msg:"Should have 2 lots";
      assert_float_equal 200.0
        (position_quantity position)
        ~msg:"Total quantity";

      (* Average cost should be (100*100 + 100*110) / 200 = 105 *)
      assert_float_equal 105.0
        (avg_cost_of_position position)
        ~msg:"Average cost")

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
  assert_some_with ~msg:"Position should still exist"
    (get_position portfolio "AAPL") ~f:(fun position ->
      assert_equal 1 (List.length position.lots) ~msg:"Should have 1 lot left";
      assert_float_equal 100.0
        (position_quantity position)
        ~msg:"Remaining quantity";

      (* Remaining lot should have cost basis of $110 per share *)
      assert_float_equal 110.0
        (avg_cost_of_position position)
        ~msg:"Remaining lot cost basis")

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
  assert_some_with ~msg:"Position should still exist"
    (get_position portfolio "AAPL") ~f:(fun position ->
      assert_equal 2
        (List.length position.lots)
        ~msg:"Should have 2 lots (partial + full)";
      assert_float_equal 150.0
        (position_quantity position)
        ~msg:"Remaining quantity";

      (* Average cost: (50*100 + 100*110) / 150 = 106.67 *)
      assert_float_equal 106.666666666667
        (avg_cost_of_position position)
        ~msg:"Average cost after partial sale")

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
      assert_float_equal fifo_qty avg_qty ~msg:"Same quantity";

      (* FIFO should have 1 lot, AverageCost should have 1 lot *)
      assert_equal 1 (List.length fifo.lots) ~msg:"FIFO lots count";
      assert_equal 1 (List.length avg.lots) ~msg:"AverageCost lots count";

      (* FIFO remaining cost should be $110 (second lot) *)
      assert_float_equal 110.0
        (avg_cost_of_position fifo)
        ~msg:"FIFO remaining cost";

      (* AverageCost remaining cost should be $105 (average of both) *)
      assert_float_equal 105.0 (avg_cost_of_position avg)
        ~msg:"AverageCost remaining cost";

      (* FIFO and AverageCost have different realized P&L *)
      (* FIFO: Sells lot bought @ $100, so P&L = 100*(120-100) = $2000 *)
      (* AverageCost: Avg cost = $105, so P&L = 100*(120-105) = $1500 *)
      let fifo_pnl = get_total_realized_pnl portfolio_fifo in
      let avg_pnl = get_total_realized_pnl portfolio_avg in
      assert_float_equal 2000.0 fifo_pnl
        ~msg:"FIFO realized P&L (sold oldest lot @ $100)";
      assert_float_equal 1500.0 avg_pnl
        ~msg:"AverageCost realized P&L (avg cost $105)";

      (* The key difference is in the REMAINING position cost basis *)
      (* FIFO keeps the $110 lot, AverageCost keeps avg of $105 *)
      let cost_diff =
        Float.abs (avg_cost_of_position fifo -. avg_cost_of_position avg)
      in
      assert_bool "Cost basis should differ" Float.(cost_diff > 0.01)
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
  assert_some_with ~msg:"Position should still exist"
    (get_position portfolio "AAPL") ~f:(fun position ->
      assert_equal 2 (List.length position.lots) ~msg:"Should have 2 lots";
      assert_float_equal 150.0
        (position_quantity position)
        ~msg:"Remaining quantity";

      (* Average cost: (50*110 + 100*120) / 150 = 116.67 *)
      assert_float_equal 116.666666666667
        (avg_cost_of_position position)
        ~msg:"Average cost after selling 150")

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
