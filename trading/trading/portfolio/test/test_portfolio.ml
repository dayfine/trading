open Core
open OUnit2
open Trading_base.Types
open Trading_portfolio.Types
open Trading_portfolio.Portfolio
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

  assert_ok_with ~msg:"Buy trade failed" (apply_trades portfolio [ buy_trade ])
    ~f:(fun updated_portfolio ->
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
            ~msg:"Position average cost (no commission)"
      | None -> assert_failure "Position should exist after buy trade")

let test_apply_sell_trade _ =
  let portfolio = create ~initial_cash:20000.0 in

  (* First buy some shares *)
  let buy_trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:150.0 ()
  in
  let portfolio =
    apply_trades_exn portfolio [ buy_trade ] ~error_msg:"Buy should succeed"
  in

  (* Then sell some shares at a higher price *)
  let sell_trade =
    make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Sell ~quantity:50.0
      ~price:160.0 ()
  in

  assert_ok_with ~msg:"Sell trade failed"
    (apply_trades portfolio [ sell_trade ]) ~f:(fun updated_portfolio ->
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

let test_insufficient_cash _ =
  let portfolio = create ~initial_cash:1000.0 in
  let expensive_trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:150.0 ()
  in

  assert_error ~msg:"Should fail due to insufficient cash"
    (apply_trades portfolio [ expensive_trade ])

let test_short_selling_allowed _ =
  let portfolio = create ~initial_cash:10000.0 in
  let sell_trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell ~quantity:100.0
      ~price:150.0 ()
  in

  assert_ok_with ~msg:"Short selling should be allowed"
    (apply_trades portfolio [ sell_trade ]) ~f:(fun updated_portfolio ->
      (* Short selling should be allowed and create negative position *)
      match get_position updated_portfolio "AAPL" with
      | Some position ->
          assert_float_equal (-100.0) position.quantity
            ~msg:"Short position created"
      | None -> assert_failure "Short position should exist")

let test_position_close _ =
  let portfolio = create ~initial_cash:20000.0 in

  (* Buy shares *)
  let buy_trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:150.0 ()
  in
  let portfolio =
    apply_trades_exn portfolio [ buy_trade ] ~error_msg:"Buy should succeed"
  in

  (* Sell all shares *)
  let sell_trade =
    make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Sell ~quantity:100.0
      ~price:160.0 ()
  in

  assert_ok_with ~msg:"Close position failed"
    (apply_trades portfolio [ sell_trade ]) ~f:(fun updated_portfolio ->
      (* Position should be closed (removed) *)
      assert_equal None
        (get_position updated_portfolio "AAPL")
        ~msg:"Position should be closed";
      assert_equal []
        (list_positions updated_portfolio)
        ~msg:"No positions remaining")

let test_validation _ =
  let portfolio = create ~initial_cash:20000.0 in
  let trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:150.0 ()
  in

  assert_ok_with ~msg:"Trade application failed"
    (apply_trades portfolio [ trade ]) ~f:(fun updated_portfolio ->
      assert_ok_with ~msg:"Validation failed" (validate updated_portfolio)
        ~f:(fun () -> () (* Expected - portfolio should be consistent *)))

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

  assert_ok_with ~msg:"Batch trades failed" (apply_trades portfolio trades)
    ~f:(fun updated_portfolio ->
      assert_equal 2
        (List.length (list_positions updated_portfolio))
        ~msg:"Two positions created";
      assert_equal 2
        (List.length (get_trade_history updated_portfolio))
        ~msg:"Two trades in history";
      (* Cash: 30000 - (100*150) - (50*200) = 30000 - 15000 - 10000 = 5000 *)
      assert_float_equal 5000.0
        (get_cash updated_portfolio)
        ~msg:"Cash after both trades")

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

  (* Short sell 100 shares at $150 with $5 commission *)
  let short_trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell ~quantity:100.0
      ~price:150.0 ~commission:5.0 ()
  in
  let portfolio =
    match apply_trades portfolio [ short_trade ] with
    | Ok p -> p
    | Error _ -> assert_failure "Short sell should succeed"
  in

  (* Verify short position cost basis includes commission *)
  (match get_position portfolio "AAPL" with
  | Some position ->
      (* Cost basis for short: $150 - $5/100 = $149.95 *)
      assert_float_equal 149.95 position.avg_cost
        ~msg:"Short cost basis should include commission ($150 - $5/100)"
  | None -> assert_failure "Short position should exist");

  (* Buy to cover 50 shares at $140 with $3 commission *)
  let cover_trade =
    make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Buy ~quantity:50.0
      ~price:140.0 ~commission:3.0 ()
  in

  match apply_trades portfolio [ cover_trade ] with
  | Ok updated_portfolio -> (
      (* Cash: 10000 + (15000 - 5) - (7000 + 3) = 10000 + 14995 - 7003 = 17992 *)
      assert_float_equal 17992.0
        (get_cash updated_portfolio)
        ~msg:"Cash after partial cover (with commissions)";

      (* Verify realized P&L: covering 50 shares
         P&L = 50 * ($149.95 - $140) - $3 = 50 * $9.95 - $3 = $497.50 - $3 = $494.50 *)
      let history = get_trade_history updated_portfolio in
      let cover_pnl = (List.nth_exn history 1).realized_pnl in
      assert_float_equal 494.5 cover_pnl ~msg:"Cover P&L should be $494.50";

      (* Position should be -50 shares *)
      match get_position updated_portfolio "AAPL" with
      | Some position ->
          assert_float_equal (-50.0) position.quantity
            ~msg:"Remaining short position";
          assert_float_equal 149.95 position.avg_cost
            ~msg:"Avg cost should remain $149.95 on partial cover"
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

let test_commission_in_cost_basis _ =
  let portfolio = create ~initial_cash:20000.0 in

  (* Buy 100 shares at $100 with $10 commission *)
  let buy_trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:100.0 ~commission:10.0 ()
  in

  match apply_trades portfolio [ buy_trade ] with
  | Ok updated_portfolio -> (
      (* Cost basis should be $100.10 per share ($100 + $10/100) *)
      match get_position updated_portfolio "AAPL" with
      | Some position ->
          assert_float_equal 100.0 position.quantity ~msg:"Position quantity";
          assert_float_equal 100.10 position.avg_cost
            ~msg:
              "Cost basis should include commission ($100 + $10/100 = $100.10)"
      | None -> assert_failure "Position should exist after buy trade")
  | Error err -> assert_failure ("Commission test failed: " ^ Status.show err)

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
         Buy 100 @ $150 + $5 commission: cost basis = $150.05/share, P&L = 0 (opening position)
         Sell 50 @ $160 - $3 commission: P&L = 50 * ($160 - $150.05) - $3 = $494.50
         Sell 50 @ $155 - $2 commission: P&L = 50 * ($155 - $150.05) - $2 = $245.50
         Total: $0 + $494.50 + $245.50 = $740 *)
      let trade_history = get_trade_history updated_portfolio in
      assert_equal 3 (List.length trade_history) ~msg:"Should have 3 trades";

      let trade1 = List.nth_exn trade_history 0 in
      let trade2 = List.nth_exn trade_history 1 in
      let trade3 = List.nth_exn trade_history 2 in

      assert_float_equal 0.0 trade1.realized_pnl
        ~msg:"Buy trade should have no realized P&L";
      assert_float_equal 494.5 trade2.realized_pnl
        ~msg:
          "First sell P&L should be $494.50 (commission included in cost basis)";
      assert_float_equal 245.5 trade3.realized_pnl
        ~msg:
          "Second sell P&L should be $245.50 (commission included in cost \
           basis)";

      let total_pnl = get_total_realized_pnl updated_portfolio in
      assert_float_equal 740.0 total_pnl
        ~msg:"Total realized P&L should be $740 (buy commission reduces P&L)";

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
         "commission_in_cost_basis" >:: test_commission_in_cost_basis;
         "realized_pnl_calculation" >:: test_realized_pnl_calculation;
       ]

let () = run_test_tt_main suite
