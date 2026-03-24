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

let make_deps data_dir =
  create_deps ~symbols:[ "AAPL" ] ~data_dir
    ~strategy:(module Noop_strategy)
    ~commission:sample_config.commission ()

(* Helper to create expected step_result for comparison.
   portfolio_value defaults to the portfolio's current_cash if not specified,
   which is correct for portfolios with no positions. *)
let make_expected_step_result ~date ~portfolio ?portfolio_value ~trades
    ~orders_submitted () =
  let portfolio_value =
    Option.value portfolio_value
      ~default:portfolio.Trading_portfolio.Portfolio.current_cash
  in
  { date; portfolio; portfolio_value; trades; orders_submitted }

(* Custom matchers for step_outcome *)
let is_stepped f = function
  | Stepped (sim', result) -> f (sim', result)
  | Completed _ -> assert_failure "Expected Stepped, got Completed"

let is_completed f = function
  | Completed result -> f result
  | Stepped _ -> assert_failure "Expected Completed, got Stepped"

(* ==================== create tests ==================== *)

let test_create_returns_simulator _ =
  with_test_data "simulator_create"
    [ ("AAPL", sample_aapl_prices) ]
    ~f:(fun data_dir ->
      let deps = make_deps data_dir in
      let sim = Test_helpers.create_exn ~config:sample_config ~deps in
      let expected_portfolio =
        Trading_portfolio.Portfolio.create ~initial_cash:10000.0 ()
      in
      let expected_result =
        make_expected_step_result
          ~date:(date_of_string "2024-01-02")
          ~portfolio:expected_portfolio ~trades:[] ~orders_submitted:[] ()
      in
      assert_that (step sim)
        (is_ok_and_holds
           (is_stepped (fun (_, result) -> assert_equal expected_result result))))

let test_create_with_empty_symbols _ =
  with_test_data "simulator_empty_symbols" [] ~f:(fun data_dir ->
      let deps =
        create_deps ~symbols:[] ~data_dir
          ~strategy:(module Noop_strategy)
          ~commission:sample_config.commission ()
      in
      let sim = Test_helpers.create_exn ~config:sample_config ~deps in
      let expected_portfolio =
        Trading_portfolio.Portfolio.create ~initial_cash:10000.0 ()
      in
      let expected_result =
        make_expected_step_result
          ~date:(date_of_string "2024-01-02")
          ~portfolio:expected_portfolio ~trades:[] ~orders_submitted:[] ()
      in
      assert_that (step sim)
        (is_ok_and_holds
           (is_stepped (fun (_, result) -> assert_equal expected_result result))))

(* ==================== step tests ==================== *)

let test_step_executes_market_order _ =
  with_test_data "simulator_market_order"
    [ ("AAPL", sample_aapl_prices) ]
    ~f:(fun data_dir ->
      let deps = make_deps data_dir in
      let sim = Test_helpers.create_exn ~config:sample_config ~deps in
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
      Trading_orders.Manager.submit_orders deps.order_manager [ order ]
      |> ignore;
      (* Step should execute the market order *)
      let _, result = step_exn sim in
      (* Verify that trades were generated *)
      assert_that result.trades (size_is 1);
      (* Verify portfolio was updated with the trade:
         10000 initial - (10 shares * 150 open price) - 1.0 min commission *)
      let quantity = 10.0 in
      let open_price = 150.0 in
      let commission = 1.0 in
      let expected_cash = 10000.0 -. (quantity *. open_price) -. commission in
      assert_that result.portfolio.current_cash (float_equal expected_cash);
      (* Verify position was created for AAPL *)
      let position =
        Trading_portfolio.Portfolio.get_position result.portfolio "AAPL"
      in
      assert_that position
        (is_some_and (fun (pos : Trading_portfolio.Types.portfolio_position) ->
             assert_that pos.symbol (equal_to "AAPL"))))

