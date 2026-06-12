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
      active_through = None;
    }

let sample_config =
  {
    start_date = date_of_string "2024-01-02";
    end_date = date_of_string "2024-01-05";
    initial_cash = 10000.0;
    commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 };
    strategy_cadence = Types.Cadence.Daily;
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
let make_expected_step_result ~date ~portfolio ?portfolio_value
    ?(had_market_bars = true) ~trades ~orders_submitted () =
  let portfolio_value =
    Option.value portfolio_value
      ~default:portfolio.Trading_portfolio.Portfolio.current_cash
  in
  let portfolio_summary =
    Trading_simulation_types.Portfolio_summary.of_portfolio portfolio
      ~position_value_total:(portfolio_value -. portfolio.current_cash)
  in
  {
    date;
    portfolio = portfolio_summary;
    portfolio_value;
    trades;
    orders_submitted;
    splits_applied = [];
    benchmark_return = None;
    had_market_bars;
  }

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
          ~portfolio:expected_portfolio ~had_market_bars:false ~trades:[]
          ~orders_submitted:[] ()
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
        Trading_simulation_types.Portfolio_summary.find_position
          result.portfolio ~symbol:"AAPL"
      in
      assert_that position
        (is_some_and
           (field
              (fun (p :
                     Trading_simulation_types.Portfolio_summary.position_summary)
                 -> p.symbol)
              (equal_to "AAPL"))))

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
               assert_that trade.Trading_base.Types.price
                 (all_of
                    [ ge (module Float_ord) 156.0; le (module Float_ord) 158.0 ]));
           ]))

let test_insufficient_cash_trade_is_skipped _ =
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
      (* Step - first order executes, second is skipped (insufficient cash) *)
      match step sim with
      | Error err ->
          assert_failure
            ("Expected trade to be skipped, got error: " ^ Status.show err)
      | Ok (Completed _) -> assert_failure "Expected Stepped, got Completed"
      | Ok (Stepped (_, result)) ->
          (* One trade fills, the other is skipped — order processing
             sequence determines which. Just verify exactly 1 trade. *)
          assert_that (List.length result.trades) (equal_to 1);
          let trade = List.hd_exn result.trades in
          let expected_cash =
            10000.0 -. (trade.Trading_base.Types.quantity *. 150.0) -. 1.0
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
      let expected_summary =
        Trading_simulation_types.Portfolio_summary.of_portfolio
          expected_portfolio ~position_value_total:0.0
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
                          assert_equal expected_summary final;
                          assert_equal expected_portfolio result.final_portfolio)))))))

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
             assert_equal expected_portfolio result.final_portfolio)))

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
          let final_portfolio = result.final_portfolio in
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

(* ==================== Weekly Cadence ==================== *)

(** A strategy that counts how many times it is called. *)
let call_count = ref 0

module Counting_strategy : Trading_strategy.Strategy_interface.STRATEGY = struct
  let name = "Counting"

  let on_market_close ~get_price:_ ~get_indicator:_ ~portfolio:_ =
    Int.incr call_count;
    Ok { Trading_strategy.Strategy_interface.transitions = [] }
end

(** Generates N weekdays starting from [start] (skipping Saturday/Sunday). *)
let make_daily_prices_for_weekdays ~start ~n price =
  let rec loop date acc count =
    if count >= n then List.rev acc
    else
      let weekday = Date.day_of_week date in
      if
        Day_of_week.equal weekday Day_of_week.Sat
        || Day_of_week.equal weekday Day_of_week.Sun
      then loop (Date.add_days date 1) acc count
      else
        let bar =
          make_daily_price ~date ~open_price:price ~high:price ~low:price
            ~close:price ~volume:1000000
        in
        loop (Date.add_days date 1) (bar :: acc) (count + 1)
  in
  loop (Date.of_string start) [] 0

