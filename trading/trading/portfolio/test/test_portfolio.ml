open Core
open OUnit2
open Trading_base.Types
open Trading_portfolio.Types
open Trading_portfolio.Portfolio

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

let test_create_portfolio _ =
  let portfolio = create ~initial_cash:10000.0 in
  assert_float_equal 10000.0 (get_cash portfolio) ~msg:"Initial cash";
  assert_float_equal 10000.0
    (get_initial_cash portfolio)
    ~msg:"Initial cash preserved";
  assert_equal [] (get_trade_history portfolio) ~msg:"Empty trade history";
  assert_equal [] (list_positions portfolio) ~msg:"No positions initially"

let test_apply_buy_trade _ =
  let portfolio = create ~initial_cash:20000.0 in
  let buy_trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:150.0 ()
  in

  match apply_trades portfolio [ buy_trade ] with
  | Ok updated_portfolio -> (
      (* Cash should be reduced by 100 * 150 = 15000 *)
      assert_float_equal 5000.0
        (get_cash updated_portfolio)
        ~msg:"Cash reduced after buy";

      (* Trade should be in history *)
      assert_equal 1
        (List.length (get_trade_history updated_portfolio))
        ~msg:"Trade in history";

      (* Position should be created *)
      match get_position updated_portfolio "AAPL" with
      | Some position ->
          assert_float_equal 100.0 position.quantity ~msg:"Position quantity";
          assert_float_equal 150.0 position.avg_cost
            ~msg:"Position average cost"
      | None -> assert_failure "Position should exist after buy trade")
  | Error err -> assert_failure ("Buy trade failed: " ^ Status.show err)

let test_apply_sell_trade _ =
  let portfolio = create ~initial_cash:20000.0 in

  (* First buy some shares *)
  let buy_trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:150.0 ()
  in
  let portfolio =
    match apply_trades portfolio [ buy_trade ] with
    | Ok p -> p
    | Error _ -> assert_failure "Buy should succeed"
  in

  (* Then sell some shares at a higher price *)
  let sell_trade =
    make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Sell ~quantity:50.0
      ~price:160.0 ()
  in

  match apply_trades portfolio [ sell_trade ] with
  | Ok updated_portfolio -> (
      (* Cash: 20000 - 15000 + 8000 = 13000 *)
      assert_float_equal 13000.0
        (get_cash updated_portfolio)
        ~msg:"Cash updated after sell";

      (* Position should be reduced *)
      match get_position updated_portfolio "AAPL" with
      | Some position ->
          assert_float_equal 50.0 position.quantity
            ~msg:"Reduced position quantity"
      | None -> assert_failure "Position should still exist after partial sell")
  | Error err -> assert_failure ("Sell trade failed: " ^ Status.show err)

let test_insufficient_cash _ =
  let portfolio = create ~initial_cash:1000.0 in
  let expensive_trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:150.0 ()
  in

  match apply_trades portfolio [ expensive_trade ] with
  | Ok _ -> assert_failure "Should fail due to insufficient cash"
  | Error _err -> () (* Expected behavior *)

let test_short_selling_allowed _ =
  let portfolio = create ~initial_cash:10000.0 in
  let sell_trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell ~quantity:100.0
      ~price:150.0 ()
  in

  match apply_trades portfolio [ sell_trade ] with
  | Ok updated_portfolio -> (
      (* Short selling should be allowed and create negative position *)
      match get_position updated_portfolio "AAPL" with
      | Some position ->
          assert_float_equal (-100.0) position.quantity
            ~msg:"Short position created"
      | None -> assert_failure "Short position should exist")
  | Error err ->
      assert_failure ("Short selling should be allowed: " ^ Status.show err)