let test_limit_order_executes_on_later_day _ =
  with_test_data "simulator_limit_order"
    [ ("AAPL", sample_aapl_prices) ]
    ~f:(fun data_dir ->
      let deps = make_deps data_dir in
      let sim = Test_helpers.create_exn ~config:sample_config ~deps in
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
        | Error err ->
            failwith ("Failed to create buy order: " ^ Status.show err)
      in
      Trading_orders.Manager.submit_orders deps.order_manager [ buy_order ]
      |> ignore;
      (* Execute the buy on day 1 *)
      let sim_after_buy, _ = step_exn sim in
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
        | Error err ->
            failwith ("Failed to create sell order: " ^ Status.show err)
      in
      Trading_orders.Manager.submit_orders deps.order_manager [ sell_order ]
      |> ignore;
      (* Step on day 2 - sell order should execute *)
      let _, result = step_exn sim_after_buy in
      (* Trade executed at limit price *)
      assert_that result.trades
        (elements_are
           [
             (fun trade ->
               assert_that trade.Trading_base.Types.price (float_equal 156.0));
           ]);
      (* Cash: started with 10000, bought 10@150 (-1501), sold 10@156 (+1559) *)
      let quantity = 10.0 in
      let buy_price = 150.0 in
      let sell_price = 156.0 in
      let commission = 1.0 in
      let expected_cash =
        10000.0 -. (quantity *. buy_price) -. commission
        +. (quantity *. sell_price) -. commission
      in
      assert_that result.portfolio.current_cash (float_equal expected_cash))

let test_stop_order_executes_on_later_day _ =
  with_test_data "simulator_stop_order"
    [ ("AAPL", sample_aapl_prices) ]
    ~f:(fun data_dir ->
      let deps = make_deps data_dir in
      let sim = Test_helpers.create_exn ~config:sample_config ~deps in
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
      Trading_orders.Manager.submit_orders deps.order_manager [ order ]
      |> ignore;
      (* Step 1 - order should remain pending *)
      let sim', result1 = step_exn sim in
      (* No trades on day 1 *)
      assert_that result1.trades is_empty;
      (* Cash unchanged *)
      assert_that result1.portfolio.current_cash (float_equal 10000.0);
      (* Step 2 - order should execute *)
      let _, result2 = step_exn sim' in
      (* Trade executed on day 2: stop triggers at 156.0, fills between stop
         and day high (158.0) *)
      assert_that result2.trades
        (elements_are
           [
             (fun trade ->
               assert_bool
                 (Printf.sprintf "Price %.2f should be in range [156.0, 158.0]"
                    trade.Trading_base.Types.price)
                 Float.(trade.price >= 156.0 && trade.price <= 158.0));
           ]))

let test_order_fails_due_to_insufficient_cash _ =
  with_test_data "simulator_insufficient_cash"
    [ ("AAPL", sample_aapl_prices) ]
    ~f:(fun data_dir ->
      let deps = make_deps data_dir in
      let sim = Test_helpers.create_exn ~config:sample_config ~deps in
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
      Trading_orders.Manager.submit_orders deps.order_manager [ order1; order2 ]
      |> ignore;
      (* Step - first order should execute, second should fail *)
      match step sim with
      | Error err ->
          (* Portfolio.apply_trades should return error for insufficient cash *)
          let err_msg = Status.show err in
          assert_bool
            (Printf.sprintf "Error should mention insufficient cash: %s" err_msg)
            (String.is_substring err_msg ~substring:"cash")
      | Ok (Completed _) -> assert_failure "Expected Stepped, got Completed"
      | Ok (Stepped (_, result)) ->
          (* Only first order (60 shares) should have executed *)
          assert_that result.trades
            (elements_are
               [
                 (fun trade ->
                   assert_that trade.Trading_base.Types.quantity
                     (float_equal 60.0));
               ]);
          (* Cash should reflect only the first trade:
             10000 initial - (60 shares * 150 open price) - 1.0 commission *)
          let quantity = 60.0 in
          let open_price = 150.0 in
          let commission = 1.0 in
          let expected_cash =
            10000.0 -. (quantity *. open_price) -. commission
          in
          assert_that result.portfolio.current_cash (float_equal expected_cash))

