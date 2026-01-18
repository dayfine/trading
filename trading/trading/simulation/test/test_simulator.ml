open OUnit2
open Core
open Trading_simulation.Simulator
open Matchers
open Test_helpers

let date_of_string s = Date.of_string s

let make_daily_price ~date ~open_price ~high ~low ~close ~volume =
  Types.Daily_price.
    {
      date;
      open_price;
      high_price = high;
      low_price = low;
      close_price = close;
      volume;
      adjusted_close = close;
    }

let sample_config =
  {
    start_date = date_of_string "2024-01-02";
    end_date = date_of_string "2024-01-05";
    initial_cash = 10000.0;
    commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 };
  }

let sample_aapl_prices =
  [
    make_daily_price
      ~date:(date_of_string "2024-01-02")
      ~open_price:150.0 ~high:155.0 ~low:149.0 ~close:154.0 ~volume:1000000;
    make_daily_price
      ~date:(date_of_string "2024-01-03")
      ~open_price:154.0 ~high:158.0 ~low:153.0 ~close:157.0 ~volume:1200000;
    make_daily_price
      ~date:(date_of_string "2024-01-04")
      ~open_price:157.0 ~high:160.0 ~low:155.0 ~close:159.0 ~volume:900000;
  ]

let make_sample_deps test_name =
  let data_dir =
    setup_test_data ("simulator_" ^ test_name) [ ("AAPL", sample_aapl_prices) ]
  in
  ( { symbols = [ "AAPL" ]; data_dir; strategy = (module Noop_strategy) },
    data_dir )

(* Helper to create expected step_result for comparison *)
let make_expected_step_result ~date ~portfolio ~trades =
  { date; portfolio; trades }

(* Custom matchers for step_outcome *)
let is_stepped f = function
  | Stepped (sim', result) -> f (sim', result)
  | Completed _ -> assert_failure "Expected Stepped, got Completed"

let is_completed f = function
  | Completed portfolio -> f portfolio
  | Stepped _ -> assert_failure "Expected Completed, got Stepped"

(* ==================== create tests ==================== *)

let test_create_returns_simulator _ =
  let deps, data_dir = make_sample_deps "create" in
  let sim = create ~config:sample_config ~deps in
  let expected_portfolio =
    Trading_portfolio.Portfolio.create ~initial_cash:10000.0 ()
  in
  let expected_result =
    make_expected_step_result
      ~date:(date_of_string "2024-01-02")
      ~portfolio:expected_portfolio ~trades:[]
  in
  assert_that (step sim)
    (is_ok_and_holds
       (is_stepped (fun (_, result) -> assert_equal expected_result result)));
  teardown_test_data data_dir

let test_create_with_empty_symbols _ =
  let data_dir = setup_test_data "simulator_empty_symbols" [] in
  let deps = { symbols = []; data_dir; strategy = (module Noop_strategy) } in
  let sim = create ~config:sample_config ~deps in
  let expected_portfolio =
    Trading_portfolio.Portfolio.create ~initial_cash:10000.0 ()
  in
  let expected_result =
    make_expected_step_result
      ~date:(date_of_string "2024-01-02")
      ~portfolio:expected_portfolio ~trades:[]
  in
  assert_that (step sim)
    (is_ok_and_holds
       (is_stepped (fun (_, result) -> assert_equal expected_result result)));
  teardown_test_data data_dir

(* ==================== step tests ==================== *)