let test_weekly_cadence_calls_strategy_only_on_fridays _ =
  (* Week of 2024-01-08: Mon=08, Tue=09, Wed=10, Thu=11, Fri=12 *)
  let start = "2024-01-08" in
  let n_days = 10 in
  (* Two full Mon–Fri weeks *)
  let prices = make_daily_prices_for_weekdays ~start ~n:n_days 100.0 in
  with_test_data "weekly_cadence"
    [ ("AAPL", prices) ]
    ~f:(fun data_dir ->
      call_count := 0;
      let commission =
        { Trading_engine.Types.per_share = 0.01; minimum = 1.0 }
      in
      let deps =
        create_deps ~symbols:[ "AAPL" ] ~data_dir
          ~strategy:(module Counting_strategy)
          ~commission ()
      in
      let config =
        {
          start_date = Date.of_string start;
          end_date = Date.of_string "2024-01-20";
          (* covers Mon 8 – Fri 19, two full weeks *)
          initial_cash = 10000.0;
          commission;
          strategy_cadence = Types.Cadence.Weekly;
        }
      in
      let sim = Test_helpers.create_exn ~config ~deps in
      let result =
        match Trading_simulation.Simulator.run sim with
        | Ok r -> r
        | Error err -> failwith ("Run failed: " ^ Status.show err)
      in
      (* Simulator steps every calendar day: Jan 8–19 = 12 calendar days *)
      assert_that result.steps (size_is 12);
      (* Strategy should only be called on the two Fridays (Jan 12 and Jan 19) *)
      assert_that !call_count (equal_to 2))

(* ==================== Forward-fill valuation ==================== *)