let test_position_close _ =
  let portfolio = create ~initial_cash:20000.0 in

  (* Buy shares *)
  let buy_trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:150.0 ()
  in
  let portfolio =
    match apply_trades portfolio [ buy_trade ] with
    | Ok p -> p
    | Error _ -> assert_failure "Buy should succeed"
  in

  (* Sell all shares *)
  let sell_trade =
    make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Sell ~quantity:100.0
      ~price:160.0 ()
  in

  match apply_trades portfolio [ sell_trade ] with
  | Ok updated_portfolio ->
      (* Position should be closed (removed) *)
      assert_equal None
        (get_position updated_portfolio "AAPL")
        ~msg:"Position should be closed";
      assert_equal []
        (list_positions updated_portfolio)
        ~msg:"No positions remaining"
  | Error err -> assert_failure ("Close position failed: " ^ Status.show err)

let test_validation _ =
  let portfolio = create ~initial_cash:20000.0 in
  let trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:150.0 ()
  in

  match apply_trades portfolio [ trade ] with
  | Ok updated_portfolio -> (
      match validate updated_portfolio with
      | Ok () -> () (* Expected - portfolio should be consistent *)
      | Error err -> assert_failure ("Validation failed: " ^ Status.show err))
  | Error err -> assert_failure ("Trade application failed: " ^ Status.show err)

let test_multiple_trades_batch _ =
  let portfolio = create ~initial_cash:30000.0 in
  let trades =
    [
      make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy
        ~quantity:100.0 ~price:150.0 ();
      make_trade ~id:"t2" ~order_id:"o2" ~symbol:"MSFT" ~side:Buy ~quantity:50.0
        ~price:200.0 ();
    ]
  in

  match apply_trades portfolio trades with
  | Ok updated_portfolio ->
      assert_equal 2
        (List.length (list_positions updated_portfolio))
        ~msg:"Two positions created";
      assert_equal 2
        (List.length (get_trade_history updated_portfolio))
        ~msg:"Two trades in history";
      (* Cash: 30000 - (100*150) - (50*200) = 30000 - 15000 - 10000 = 5000 *)
      assert_float_equal 5000.0
        (get_cash updated_portfolio)
        ~msg:"Cash after both trades"
  | Error err -> assert_failure ("Batch trades failed: " ^ Status.show err)

let test_short_selling _ =
  let portfolio = create ~initial_cash:10000.0 in

  (* Short sell 100 shares at $150 *)
  let short_trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell ~quantity:100.0
      ~price:150.0 ()
  in

  match apply_trades portfolio [ short_trade ] with
  | Ok updated_portfolio -> (
      (* Cash should increase by 100 * 150 = 15000 *)
      assert_float_equal 25000.0
        (get_cash updated_portfolio)
        ~msg:"Cash increased after short sell";

      (* Position should be negative *)
      match get_position updated_portfolio "AAPL" with
      | Some position ->
          assert_float_equal (-100.0) position.quantity
            ~msg:"Short position quantity";
          assert_float_equal 150.0 position.avg_cost ~msg:"Short position cost"
      | None -> assert_failure "Short position should exist")
  | Error err -> assert_failure ("Short sell failed: " ^ Status.show err)

let test_short_cover _ =
  let portfolio = create ~initial_cash:10000.0 in

  (* Short sell 100 shares at $150 *)
  let short_trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell ~quantity:100.0
      ~price:150.0 ()
  in
  let portfolio =
    match apply_trades portfolio [ short_trade ] with
    | Ok p -> p
    | Error _ -> assert_failure "Short sell should succeed"
  in

  (* Buy to cover 50 shares at $140 *)
  let cover_trade =
    make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Buy ~quantity:50.0
      ~price:140.0 ()
  in

  match apply_trades portfolio [ cover_trade ] with
  | Ok updated_portfolio -> (
      (* Cash: 10000 + 15000 - 7000 = 18000 *)
      assert_float_equal 18000.0
        (get_cash updated_portfolio)
        ~msg:"Cash after partial cover";

      (* Position should be -50 shares *)
      match get_position updated_portfolio "AAPL" with
      | Some position ->
          assert_float_equal (-50.0) position.quantity
            ~msg:"Remaining short position";
          assert_float_equal 150.0 position.avg_cost
            ~msg:"Avg cost unchanged on cover"
      | None -> assert_failure "Remaining short position should exist")
  | Error err -> assert_failure ("Cover trade failed: " ^ Status.show err)