let test_step_executes_market_order _ =
  let deps, data_dir = make_sample_deps "market_order" in
  let sim = create ~config:sample_config ~deps in
  (* Place a market order for AAPL *)
  let order_params =
    Trading_orders.Create_order.
      {
        symbol = "AAPL";
        side = Trading_base.Types.Buy;
        quantity = 10.0;
        order_type = Trading_base.Types.Market;
        time_in_force = Trading_orders.Types.GTC;
      }
  in
  let order =
    match Trading_orders.Create_order.create_order order_params with
    | Ok o -> o
    | Error err -> failwith ("Failed to create order: " ^ Status.show err)
  in
  submit_orders sim [ order ] |> ignore;
  (* Step should execute the market order *)
  (match step sim with
  | Error err -> failwith ("Step failed: " ^ Status.show err)
  | Ok (Completed _) -> assert_failure "Expected Stepped, got Completed"
  | Ok (Stepped (_, result)) ->
      (* Verify that trades were generated *)
      assert_that result.trades (size_is 1);
      (* Verify portfolio was updated with the trade *)
      let expected_cash = 10000.0 -. (10.0 *. 150.0) -. 1.0 in
      (* 150.0 is open price, 1.0 is commission *)
      assert_that result.portfolio.current_cash (float_equal expected_cash);
      (* Verify position was created for AAPL *)
      let position =
        Trading_portfolio.Portfolio.get_position result.portfolio "AAPL"
      in
      assert_that position
        (is_some_and (fun (pos : Trading_portfolio.Types.portfolio_position) ->
             assert_that pos.symbol (equal_to "AAPL"))));
  teardown_test_data data_dir

let test_limit_order_executes_on_later_day _ =
  let deps, data_dir = make_sample_deps "limit_order" in
  let sim = create ~config:sample_config ~deps in
  (* First, buy shares with a market order *)
  let buy_order_params =
    Trading_orders.Create_order.
      {
        symbol = "AAPL";
        side = Trading_base.Types.Buy;
        quantity = 10.0;
        order_type = Trading_base.Types.Market;
        time_in_force = Trading_orders.Types.GTC;
      }
  in
  let buy_order =
    match Trading_orders.Create_order.create_order buy_order_params with
    | Ok o -> o
    | Error err -> failwith ("Failed to create buy order: " ^ Status.show err)
  in
  submit_orders sim [ buy_order ] |> ignore;
  (* Execute the buy on day 1 *)
  let sim_after_buy =
    match step sim with
    | Error err -> failwith ("Buy step failed: " ^ Status.show err)
    | Ok (Completed _) -> failwith "Unexpected completion after buy"
    | Ok (Stepped (s, _)) -> s
  in
  (* Now place a sell limit order at 156.0
     Day 2 (2024-01-03): high=158.0 - should execute at 156.0 *)
  let sell_order_params =
    Trading_orders.Create_order.
      {
        symbol = "AAPL";
        side = Trading_base.Types.Sell;
        quantity = 10.0;
        order_type = Trading_base.Types.Limit 156.0;
        time_in_force = Trading_orders.Types.GTC;
      }
  in
  let sell_order =
    match Trading_orders.Create_order.create_order sell_order_params with
    | Ok o -> o
    | Error err -> failwith ("Failed to create sell order: " ^ Status.show err)
  in
  submit_orders sim_after_buy [ sell_order ] |> ignore;
  (* Step on day 2 - sell order should execute *)
  (match step sim_after_buy with
  | Error err -> failwith ("Sell step failed: " ^ Status.show err)
  | Ok (Completed _) -> assert_failure "Expected Stepped on day 2"
  | Ok (Stepped (_, result)) ->
      (* Trade executed *)
      assert_that result.trades (size_is 1);
      let trade = List.hd_exn result.trades in
      assert_that trade.price (float_equal 156.0);
      (* Cash: started with 10000, bought 10@150 (-1501), sold 10@156 (+1559) *)
      let expected_cash =
        10000.0 -. (10.0 *. 150.0) -. 1.0 +. (10.0 *. 156.0) -. 1.0
      in
      assert_that result.portfolio.current_cash (float_equal expected_cash));
  teardown_test_data data_dir

