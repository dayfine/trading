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

let test_fifo_basic_buy_sell _ =
  (* Create portfolio with FIFO accounting *)
  let portfolio = create ~accounting_method:FIFO ~initial_cash:30000.0 () in

  (* Buy 100 shares at $100 *)
  let buy1 =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:100.0 ()
  in
  let portfolio =
    apply_trades_exn portfolio [ buy1 ] ~error_msg:"First buy should succeed"
  in

  (* Buy another 100 shares at $110 *)
  let buy2 =
    make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:110.0 ()
  in
  let portfolio =
    apply_trades_exn portfolio [ buy2 ] ~error_msg:"Second buy should succeed"
  in

  (* Verify position has 2 lots *)
  match get_position portfolio "AAPL" with
  | Some position ->
      assert_equal 2 (List.length position.lots) ~msg:"Should have 2 lots";
      assert_float_equal 200.0 position.quantity ~msg:"Total quantity";

      (* Average cost should be (100*100 + 100*110) / 200 = 105 *)
      assert_float_equal 105.0 (avg_cost_of_position position)
        ~msg:"Average cost"
  | None -> assert_failure "Position should exist"

let test_fifo_sell_matches_oldest _ =
  (* Create portfolio with FIFO accounting *)
  let portfolio = create ~accounting_method:FIFO ~initial_cash:50000.0 () in

  (* Buy 100 shares at $100 on day 1 *)
  let buy1 =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:100.0 ()
  in
  (* Buy 100 shares at $110 on day 2 *)
  let buy2 =
    make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:110.0 ()
  in
  (* Sell 100 shares at $120 - should match against first lot (cost $100) *)
  let sell1 =
    make_trade ~id:"t3" ~order_id:"o3" ~symbol:"AAPL" ~side:Sell
      ~quantity:100.0 ~price:120.0 ()
  in

  let portfolio =
    apply_trades_exn portfolio [ buy1; buy2; sell1 ]
      ~error_msg:"Trades should succeed"
  in

  (* Should have 1 lot remaining (the second buy at $110) *)
  match get_position portfolio "AAPL" with
  | Some position ->
      assert_equal 1 (List.length position.lots) ~msg:"Should have 1 lot left";
      assert_float_equal 100.0 position.quantity ~msg:"Remaining quantity";

      (* Remaining lot should have cost basis of $110 per share *)
      assert_float_equal 110.0 (avg_cost_of_position position)
        ~msg:"Remaining lot cost basis"
  | None -> assert_failure "Position should still exist"

let test_fifo_partial_lot_consumption _ =
  (* Create portfolio with FIFO accounting *)
  let portfolio = create ~accounting_method:FIFO ~initial_cash:30000.0 () in

  (* Buy 100 shares at $100 *)
  let buy1 =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:100.0 ()
  in
  (* Buy 100 shares at $110 *)
  let buy2 =
    make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:110.0 ()
  in
  (* Sell 50 shares - should partially consume first lot *)
  let sell1 =
    make_trade ~id:"t3" ~order_id:"o3" ~symbol:"AAPL" ~side:Sell ~quantity:50.0
      ~price:120.0 ()
  in

  let portfolio =
    apply_trades_exn portfolio [ buy1; buy2; sell1 ]
      ~error_msg:"Trades should succeed"
  in

  (* Should have 2 lots: 50 shares at $100, 100 shares at $110 *)
  match get_position portfolio "AAPL" with
  | Some position ->
      assert_equal 2 (List.length position.lots)
        ~msg:"Should have 2 lots (partial + full)";
      assert_float_equal 150.0 position.quantity ~msg:"Remaining quantity";

      (* Average cost: (50*100 + 100*110) / 150 = 106.67 *)
      assert_float_equal 106.666666666667 (avg_cost_of_position position)
        ~msg:"Average cost after partial sale"
  | None -> assert_failure "Position should still exist"

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
      assert_float_equal fifo.quantity avg.quantity ~msg:"Same quantity";

      (* FIFO should have 1 lot, AverageCost should have 1 lot *)
      assert_equal 1 (List.length fifo.lots) ~msg:"FIFO lots count";
      assert_equal 1 (List.length avg.lots) ~msg:"AverageCost lots count";

      (* FIFO remaining cost should be $110 (second lot) *)
      assert_float_equal 110.0 (avg_cost_of_position fifo)
        ~msg:"FIFO remaining cost";

      (* AverageCost remaining cost should be $105 (average of both) *)
      assert_float_equal 105.0 (avg_cost_of_position avg)
        ~msg:"AverageCost remaining cost"
  | _ -> assert_failure "Both positions should exist"

let test_fifo_multiple_partial_sells _ =
  (* Create portfolio with FIFO accounting *)
  let portfolio = create ~accounting_method:FIFO ~initial_cash:50000.0 () in

  (* Buy 3 lots *)
  let buy1 =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:100.0 ()
  in
  let buy2 =
    make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:110.0 ()
  in
  let buy3 =
    make_trade ~id:"t3" ~order_id:"o3" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:120.0 ()
  in

  (* Sell 150 shares - should consume first lot fully and half of second lot *)
  let sell1 =
    make_trade ~id:"t4" ~order_id:"o4" ~symbol:"AAPL" ~side:Sell
      ~quantity:150.0 ~price:130.0 ()
  in

  let portfolio =
    apply_trades_exn portfolio [ buy1; buy2; buy3; sell1 ]
      ~error_msg:"Trades should succeed"
  in

  (* Should have 2 lots: 50 shares at $110, 100 shares at $120 *)
  match get_position portfolio "AAPL" with
  | Some position ->
      assert_equal 2 (List.length position.lots) ~msg:"Should have 2 lots";
      assert_float_equal 150.0 position.quantity ~msg:"Remaining quantity";

      (* Average cost: (50*110 + 100*120) / 150 = 116.67 *)
      assert_float_equal 116.666666666667 (avg_cost_of_position position)
        ~msg:"Average cost after selling 150"
  | None -> assert_failure "Position should still exist"

let suite =
  "FIFO Accounting"
  >::: [
         "basic_buy_sell" >:: test_fifo_basic_buy_sell;
         "sell_matches_oldest" >:: test_fifo_sell_matches_oldest;
         "partial_lot_consumption" >:: test_fifo_partial_lot_consumption;
         "fifo_vs_average_cost" >:: test_fifo_vs_average_cost;
         "multiple_partial_sells" >:: test_fifo_multiple_partial_sells;
       ]

let () = run_test_tt_main suite