let test_short_to_long _ =
  let portfolio = create ~initial_cash:10000.0 in

  (* Short sell 50 shares at $150 *)
  let short_trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell ~quantity:50.0
      ~price:150.0 ()
  in
  let portfolio =
    match apply_trades portfolio [ short_trade ] with
    | Ok p -> p
    | Error _ -> assert_failure "Short sell should succeed"
  in

  (* Buy 100 shares at $140 to go long *)
  let buy_trade =
    make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:140.0 ()
  in

  match apply_trades portfolio [ buy_trade ] with
  | Ok updated_portfolio -> (
      (* Cash: 10000 + 7500 - 14000 = 3500 *)
      assert_float_equal 3500.0
        (get_cash updated_portfolio)
        ~msg:"Cash after going long";

      (* Position should be +50 shares at new cost basis *)
      match get_position updated_portfolio "AAPL" with
      | Some position ->
          assert_float_equal 50.0 position.quantity
            ~msg:"Long position after flip";
          assert_float_equal 140.0 position.avg_cost
            ~msg:"New avg cost after direction change"
      | None -> assert_failure "Long position should exist after flip")
  | Error err -> assert_failure ("Short to long failed: " ^ Status.show err)

let test_realized_pnl_calculation _ =
  let portfolio = create ~initial_cash:20000.0 in
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

  match apply_trades portfolio trades with
  | Ok updated_portfolio ->
      (* Verify individual trade P&L:
         Buy 100 @ $150: P&L = 0 (opening position)
         Sell 50 @ $160: P&L = 50 * ($160 - $150) - $3 = $497
         Sell 50 @ $155: P&L = 50 * ($155 - $150) - $2 = $248
         Total: $0 + $497 + $248 = $745 *)
      let trade_history = get_trade_history updated_portfolio in
      assert_equal 3 (List.length trade_history) ~msg:"Should have 3 trades";

      let trade1 = List.nth_exn trade_history 0 in
      let trade2 = List.nth_exn trade_history 1 in
      let trade3 = List.nth_exn trade_history 2 in

      assert_float_equal 0.0 trade1.realized_pnl
        ~msg:"Buy trade should have no realized P&L";
      assert_float_equal 497.0 trade2.realized_pnl
        ~msg:"First sell should realize $497";
      assert_float_equal 248.0 trade3.realized_pnl
        ~msg:"Second sell should realize $248";

      assert_float_equal 745.0
        (get_total_realized_pnl updated_portfolio)
        ~msg:"Total realized P&L should be $745";

      (* Position should be closed *)
      assert_equal None
        (get_position updated_portfolio "AAPL")
        ~msg:"Position should be closed after selling all shares"
  | Error err -> assert_failure ("Realized P&L test failed: " ^ Status.show err)

let suite =
  "Portfolio"
  >::: [
         "create_portfolio" >:: test_create_portfolio;
         "apply_buy_trade" >:: test_apply_buy_trade;
         "apply_sell_trade" >:: test_apply_sell_trade;
         "insufficient_cash" >:: test_insufficient_cash;
         "short_selling_allowed" >:: test_short_selling_allowed;
         "position_close" >:: test_position_close;
         "validation" >:: test_validation;
         "multiple_trades_batch" >:: test_multiple_trades_batch;
         "short_selling" >:: test_short_selling;
         "short_cover" >:: test_short_cover;
         "short_to_long" >:: test_short_to_long;
         "realized_pnl_calculation" >:: test_realized_pnl_calculation;
       ]

let () = run_test_tt_main suite