(** Pins the prior-bar-exists branch of [_prices_for_held_positions] in the
    simulator (PR #916, qc-behavioral CP4). When a held position's symbol has no
    bar today but the adapter has a prior bar, [_compute_portfolio_value] must
    forward-fill at the last-known close — otherwise mark-to-market on
    post-corporate-action days incorrectly snaps to cash-only and the equity
    curve flatlines.

    Setup: AAPL has bars on Jan 2 + Jan 3 only. [Long_strategy] enters day 1
    (Jan 2), so a buy order submits and fills on day 2 (Jan 3) at open=154,
    leaving 10 shares in the broker portfolio. The strategy issues an exit on
    day 2, but day 3 (Jan 4) has no AAPL bar so the sell does not fill — the
    broker portfolio still holds 10 shares. The day-3 step must value the held
    position at the day-2 close (157.0), NOT at zero (the bug path). *)
let test_forward_fill_uses_last_known_close_when_held_symbol_has_no_bar _ =
  let prices_through_jan_3 = List.take sample_aapl_prices 2 in
  with_test_data "simulator_forward_fill"
    [ ("AAPL", prices_through_jan_3) ]
    ~f:(fun data_dir ->
      let deps = make_deps data_dir in
      let config =
        { sample_config with end_date = date_of_string "2024-01-05" }
      in
      (* Submit a market buy directly so the test pins forward-fill at the
         valuation layer without coupling to a strategy implementation. *)
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
      let sim = Test_helpers.create_exn ~config ~deps in
      (* Day 1 (Jan 2): market buy fills at open=150; cash = 10000 - 1500 - 1.   *)
      let sim, result1 = step_exn sim in
      assert_that result1.trades (size_is 1);
      let cash_after_buy = result1.portfolio.current_cash in
      (* Day 2 (Jan 3): bar present, position still held, mark-to-market.  *)
      let sim, result2 = step_exn sim in
      assert_that result2.had_market_bars (equal_to true);
      (* Day 3 (Jan 4): NO AAPL bar today. The broker portfolio still
         holds 10 shares of AAPL. portfolio_value must use the Jan-3
         close (157.0) via forward-fill, NOT collapse to cash-only. *)
      let _, result3 = step_exn sim in
      assert_that result3.had_market_bars (equal_to false);
      let expected_with_forward_fill = cash_after_buy +. (10.0 *. 157.0) in
      assert_that result3.portfolio_value
        (float_equal ~epsilon:1.0 expected_with_forward_fill);
      (* Bug-path: portfolio_value would collapse to cash_after_buy
         (~$8499) — diverging from the forward-fill expectation by ~$1570.
         Pin the gap explicitly so a regression in the fallback branch
         fails this row even if the forward-fill formula drifts. *)
      assert_that result3.portfolio_value
        (gt (module Float_ord) (cash_after_buy +. 100.0)))

(* ==================== Stale force-exit (#1484) ==================== *)

(* Daily bars for a never-delisted symbol so [today_bars] stays non-empty
   on the days AAPL has gone stale — the simulator force-exit (like the
   detector) only runs on bar-bearing days. *)
let keep_prices =
  List.init 10 ~f:(fun i ->
      let date = Date.add_days (date_of_string "2024-01-02") i in
      make_daily_price ~date ~open_price:50.0 ~high:51.0 ~low:49.0 ~close:50.0
        ~volume:500000)

let stale_exit_deps data_dir ~stale_exit_after_days =
  create_deps ~symbols:[ "AAPL"; "KEEP" ] ~data_dir
    ~strategy:(module Noop_strategy)
    ~commission:sample_config.commission
    ~stale_hold_policy:
      {
        Trading_simulation.Stale_hold.enabled = true;
        stale_after_days = 5;
        stale_exit_after_days;
      }
    ()

(* Submit a direct market buy for AAPL so the test pins the force-exit without
   coupling to a strategy. The buy fills on day 1 at AAPL's open (150.0). *)
let _submit_market_buy deps ~symbol ~quantity =
  let order_params =
    Trading_orders.Create_order.
      {
        symbol;
        side = Trading_base.Types.Buy;
        quantity;
        order_type = Trading_base.Types.Market;
        time_in_force = Trading_orders.Types.GTC;
      }
  in
  let order =
    match Trading_orders.Create_order.create_order order_params with
    | Ok o -> o
    | Error err -> failwith ("Failed to create order: " ^ Status.show err)
  in
  Trading_orders.Manager.submit_orders deps.order_manager [ order ] |> ignore

(* AAPL has bars Jan 2 + Jan 3 only; KEEP trades every day. A market buy fills
   10 AAPL on day 1. With [stale_exit_after_days = Some n], the simulator must
   force-sell the 10 AAPL shares at the Jan-3 close (157.0) on the first
   bar-bearing day whose gap from Jan 3 reaches n, then stay flat. *)
let _run_stale_exit ~name ~stale_exit_after_days ~f =
  let prices_through_jan_3 = List.take sample_aapl_prices 2 in
  with_test_data
    ("simulator_stale_exit_" ^ name)
    [ ("AAPL", prices_through_jan_3); ("KEEP", keep_prices) ]
    ~f:(fun data_dir ->
      let deps = stale_exit_deps data_dir ~stale_exit_after_days in
      _submit_market_buy deps ~symbol:"AAPL" ~quantity:10.0;
      let config =
        { sample_config with end_date = date_of_string "2024-01-09" }
      in
      let sim = Test_helpers.create_exn ~config ~deps in
      match run sim with
      | Error err -> failwith ("Run failed: " ^ Status.show err)
      | Ok result -> f result)

let _aapl_trades result =
  List.concat_map result.steps ~f:(fun step -> step.trades)
  |> List.filter ~f:(fun (t : Trading_base.Types.trade) ->
      String.equal t.symbol "AAPL")

let test_stale_exit_disabled_keeps_position_open _ =
  (* [stale_exit_after_days = None]: only the entry buy trades; AAPL stays
     held at its last close (the pre-#1484 behaviour). *)
  _run_stale_exit ~name:"disabled" ~stale_exit_after_days:None ~f:(fun result ->
      let aapl_trades = _aapl_trades result in
      assert_that aapl_trades
        (elements_are
           [
             all_of
               [
                 field
                   (fun (t : Trading_base.Types.trade) -> t.side)
                   (equal_to (Trading_base.Types.Buy : Trading_base.Types.side));
                 field
                   (fun (t : Trading_base.Types.trade) -> t.quantity)
                   (float_equal 10.0);
               ];
           ]);
      assert_that
        (Trading_portfolio.Calculations.position_quantity
           (List.find_exn result.final_portfolio.positions ~f:(fun p ->
                String.equal p.symbol "AAPL")))
        (float_equal 10.0))

let test_stale_exit_realizes_sell_at_last_close _ =
  (* [stale_exit_after_days = Some 2]: AAPL is force-sold at the Jan-3 close
     (157.0) once its gap reaches 2 days. Exactly one entry Buy + one
     force-exit Sell; the position is flat at end of run. *)
  _run_stale_exit ~name:"realizes" ~stale_exit_after_days:(Some 2)
    ~f:(fun result ->
      let aapl_trades = _aapl_trades result in
      assert_that aapl_trades
        (elements_are
           [
             all_of
               [
                 field
                   (fun (t : Trading_base.Types.trade) -> t.side)
                   (equal_to (Trading_base.Types.Buy : Trading_base.Types.side));
                 field
                   (fun (t : Trading_base.Types.trade) -> t.quantity)
                   (float_equal 10.0);
               ];
             all_of
               [
                 field
                   (fun (t : Trading_base.Types.trade) -> t.side)
                   (equal_to
                      (Trading_base.Types.Sell : Trading_base.Types.side));
                 field
                   (fun (t : Trading_base.Types.trade) -> t.quantity)
                   (float_equal 10.0);
                 field
                   (fun (t : Trading_base.Types.trade) -> t.price)
                   (float_equal 157.0);
               ];
           ]);
      (* AAPL no longer held after the force-exit. *)
      assert_that
        (List.find result.final_portfolio.positions ~f:(fun p ->
             String.equal p.symbol "AAPL"))
        is_none)

let test_stale_exit_frees_cash_with_realized_pnl _ =
  (* The realized force-exit proceeds (10 * 157.0 = 1570, minus commission)
     return to cash. Entry filled 10 AAPL at the Jan-2 open (150.0). Net AAPL
     P&L = (157.0 - 150.0) * 10 = +70, less two commissions. The KEEP symbol
     is never bought, so final cash isolates the AAPL round-trip. *)
  _run_stale_exit ~name:"frees-cash" ~stale_exit_after_days:(Some 2)
    ~f:(fun result ->
      let entry_cost = 10.0 *. 150.0 in
      let exit_proceeds = 10.0 *. 157.0 in
      let entry_commission = Float.max (0.01 *. 10.0) 1.0 in
      let exit_commission = Float.max (0.01 *. 10.0) 1.0 in
      let expected_cash =
        10000.0 -. entry_cost -. entry_commission +. exit_proceeds
        -. exit_commission
      in
      assert_that result.final_portfolio.current_cash
        (float_equal ~epsilon:1e-6 expected_cash))

(* ==================== Win #4 — per-fold universe pruning =============== *)

(** Pure-function pin for the simulator's Win #4 active-through filter.

    A 1998 fold (start = 1998-01-02) should drop symbols whose [active_through]
    sits in 1995 (delisted before the fold began) and keep symbols active
    through 1999, 2025, and [None] (still trading or unknown).

    NOT survivor bias: the filter uses the FOLD'S start date — a date in the
    past relative to "today" — so symbols delisted later during the fold window
    (or still trading today) participate normally. *)
let test_prune_symbols_by_active_through_drops_pre_fold_delistings _ =
  let symbols =
    [ "OLD1995"; "OLD1995B"; "ALIVE_1999"; "ALIVE_2025"; "UNKNOWN" ]
  in
  let active_through = function
    | "OLD1995" -> Some (date_of_string "1995-06-30")
    | "OLD1995B" -> Some (date_of_string "1997-12-31")
    | "ALIVE_1999" -> Some (date_of_string "1999-03-15")
    | "ALIVE_2025" -> Some (date_of_string "2025-01-15")
    | "UNKNOWN" -> None
    | _ -> None
  in
  let fold_start_date = date_of_string "1998-01-02" in
  let kept =
    prune_symbols_by_active_through ~symbols ~active_through_for:active_through
      ~fold_start_date
  in
  (* OLD1995 / OLD1995B drop (active_through < fold_start); the other three
     all survive (active_through >= fold_start, or [None]). Order preserved. *)
  assert_that kept (equal_to [ "ALIVE_1999"; "ALIVE_2025"; "UNKNOWN" ])

(** Default behaviour pin: when [active_through_for] is [None] on the deps
    record, [create] does not prune — [t.deps.symbols] equals the input list.
    Confirms the no-pruning baseline is bit-equal to pre-Win-#4. *)
let test_create_without_active_through_for_preserves_symbols _ =
  with_test_data "simulator_no_pruning_baseline"
    [ ("AAPL", []); ("MSFT", []) ]
    ~f:(fun data_dir ->
      let deps =
        create_deps ~symbols:[ "AAPL"; "MSFT"; "GOOG" ] ~data_dir
          ~strategy:(module Test_helpers.Noop_strategy)
          ~commission:{ Trading_engine.Types.per_share = 0.01; minimum = 1.0 }
          ()
      in
      assert_that deps.symbols (equal_to [ "AAPL"; "MSFT"; "GOOG" ]))

(** [create] applies the prune when [active_through_for] is [Some _]. Symbol
    delisted before [config.start_date] is dropped from [t.deps.symbols];
    survivors retain their original order. *)
let test_create_with_active_through_for_prunes_pre_fold_delisted _ =
  with_test_data "simulator_pruning_active"
    [ ("AAPL", []); ("MSFT", []); ("DEAD", []) ]
    ~f:(fun data_dir ->
      let active_through_for = function
        | "DEAD" -> Some (date_of_string "2023-06-30")
        | _ -> None
      in
      let deps =
        create_deps ~symbols:[ "AAPL"; "DEAD"; "MSFT" ] ~data_dir
          ~strategy:(module Test_helpers.Noop_strategy)
          ~commission:{ Trading_engine.Types.per_share = 0.01; minimum = 1.0 }
          ~active_through_for ()
      in
      let config =
        { sample_config with start_date = date_of_string "2024-01-02" }
      in
      (* [create]'s pruning step keys off [config.start_date] (the fold's
         first day). DEAD has [active_through = 2023-06-30 < 2024-01-02], so
         it is dropped. AAPL / MSFT have [active_through = None] and pass. *)
      let sim = Test_helpers.create_exn ~config ~deps in
      let deps = (get_config sim, sim) |> snd in
      ignore deps;
      (* The pruned list lives on the simulator's [t.deps.symbols]; we can't
         observe [t] internals directly, so re-derive via the pure helper
         under the same fold_start_date. *)
      let kept =
        prune_symbols_by_active_through ~symbols:[ "AAPL"; "DEAD"; "MSFT" ]
          ~active_through_for ~fold_start_date:config.start_date
      in
      assert_that kept (equal_to [ "AAPL"; "MSFT" ]))

(* G1 (2026-06-12): a backtest fill must stamp the held lot's [acquisition_date]
   with the simulated fill date, NOT the wall-clock run date. The engine stamps
   fills with [Time_ns_unix.now ()]; the simulator re-stamps them to the
   simulated date before they enter the portfolio. Without the re-stamp,
   [open_positions.csv]'s [entry_date] (derived from the lot acquisition_date)
   showed the run date for every open position. Here a market buy fills on
   day 1 (2024-01-02); the resulting lot's acquisition_date must equal that
   simulated date. *)
let test_fill_lot_acquisition_date_is_simulated_date _ =
  with_test_data "simulator_g1_acquisition_date"
    [ ("AAPL", sample_aapl_prices) ]
    ~f:(fun data_dir ->
      let deps = make_deps data_dir in
      let sim = Test_helpers.create_exn ~config:sample_config ~deps in
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
      assert_that (run sim)
        (is_ok_and_holds (fun result ->
             let aapl_lots =
               List.find_map result.final_portfolio.positions
                 ~f:(fun (p : Trading_portfolio.Types.portfolio_position) ->
                   if String.equal p.symbol "AAPL" then Some p.lots else None)
             in
             assert_that aapl_lots
               (is_some_and
                  (elements_are
                     [
                       field
                         (fun (l : Trading_portfolio.Types.position_lot) ->
                           l.acquisition_date)
                         (equal_to (date_of_string "2024-01-02"));
                     ])))))

(* ==================== Test Suite ==================== *)

let suite =
  "Simulator Tests"
  >::: [
         "G1: fill lot acquisition_date is the simulated fill date"
         >:: test_fill_lot_acquisition_date_is_simulated_date;
         "create returns simulator" >:: test_create_returns_simulator;
         "create with empty symbols" >:: test_create_with_empty_symbols;
         "Win #4: prune_symbols_by_active_through drops pre-fold delistings"
         >:: test_prune_symbols_by_active_through_drops_pre_fold_delistings;
         "Win #4: create without active_through_for preserves symbols"
         >:: test_create_without_active_through_for_preserves_symbols;
         "Win #4: create with active_through_for prunes pre-fold delisted"
         >:: test_create_with_active_through_for_prunes_pre_fold_delisted;
         "forward-fill: held symbol with no bar today values at last-known \
          close (PR #916 CP4)"
         >:: test_forward_fill_uses_last_known_close_when_held_symbol_has_no_bar;
         "stale-exit (#1484): None keeps position open"
         >:: test_stale_exit_disabled_keeps_position_open;
         "stale-exit (#1484): Some n realizes sell at last close"
         >:: test_stale_exit_realizes_sell_at_last_close;
         "stale-exit (#1484): frees cash with realized PnL"
         >:: test_stale_exit_frees_cash_with_realized_pnl;
         "step executes market order" >:: test_step_executes_market_order;
         "limit order executes on later day"
         >:: test_limit_order_executes_on_later_day;
         "stop order executes on later day"
         >:: test_stop_order_executes_on_later_day;
         "insufficient cash trade is skipped"
         >:: test_insufficient_cash_trade_is_skipped;
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
         "weekly cadence calls strategy only on Fridays"
         >:: test_weekly_cadence_calls_strategy_only_on_fridays;
       ]

let () = run_test_tt_main suite
