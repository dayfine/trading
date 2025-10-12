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

let test_insufficient_position _ =
  let portfolio = create ~initial_cash:10000.0 in
  let sell_trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell ~quantity:100.0
      ~price:150.0 ()
  in

  match apply_trades portfolio [ sell_trade ] with
  | Ok _ -> assert_failure "Should fail due to insufficient position"
  | Error _err -> () (* Expected behavior *)

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

let suite =
  "Portfolio"
  >::: [
         "create_portfolio" >:: test_create_portfolio;
         "apply_buy_trade" >:: test_apply_buy_trade;
         "apply_sell_trade" >:: test_apply_sell_trade;
         "insufficient_cash" >:: test_insufficient_cash;
         "insufficient_position" >:: test_insufficient_position;
         "position_close" >:: test_position_close;
         "validation" >:: test_validation;
         "multiple_trades_batch" >:: test_multiple_trades_batch;
       ]

let () = run_test_tt_main suite
