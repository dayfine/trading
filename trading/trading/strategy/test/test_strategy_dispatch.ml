open OUnit2
open Core
open Test_helpers

let date_of_string s = Date.of_string s

(** Helper to create portfolio *)
let create_portfolio_exn () =
  Trading_portfolio.Portfolio.create ~initial_cash:100000.0 ()

(** Test: Can create and execute EMA strategy through dispatch *)
let test_dispatch_ema_strategy _ =
  let prices =
    Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:20 ~base_price:140.0 ~trend:(Price_generators.Uptrend 0.5)
      ~volatility:0.01
  in
  let market_data =
    Mock_market_data.create
      ~data:[ ("AAPL", prices) ]
      ~ema_periods:[ 10 ]
      ~current_date:(date_of_string "2024-01-15")
  in

  (* Create EMA strategy via dispatch *)
  let ema_config =
    {
      Trading_strategy.Ema_strategy.symbols = [ "AAPL" ];
      ema_period = 10;
      stop_loss_percent = 0.05;
      take_profit_percent = 0.10;
      position_size = 100.0;
    }
  in
  let strategy = Trading_strategy.Strategy.create_strategy (Trading_strategy.Strategy.EmaConfig ema_config) in

  (* Verify strategy name *)
  assert_equal "EmaCrossover" (Trading_strategy.Strategy.get_name strategy);

  (* Execute strategy *)
  let portfolio = create_portfolio_exn () in
  let result =
    Trading_strategy.Strategy.execute ~market_data
      ~get_price:Mock_market_data.get_price ~get_indicator:Mock_market_data.get_indicator
      ~portfolio strategy
  in

  match result with
  | Ok (output, new_strategy) ->
      (* Should have executed successfully *)
      assert_bool "Should have transitions" (List.length output.transitions > 0);
      (* Strategy name should be preserved *)
      assert_equal "EmaCrossover"
        (Trading_strategy.Strategy.get_name new_strategy)
  | Error err -> assert_failure ("EMA strategy failed: " ^ Status.show err)

(** Test: Can create and execute Buy-and-Hold strategy through dispatch *)
let test_dispatch_buy_and_hold_strategy _ =
  let prices =
    Price_generators.make_price_sequence ~symbol:"MSFT"
      ~start_date:(date_of_string "2024-01-01")
      ~days:10 ~base_price:300.0 ~trend:Price_generators.Sideways
      ~volatility:0.01
  in
  let market_data =
    Mock_market_data.create
      ~data:[ ("MSFT", prices) ]
      ~ema_periods:[]
      ~current_date:(date_of_string "2024-01-05")
  in

  (* Create Buy-and-Hold strategy via dispatch *)
  let bh_config =
    {
      Trading_strategy.Buy_and_hold_strategy.symbols = [ "MSFT" ];
      position_size = 50.0;
      entry_date = None;
    }
  in
  let strategy =
    Trading_strategy.Strategy.create_strategy (Trading_strategy.Strategy.BuyAndHoldConfig bh_config)
  in

  (* Verify strategy name *)
  assert_equal "BuyAndHold" (Trading_strategy.Strategy.get_name strategy);

  (* Execute strategy *)
  let portfolio = create_portfolio_exn () in
  let result =
    Trading_strategy.Strategy.execute ~market_data
      ~get_price:Mock_market_data.get_price ~get_indicator:Mock_market_data.get_indicator
      ~portfolio strategy
  in

  match result with
  | Ok (output, new_strategy) ->
      assert_bool "Should have transitions" (List.length output.transitions > 0);
      assert_equal "BuyAndHold"
        (Trading_strategy.Strategy.get_name new_strategy)
  | Error err ->
      assert_failure ("Buy-and-Hold strategy failed: " ^ Status.show err)