let test_stop_order_executes_on_later_day _ =
  let deps, data_dir = make_sample_deps "stop_order" in
  let sim = create ~config:sample_config ~deps in
  (* Place a buy stop order at 156.0
     Day 1 (2024-01-02): high=155.0 - won't trigger (price never reaches 156.0)
     Day 2 (2024-01-03): open=154.0, high=158.0 - should trigger and execute *)
  let order_params =
    Trading_orders.Create_order.
      {
        symbol = "AAPL";
        side = Trading_base.Types.Buy;
        quantity = 10.0;
        order_type = Trading_base.Types.Stop 156.0;
        time_in_force = Trading_orders.Types.GTC;
      }
  in
  let order =
    match Trading_orders.Create_order.create_order order_params with
    | Ok o -> o
    | Error err -> failwith ("Failed to create order: " ^ Status.show err)
  in
  submit_orders sim [ order ] |> ignore;
  (* Step 1 - order should remain pending *)
  (match step sim with
  | Error err -> failwith ("Step 1 failed: " ^ Status.show err)
  | Ok (Completed _) -> assert_failure "Expected Stepped on day 1"
  | Ok (Stepped (sim', result1)) -> (
      (* No trades on day 1 *)
      assert_that result1.trades (size_is 0);
      (* Cash unchanged *)
      assert_that result1.portfolio.current_cash (float_equal 10000.0);
      (* Step 2 - order should execute *)
      match step sim' with
      | Error err -> failwith ("Step 2 failed: " ^ Status.show err)
      | Ok (Completed _) -> assert_failure "Expected Stepped on day 2"
      | Ok (Stepped (_, result2)) ->
          (* Trade executed on day 2 *)
          assert_that result2.trades (size_is 1);
          let trade = List.hd_exn result2.trades in
          (* Stop triggers at 156.0, fills between stop and day high (158.0) *)
          assert_bool
            (Printf.sprintf "Price %.2f should be in range [156.0, 158.0]"
               trade.price)
            Float.(trade.price >= 156.0 && trade.price <= 158.0)));
  teardown_test_data data_dir

let test_order_fails_due_to_insufficient_cash _ =
  let deps, data_dir = make_sample_deps "insufficient_cash" in
  let sim = create ~config:sample_config ~deps in
  (* Place two market orders:
     1. Buy 60 shares at ~150.0 = 9000 + 1.0 commission = 9001
     2. Buy 10 shares at ~150.0 = 1500 + 1.0 commission = 1501
     Total needed: 10502, but we only have 10000
     First order should execute, second should fail *)
  let order1_params =
    Trading_orders.Create_order.
      {
        symbol = "AAPL";
        side = Trading_base.Types.Buy;
        quantity = 60.0;
        order_type = Trading_base.Types.Market;
        time_in_force = Trading_orders.Types.GTC;
      }
  in
  let order2_params =
    Trading_orders.Create_order.
      {
        symbol = "AAPL";
        side = Trading_base.Types.Buy;
        quantity = 10.0;
        order_type = Trading_base.Types.Market;
        time_in_force = Trading_orders.Types.GTC;
      }
  in
  let order1 =
    match Trading_orders.Create_order.create_order order1_params with
    | Ok o -> o
    | Error err -> failwith ("Failed to create order1: " ^ Status.show err)
  in
  let order2 =
    match Trading_orders.Create_order.create_order order2_params with
    | Ok o -> o
    | Error err -> failwith ("Failed to create order2: " ^ Status.show err)
  in
  submit_orders sim [ order1; order2 ] |> ignore;
  (* Step - first order should execute, second should fail *)
  (match step sim with
  | Error err ->
      (* Portfolio.apply_trades should return error for insufficient cash *)
      let err_msg = Status.show err in
      assert_bool
        (Printf.sprintf "Error should mention insufficient cash: %s" err_msg)
        (String.is_substring err_msg ~substring:"cash")
  | Ok (Completed _) -> assert_failure "Expected Stepped, got Completed"
  | Ok (Stepped (_, result)) ->
      (* Only one trade should have executed *)
      assert_that result.trades (size_is 1);
      let trade = List.hd_exn result.trades in
      assert_that trade.quantity (float_equal 60.0);
      (* Cash should reflect only the first trade *)
      let expected_cash = 10000.0 -. (60.0 *. 150.0) -. 1.0 in
      assert_that result.portfolio.current_cash (float_equal expected_cash));
  teardown_test_data data_dir

let test_step_advances_date _ =
  let deps, data_dir = make_sample_deps "advances_date" in
  let sim = create ~config:sample_config ~deps in
  let expected_portfolio =
    Trading_portfolio.Portfolio.create ~initial_cash:10000.0 ()
  in
  let expected_result1 =
    make_expected_step_result
      ~date:(date_of_string "2024-01-02")
      ~portfolio:expected_portfolio ~trades:[]
  in
  let expected_result2 =
    make_expected_step_result
      ~date:(date_of_string "2024-01-03")
      ~portfolio:expected_portfolio ~trades:[]
  in
  assert_that (step sim)
    (is_ok_and_holds
       (is_stepped (fun (sim', result1) ->
            assert_equal expected_result1 result1;
            assert_that (step sim')
              (is_ok_and_holds
                 (is_stepped (fun (_, result2) ->
                      assert_equal expected_result2 result2))))));
  teardown_test_data data_dir

let test_step_returns_completed_when_done _ =
  let deps, data_dir = make_sample_deps "completed" in
  let config =
    {
      sample_config with
      start_date = date_of_string "2024-01-02";
      end_date = date_of_string "2024-01-02";
    }
  in
  let sim = create ~config ~deps in
  let expected_portfolio =
    Trading_portfolio.Portfolio.create ~initial_cash:10000.0 ()
  in
  assert_that (step sim)
    (is_ok_and_holds
       (is_completed (fun portfolio ->
            assert_equal expected_portfolio portfolio)));
  teardown_test_data data_dir

(* ==================== run tests ==================== *)

let test_run_completes_simulation _ =
  let deps, data_dir = make_sample_deps "run_completes" in
  let sim = create ~config:sample_config ~deps in
  let expected_portfolio =
    Trading_portfolio.Portfolio.create ~initial_cash:10000.0 ()
  in
  let expected_steps =
    [
      make_expected_step_result
        ~date:(date_of_string "2024-01-02")
        ~portfolio:expected_portfolio ~trades:[];
      make_expected_step_result
        ~date:(date_of_string "2024-01-03")
        ~portfolio:expected_portfolio ~trades:[];
      make_expected_step_result
        ~date:(date_of_string "2024-01-04")
        ~portfolio:expected_portfolio ~trades:[];
    ]
  in
  assert_that (run sim)
    (is_ok_and_holds (fun (steps, final_portfolio) ->
         assert_equal expected_steps steps;
         assert_equal expected_portfolio final_portfolio));
  teardown_test_data data_dir

let test_run_on_already_complete _ =
  let deps, data_dir = make_sample_deps "run_already_complete" in
  let config =
    {
      sample_config with
      start_date = date_of_string "2024-01-02";
      end_date = date_of_string "2024-01-02";
    }
  in
  let sim = create ~config ~deps in
  let expected_portfolio =
    Trading_portfolio.Portfolio.create ~initial_cash:10000.0 ()
  in
  assert_that (run sim)
    (is_ok_and_holds (fun (steps, final_portfolio) ->
         assert_that steps (size_is 0);
         assert_equal expected_portfolio final_portfolio));
  teardown_test_data data_dir

(* ==================== Test Suite ==================== *)

let suite =
  "Simulator Tests"
  >::: [
         "create returns simulator" >:: test_create_returns_simulator;
         "create with empty symbols" >:: test_create_with_empty_symbols;
         "step executes market order" >:: test_step_executes_market_order;
         "limit order executes on later day"
         >:: test_limit_order_executes_on_later_day;
         "stop order executes on later day"
         >:: test_stop_order_executes_on_later_day;
         "order fails due to insufficient cash"
         >:: test_order_fails_due_to_insufficient_cash;
         "step advances date" >:: test_step_advances_date;
         "step returns Completed when done"
         >:: test_step_returns_completed_when_done;
         "run completes simulation" >:: test_run_completes_simulation;
         "run on already complete" >:: test_run_on_already_complete;
       ]

let () = run_test_tt_main suite