let test_step_advances_date _ =
  with_test_data "simulator_advances_date"
    [ ("AAPL", sample_aapl_prices) ]
    ~f:(fun data_dir ->
      let deps = make_deps data_dir in
      let sim = Test_helpers.create_exn ~config:sample_config ~deps in
      let expected_portfolio =
        Trading_portfolio.Portfolio.create ~initial_cash:10000.0 ()
      in
      let expected_result1 =
        make_expected_step_result
          ~date:(date_of_string "2024-01-02")
          ~portfolio:expected_portfolio ~trades:[] ~orders_submitted:[] ()
      in
      let expected_result2 =
        make_expected_step_result
          ~date:(date_of_string "2024-01-03")
          ~portfolio:expected_portfolio ~trades:[] ~orders_submitted:[] ()
      in
      assert_that (step sim)
        (is_ok_and_holds
           (is_stepped (fun (sim', result1) ->
                assert_equal expected_result1 result1;
                assert_that (step sim')
                  (is_ok_and_holds
                     (is_stepped (fun (_, result2) ->
                          assert_equal expected_result2 result2)))))))

let test_step_returns_completed_when_done _ =
  with_test_data "simulator_completed"
    [ ("AAPL", sample_aapl_prices) ]
    ~f:(fun data_dir ->
      let deps = make_deps data_dir in
      let config =
        {
          sample_config with
          start_date = date_of_string "2024-01-02";
          end_date = date_of_string "2024-01-03";
        }
      in
      let sim = Test_helpers.create_exn ~config ~deps in
      let expected_portfolio =
        Trading_portfolio.Portfolio.create ~initial_cash:10000.0 ()
      in
      (* First step advances from start_date to end_date *)
      assert_that (step sim)
        (is_ok_and_holds
           (is_stepped (fun (sim', _) ->
                (* Second step returns Completed *)
                assert_that (step sim')
                  (is_ok_and_holds
                     (is_completed (fun result ->
                          let final = (List.last_exn result.steps).portfolio in
                          assert_equal expected_portfolio final)))))))

(* ==================== run tests ==================== *)

let test_run_completes_simulation _ =
  with_test_data "simulator_run_completes"
    [ ("AAPL", sample_aapl_prices) ]
    ~f:(fun data_dir ->
      let deps = make_deps data_dir in
      let sim = Test_helpers.create_exn ~config:sample_config ~deps in
      let expected_portfolio =
        Trading_portfolio.Portfolio.create ~initial_cash:10000.0 ()
      in
      let expected_steps =
        [
          make_expected_step_result
            ~date:(date_of_string "2024-01-02")
            ~portfolio:expected_portfolio ~trades:[] ~orders_submitted:[] ();
          make_expected_step_result
            ~date:(date_of_string "2024-01-03")
            ~portfolio:expected_portfolio ~trades:[] ~orders_submitted:[] ();
          make_expected_step_result
            ~date:(date_of_string "2024-01-04")
            ~portfolio:expected_portfolio ~trades:[] ~orders_submitted:[] ();
        ]
      in
      assert_that (run sim)
        (is_ok_and_holds (fun result ->
             assert_equal expected_steps result.steps;
             let final = (List.last_exn result.steps).portfolio in
             assert_equal expected_portfolio final)))

let test_create_rejects_invalid_date_range _ =
  with_test_data "simulator_invalid_date_range"
    [ ("AAPL", sample_aapl_prices) ]
    ~f:(fun data_dir ->
      let deps = make_deps data_dir in
      (* end_date == start_date should fail *)
      let config_same =
        {
          sample_config with
          start_date = date_of_string "2024-01-02";
          end_date = date_of_string "2024-01-02";
        }
      in
      assert_that
        (create ~config:config_same ~deps)
        (is_error_with Invalid_argument ~msg:"end_date");
      (* end_date < start_date should fail *)
      let config_before =
        {
          sample_config with
          start_date = date_of_string "2024-01-05";
          end_date = date_of_string "2024-01-02";
        }
      in
      assert_that
        (create ~config:config_before ~deps)
        (is_error_with Invalid_argument ~msg:"end_date"))

(* ==================== position lifecycle tests ==================== *)

let make_enter_exit_deps data_dir =
  Enter_then_exit_strategy.reset ();
  create_deps ~symbols:[ "AAPL" ] ~data_dir
    ~strategy:(module Enter_then_exit_strategy)
    ~commission:sample_config.commission ()

let test_position_created_when_strategy_returns_create_entering _ =
  with_test_data "position_lifecycle_create"
    [ ("AAPL", sample_aapl_prices) ]
    ~f:(fun data_dir ->
      let deps = make_enter_exit_deps data_dir in
      let sim = Test_helpers.create_exn ~config:sample_config ~deps in
      (* Step 1: Strategy returns CreateEntering, order is submitted
         (but orders execute on the next step) *)
      let sim', result1 = step_exn sim in
      (* No trades yet - order was just submitted *)
      assert_that result1.trades is_empty;
      (* Verify entry order was submitted *)
      assert_that result1.orders_submitted
        (elements_are
           [
             (fun order ->
               assert_that order.Trading_orders.Types.symbol (equal_to "AAPL");
               assert_that order.side
                 (equal_to (Trading_base.Types.Buy : Trading_base.Types.side));
               assert_that order.quantity (float_equal 10.0));
           ]);
      (* Step 2: Entry order executes *)
      let _, result2 = step_exn sim' in
      (* Quantity 10.0 comes from Enter_then_exit_strategy.target_quantity *)
      assert_that result2.trades
        (elements_are
           [
             (fun trade ->
               assert_that trade.Trading_base.Types.symbol (equal_to "AAPL");
               assert_that trade.side
                 (equal_to (Trading_base.Types.Buy : Trading_base.Types.side));
               assert_that trade.quantity (float_equal 10.0));
           ]))

let test_position_moves_to_exiting_when_strategy_triggers_exit _ =
  with_test_data "position_lifecycle_exit"
    [ ("AAPL", sample_aapl_prices) ]
    ~f:(fun data_dir ->
      let deps = make_enter_exit_deps data_dir in
      let config =
        {
          sample_config with
          start_date = date_of_string "2024-01-02";
          end_date = date_of_string "2024-01-06";
        }
      in
      let sim = Test_helpers.create_exn ~config ~deps in
      (* Step 1: Strategy returns CreateEntering, entry order submitted *)
      let sim', result1 = step_exn sim in
      assert_that result1.orders_submitted (size_is 1);
      (* Step 2: Entry order fills, strategy returns TriggerExit, exit order
         submitted *)
      let sim'', result2 = step_exn sim' in
      assert_that result2.trades
        (elements_are
           [
             (fun trade ->
               assert_that trade.Trading_base.Types.side
                 (equal_to (Trading_base.Types.Buy : Trading_base.Types.side)));
           ]);
      (* Verify exit order was submitted *)
      assert_that result2.orders_submitted
        (elements_are
           [
             (fun order ->
               assert_that order.Trading_orders.Types.symbol (equal_to "AAPL");
               assert_that order.side
                 (equal_to (Trading_base.Types.Sell : Trading_base.Types.side)));
           ]);
      (* Step 3: Exit order fills *)
      let _, result3 = step_exn sim'' in
      (* Quantity 10.0 comes from Enter_then_exit_strategy.target_quantity *)
      assert_that result3.trades
        (elements_are
           [
             (fun trade ->
               assert_that trade.Trading_base.Types.symbol (equal_to "AAPL");
               assert_that trade.side
                 (equal_to (Trading_base.Types.Sell : Trading_base.Types.side));
               assert_that trade.quantity (float_equal 10.0));
           ]);
      (* No more orders after position closed *)
      assert_that result3.orders_submitted is_empty)

let test_full_position_lifecycle _ =
  with_test_data "position_lifecycle_full"
    [ ("AAPL", sample_aapl_prices) ]
    ~f:(fun data_dir ->
      let deps = make_enter_exit_deps data_dir in
      let config =
        {
          sample_config with
          start_date = date_of_string "2024-01-02";
          end_date = date_of_string "2024-01-05";
        }
      in
      let sim = Test_helpers.create_exn ~config ~deps in
      (* Run the full simulation.
         Order flow with strategy that enters on day 1, exits on day 2:
         - Step 1 (Jan 2): CreateEntering transition -> order submitted. No trades.
         - Step 2 (Jan 3): Entry order fills. TriggerExit transition -> exit order
           submitted. 1 trade (entry).
         - Step 3 (Jan 4): Exit order fills. 1 trade (exit). *)
      match run sim with
      | Error err -> failwith ("Run failed: " ^ Status.show err)
      | Ok result ->
          let steps = result.steps in
          let final_portfolio = (List.last_exn steps).portfolio in
          (* Verify step structure: 3 steps with expected trades *)
          assert_that steps
            (elements_are
               [
                 (* Step 1: No trades (order just submitted) *)
                 (fun step -> assert_that step.trades is_empty);
                 (* Step 2: Entry trade fills *)
                 (fun step ->
                   assert_that step.trades
                     (elements_are
                        [
                          (fun t ->
                            assert_that t.Trading_base.Types.side
                              (equal_to
                                 (Trading_base.Types.Buy
                                   : Trading_base.Types.side)));
                        ]));
                 (* Step 3: Exit trade fills *)
                 (fun step ->
                   assert_that step.trades
                     (elements_are
                        [
                          (fun t ->
                            assert_that t.Trading_base.Types.side
                              (equal_to
                                 (Trading_base.Types.Sell
                                   : Trading_base.Types.side)));
                        ]));
               ]);
          (* Verify final portfolio cash:
             initial - (quantity * entry_price) - commission + (quantity * exit_price) - commission *)
          let entry_trade = List.hd_exn (List.nth_exn steps 1).trades in
          let exit_trade = List.hd_exn (List.nth_exn steps 2).trades in
          let commission = 1.0 in
          let entry_cost = entry_trade.quantity *. entry_trade.price in
          let exit_proceeds = exit_trade.quantity *. exit_trade.price in
          let expected_cash =
            10000.0 -. entry_cost -. commission +. exit_proceeds -. commission
          in
          assert_that final_portfolio.current_cash (float_equal expected_cash))

(** Helper to create deps with Long_strategy *)
let make_long_strategy_deps data_dir =
  Long_strategy.reset ();
  create_deps ~symbols:[ "AAPL" ] ~data_dir
    ~strategy:(module Long_strategy)
    ~commission:sample_config.commission ()

(** Helper to create deps with Short_strategy *)
let make_short_strategy_deps data_dir =
  Short_strategy.reset ();
  create_deps ~symbols:[ "AAPL" ] ~data_dir
    ~strategy:(module Short_strategy)
    ~commission:sample_config.commission ()

let test_position_matched_by_state_not_side _ =
  (* This test verifies that trades are matched to positions by state
     (Entering/Exiting), not by side (Buy/Sell). This is important for
     supporting short positions where you sell to enter and buy to exit.

     See also: test_short_position_lifecycle for short position verification. *)
  with_test_data "position_matched_by_state"
    [ ("AAPL", sample_aapl_prices) ]
    ~f:(fun data_dir ->
      let deps = make_long_strategy_deps data_dir in
      let config =
        {
          sample_config with
          start_date = date_of_string "2024-01-02";
          end_date = date_of_string "2024-01-06";
        }
      in
      let sim = Test_helpers.create_exn ~config ~deps in
      (* Step 1: CreateEntering transition creates position in Entering state,
         order submitted for next step. *)
      let sim', result1 = step_exn sim in
      (* No trades yet - order just submitted *)
      assert_that result1.trades is_empty;
      (* Entry order submitted - for long position, this is a Buy *)
      assert_that result1.orders_submitted (size_is 1);
      (* Step 2: Entry order fills. Position moves to Holding via state matching
         (matched Entering state, not Buy side).
         TriggerExit transition moves position to Exiting state, exit order
         submitted. *)
      let sim'', result2 = step_exn sim' in
      (* Entry trade - matched by Entering state, not Buy side *)
      assert_that result2.trades
        (elements_are
           [
             (fun trade ->
               assert_that trade.Trading_base.Types.side
                 (equal_to (Trading_base.Types.Buy : Trading_base.Types.side)));
           ]);
      (* Exit order submitted - for long position, this is a Sell *)
      assert_that result2.orders_submitted (size_is 1);
      (* Step 3: Exit order fills. Position moves to Closed via state matching
         (matched Exiting state, not Sell side). *)
      let _, result3 = step_exn sim'' in
      (* Exit trade - matched by Exiting state, not Sell side *)
      assert_that result3.trades
        (elements_are
           [
             (fun trade ->
               assert_that trade.Trading_base.Types.side
                 (equal_to (Trading_base.Types.Sell : Trading_base.Types.side)));
           ]);
      (* No more orders after position closed *)
      assert_that result3.orders_submitted is_empty)

let test_short_position_lifecycle _ =
  (* Verify short position lifecycle: Sell to enter, Buy to exit.
     This is the counterpart to test_position_matched_by_state_not_side,
     verifying that order_generator correctly handles short positions. *)
  with_test_data "short_position_lifecycle"
    [ ("AAPL", sample_aapl_prices) ]
    ~f:(fun data_dir ->
      let deps = make_short_strategy_deps data_dir in
      let config =
        {
          sample_config with
          start_date = date_of_string "2024-01-02";
          end_date = date_of_string "2024-01-06";
        }
      in
      let sim = Test_helpers.create_exn ~config ~deps in
      (* Step 1: CreateEntering transition with Short side, order submitted *)
      let sim', result1 = step_exn sim in
      assert_that result1.trades is_empty;
      (* Entry order submitted - for short position, this is a Sell *)
      assert_that result1.orders_submitted (size_is 1);
      (* Step 2: Entry order fills. For short position, entry is Sell.
         Position moves to Holding, then TriggerExit moves to Exiting. *)
      let sim'', result2 = step_exn sim' in
      (* Entry trade - Sell order for short entry *)
      assert_that result2.trades
        (elements_are
           [
             (fun trade ->
               assert_that trade.Trading_base.Types.side
                 (equal_to (Trading_base.Types.Sell : Trading_base.Types.side)));
           ]);
      (* Exit order submitted - for short position, this is a Buy to cover *)
      assert_that result2.orders_submitted (size_is 1);
      (* Step 3: Exit order fills. For short position, exit is Buy. *)
      let _, result3 = step_exn sim'' in
      (* Exit trade - Buy order to cover short position *)
      assert_that result3.trades
        (elements_are
           [
             (fun trade ->
               assert_that trade.Trading_base.Types.side
                 (equal_to (Trading_base.Types.Buy : Trading_base.Types.side)));
           ]);
      assert_that result3.orders_submitted is_empty)

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
         "create rejects invalid date range"
         >:: test_create_rejects_invalid_date_range;
         (* Position lifecycle tests *)
         "position created when strategy returns CreateEntering"
         >:: test_position_created_when_strategy_returns_create_entering;
         "position moves to exiting when strategy triggers exit"
         >:: test_position_moves_to_exiting_when_strategy_triggers_exit;
         "full position lifecycle" >:: test_full_position_lifecycle;
         "position matched by state not side"
         >:: test_position_matched_by_state_not_side;
         "short position lifecycle" >:: test_short_position_lifecycle;
       ]

let () = run_test_tt_main suite