(** Test: Multiple strategies can be executed independently via dispatch *)
let test_dispatch_multiple_strategies _ =
  (* Create price data for two symbols *)
  let aapl_prices =
    Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:20 ~base_price:150.0 ~trend:(Price_generators.Uptrend 0.8)
      ~volatility:0.01
  in
  let msft_prices =
    Price_generators.make_price_sequence ~symbol:"MSFT"
      ~start_date:(date_of_string "2024-01-01")
      ~days:20 ~base_price:300.0 ~trend:(Price_generators.Uptrend 0.5)
      ~volatility:0.01
  in
  let market_data =
    Mock_market_data.create
      ~data:[ ("AAPL", aapl_prices); ("MSFT", msft_prices) ]
      ~ema_periods:[ 10 ]
      ~current_date:(date_of_string "2024-01-15")
  in

  (* Create EMA strategy for AAPL *)
  let ema_config =
    {
      Trading_strategy.Ema_strategy.symbols = [ "AAPL" ];
      ema_period = 10;
      stop_loss_percent = 0.05;
      take_profit_percent = 0.10;
      position_size = 100.0;
    }
  in
  let ema_strategy = Trading_strategy.Strategy.create_strategy (Trading_strategy.Strategy.EmaConfig ema_config) in

  (* Create Buy-and-Hold strategy for MSFT *)
  let bh_config =
    {
      Trading_strategy.Buy_and_hold_strategy.symbols = [ "MSFT" ];
      position_size = 50.0;
      entry_date = None;
    }
  in
  let bh_strategy =
    Trading_strategy.Strategy.create_strategy (Trading_strategy.Strategy.BuyAndHoldConfig bh_config)
  in

  let portfolio = create_portfolio_exn () in

  (* Execute both strategies *)
  let ema_result =
    Trading_strategy.Strategy.execute ~market_data
      ~get_price:Mock_market_data.get_price ~get_indicator:Mock_market_data.get_indicator
      ~portfolio ema_strategy
  in

  let bh_result =
    Trading_strategy.Strategy.execute ~market_data
      ~get_price:Mock_market_data.get_price ~get_indicator:Mock_market_data.get_indicator
      ~portfolio bh_strategy
  in

  (* Both should execute successfully *)
  (match ema_result with
  | Ok (output, new_strategy) ->
      assert_bool "EMA should have transitions"
        (List.length output.transitions > 0);
      assert_equal "EmaCrossover"
        (Trading_strategy.Strategy.get_name new_strategy)
  | Error err -> assert_failure ("EMA failed: " ^ Status.show err));

  match bh_result with
  | Ok (output, new_strategy) ->
      assert_bool "B&H should have transitions"
        (List.length output.transitions > 0);
      assert_equal "BuyAndHold"
        (Trading_strategy.Strategy.get_name new_strategy)
  | Error err -> assert_failure ("B&H failed: " ^ Status.show err)

(** Test: Strategy state is preserved across executions *)
let test_strategy_state_preservation _ =
  let prices =
    Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:20 ~base_price:150.0 ~trend:(Price_generators.Uptrend 0.5)
      ~volatility:0.01
  in
  let market_data =
    Mock_market_data.create
      ~data:[ ("AAPL", prices) ]
      ~ema_periods:[ 10 ]
      ~current_date:(date_of_string "2024-01-15")
  in

  let ema_config =
    {
      Trading_strategy.Ema_strategy.symbols = [ "AAPL" ];
      ema_period = 10;
      stop_loss_percent = 0.05;
      take_profit_percent = 0.10;
      position_size = 100.0;
    }
  in
  let strategy = Trading_strategy.Strategy.create_strategy (Trading_strategy.Strategy.EmaConfig ema_config) in
  let portfolio = create_portfolio_exn () in

  (* Day 1: Enter position *)
  let result1 =
    Trading_strategy.Strategy.execute ~market_data
      ~get_price:Mock_market_data.get_price ~get_indicator:Mock_market_data.get_indicator
      ~portfolio strategy
  in

  let strategy1 =
    match result1 with
    | Ok (_, s) -> s
    | Error err -> failwith ("Day 1 failed: " ^ Status.show err)
  in

  (* Day 2: Should still have position state *)
  let market_data' =
    Mock_market_data.advance market_data ~date:(date_of_string "2024-01-16")
  in
  let result2 =
    Trading_strategy.Strategy.execute ~market_data:market_data'
      ~get_price:Mock_market_data.get_price ~get_indicator:Mock_market_data.get_indicator
      ~portfolio strategy1
  in

  match result2 with
  | Ok (output, new_strategy) ->
      (* Should have no new transitions (holding position) *)
      assert_equal 0 (List.length output.transitions);
      (* Strategy should maintain its type *)
      assert_equal "EmaCrossover"
        (Trading_strategy.Strategy.get_name new_strategy)
  | Error err -> assert_failure ("Day 2 failed: " ^ Status.show err)

let suite =
  "Strategy Dispatch Tests"
  >::: [
         "dispatch ema strategy" >:: test_dispatch_ema_strategy;
         "dispatch buy and hold strategy"
         >:: test_dispatch_buy_and_hold_strategy;
         "dispatch multiple strategies" >:: test_dispatch_multiple_strategies;
         "strategy state preservation" >:: test_strategy_state_preservation;
       ]

let () = run_test_tt_main suite
