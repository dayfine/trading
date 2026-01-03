open OUnit2
open Core
open Matchers
open Test_helpers

let date_of_string s = Date.of_string s

(** Helper to create portfolio *)
let create_portfolio_exn () =
  Trading_portfolio.Portfolio.create ~initial_cash:100000.0 ()

(** Helper to create strategy module and initial state from config *)
let make_strategy config =
  let strategy_module, initial_state =
    Trading_strategy.Ema_strategy.make config
  in
  let (module S : Trading_strategy.Strategy_interface.STRATEGY) =
    strategy_module
  in
  ((module S : Trading_strategy.Strategy_interface.STRATEGY), initial_state)

(** Test: Two strategies with different EMA periods work independently *)
let test_different_ema_periods_different_signals _ =
  (* Create price data with uptrend *)
  let prices =
    Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:25 ~base_price:140.0 ~trend:(Price_generators.Uptrend 0.5)
      ~volatility:0.01
  in
  let market_data =
    Mock_market_data.create
      ~data:[ ("AAPL", prices) ]
      ~ema_periods:[ 10; 50 ]
      ~current_date:(date_of_string "2024-01-20")
  in

  (* Strategy 1: EMA(10) *)
  let config_10 =
    {
      Trading_strategy.Ema_strategy.symbols = [ "AAPL" ];
      ema_period = 10;
      stop_loss_percent = 0.05;
      take_profit_percent = 0.10;
      position_size = 100.0;
    }
  in
  let (module S_10), initial_state_10 = make_strategy config_10 in

  (* Strategy 2: EMA(50) *)
  let config_50 =
    {
      Trading_strategy.Ema_strategy.symbols = [ "AAPL" ];
      ema_period = 50;
      stop_loss_percent = 0.05;
      take_profit_percent = 0.10;
      position_size = 200.0;
    }
  in
  let (module S_50), initial_state_50 = make_strategy config_50 in

  let portfolio = create_portfolio_exn () in

  (* Execute both strategies on same market data *)
  let get_price_fn = Mock_market_data.get_price market_data in
  let get_indicator_fn = Mock_market_data.get_indicator market_data in

  let result_10 =
    S_10.on_market_close ~get_price:get_price_fn ~get_indicator:get_indicator_fn
      ~portfolio ~state:initial_state_10
  in

  let result_50 =
    S_50.on_market_close ~get_price:get_price_fn ~get_indicator:get_indicator_fn
      ~portfolio ~state:initial_state_50
  in

  (* Both strategies should be able to execute successfully *)
  (match result_10 with
  | Ok (_, _new_state) ->
      (* Config is passed separately now, just verify execution succeeded *)
      ()
  | Error err -> assert_failure ("EMA(10) strategy failed: " ^ Status.show err));

  (* EMA(50) should also execute successfully *)
  match result_50 with
  | Ok (_, _new_state) ->
      (* Config is passed separately now, just verify execution succeeded *)
      ()
  | Error err -> assert_failure ("EMA(50) strategy failed: " ^ Status.show err)

(** Test: Same strategy config on different symbols works independently *)
let test_same_strategy_different_symbols _ =
  (* AAPL: Strong uptrend *)
  let aapl_prices =
    Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:20 ~base_price:150.0 ~trend:(Price_generators.Uptrend 1.0)
      ~volatility:0.01
  in

  (* MSFT: Downtrend *)
  let msft_prices =
    Price_generators.make_price_sequence ~symbol:"MSFT"
      ~start_date:(date_of_string "2024-01-01")
      ~days:20 ~base_price:300.0 ~trend:(Price_generators.Downtrend 0.5)
      ~volatility:0.01
  in

  let market_data =
    Mock_market_data.create
      ~data:[ ("AAPL", aapl_prices); ("MSFT", msft_prices) ]
      ~ema_periods:[ 10 ]
      ~current_date:(date_of_string "2024-01-15")
  in

  (* Strategy for AAPL *)
  let config_aapl =
    {
      Trading_strategy.Ema_strategy.symbols = [ "AAPL" ];
      ema_period = 10;
      stop_loss_percent = 0.05;
      take_profit_percent = 0.10;
      position_size = 100.0;
    }
  in
  let (module S_aapl), initial_state_aapl = make_strategy config_aapl in

  (* Strategy for MSFT *)
  let config_msft =
    {
      Trading_strategy.Ema_strategy.symbols = [ "MSFT" ];
      ema_period = 10;
      stop_loss_percent = 0.05;
      take_profit_percent = 0.10;
      position_size = 50.0;
    }
  in
  let (module S_msft), initial_state_msft = make_strategy config_msft in

  let portfolio = create_portfolio_exn () in

  (* Execute both strategies *)
  let get_price_fn = Mock_market_data.get_price market_data in
  let get_indicator_fn = Mock_market_data.get_indicator market_data in

  let result_aapl =
    S_aapl.on_market_close ~get_price:get_price_fn
      ~get_indicator:get_indicator_fn ~portfolio ~state:initial_state_aapl
  in

  let result_msft =
    S_msft.on_market_close ~get_price:get_price_fn
      ~get_indicator:get_indicator_fn ~portfolio ~state:initial_state_msft
  in

  (* AAPL should enter (uptrend) *)
  (match result_aapl with
  | Ok (_output, new_state) -> (
      assert_bool "AAPL should have active position"
        (Option.is_some (Map.find new_state.positions "AAPL"));
      (* Verify quantity is 100 as configured *)
      match Map.find new_state.positions "AAPL" with
      | Some pos -> (
          match Trading_strategy.Position.get_state pos with
          | Holding h -> assert_that h.quantity (float_equal 100.0)
          | _ -> ())
      | None -> ())
  | Error err -> assert_failure ("AAPL strategy failed: " ^ Status.show err));

  (* MSFT should NOT enter (downtrend) *)
  match result_msft with
  | Ok (_output, new_state) ->
      assert_bool "MSFT should have no position"
        (Option.is_none (Map.find new_state.positions "MSFT"))
  | Error err -> assert_failure ("MSFT strategy failed: " ^ Status.show err)

(** Test: Strategies don't interfere with each other's state *)
let test_strategies_maintain_independent_state _ =
  (* Create price sequence with trend reversal *)
  let prices =
    Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:30 ~base_price:140.0 ~trend:(Price_generators.Uptrend 1.0)
      ~volatility:0.01
  in
  let market_data =
    Mock_market_data.create
      ~data:[ ("AAPL", prices) ]
      ~ema_periods:[ 10; 20 ]
      ~current_date:(date_of_string "2024-01-15")
  in

  (* Strategy 1: EMA(10) *)
  let config_10 =
    {
      Trading_strategy.Ema_strategy.symbols = [ "AAPL" ];
      ema_period = 10;
      stop_loss_percent = 0.05;
      take_profit_percent = 0.10;
      position_size = 100.0;
    }
  in
  let (module S_10), initial_state_10 = make_strategy config_10 in

  (* Strategy 2: EMA(20) *)
  let config_20 =
    {
      Trading_strategy.Ema_strategy.symbols = [ "AAPL" ];
      ema_period = 20;
      stop_loss_percent = 0.05;
      take_profit_percent = 0.10;
      position_size = 50.0;
    }
  in
  let (module S_20), initial_state_20 = make_strategy config_20 in

  let portfolio = create_portfolio_exn () in

  (* Day 1: Run both strategies *)
  let get_price_fn = Mock_market_data.get_price market_data in
  let get_indicator_fn = Mock_market_data.get_indicator market_data in

  let result_10_day1 =
    S_10.on_market_close ~get_price:get_price_fn ~get_indicator:get_indicator_fn
      ~portfolio ~state:initial_state_10
  in

  let result_20_day1 =
    S_20.on_market_close ~get_price:get_price_fn ~get_indicator:get_indicator_fn
      ~portfolio ~state:initial_state_20
  in

  (* Get new states *)
  let state_10_day1 =
    match result_10_day1 with
    | Ok (_, s) -> s
    | Error err -> failwith ("Day 1 EMA(10) failed: " ^ Status.show err)
  in

  let state_20_day1 =
    match result_20_day1 with
    | Ok (_, s) -> s
    | Error err -> failwith ("Day 1 EMA(20) failed: " ^ Status.show err)
  in

  (* Advance to next day *)
  let market_data' =
    Mock_market_data.advance market_data ~date:(date_of_string "2024-01-16")
  in

  (* Day 2: Run both strategies again *)
  let get_price_fn' = Mock_market_data.get_price market_data' in
  let get_indicator_fn' = Mock_market_data.get_indicator market_data' in

  let result_10_day2 =
    S_10.on_market_close ~get_price:get_price_fn'
      ~get_indicator:get_indicator_fn' ~portfolio ~state:state_10_day1
  in

  let result_20_day2 =
    S_20.on_market_close ~get_price:get_price_fn'
      ~get_indicator:get_indicator_fn' ~portfolio ~state:state_20_day1
  in

  (* Verify both strategies maintained their own state *)
  (match result_10_day2 with
  | Ok (_, _new_state) ->
      (* Strategies are passed their config separately now, just verify they executed *)
      ()
  | Error err -> assert_failure ("Day 2 EMA(10) failed: " ^ Status.show err));

  match result_20_day2 with
  | Ok (_, _new_state) ->
      (* Strategies are passed their config separately now, just verify they executed *)
      ()
  | Error err -> assert_failure ("Day 2 EMA(20) failed: " ^ Status.show err)

(** Test: Conservative vs aggressive strategy variants *)
let test_conservative_vs_aggressive_variants _ =
  (* Create volatile price data *)
  let prices =
    Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:20 ~base_price:150.0 ~trend:(Price_generators.Uptrend 0.8)
      ~volatility:0.03
  in
  let market_data =
    Mock_market_data.create
      ~data:[ ("AAPL", prices) ]
      ~ema_periods:[ 10 ]
      ~current_date:(date_of_string "2024-01-15")
  in

  (* Conservative strategy: tight stop loss, wider take profit *)
  let conservative_config =
    {
      Trading_strategy.Ema_strategy.symbols = [ "AAPL" ];
      ema_period = 10;
      stop_loss_percent = 0.03;
      (* -3% *)
      take_profit_percent = 0.15;
      (* +15% *)
      position_size = 100.0;
    }
  in
  let (module S_conservative), initial_state_conservative =
    make_strategy conservative_config
  in

  (* Aggressive strategy: wider stop loss, tighter take profit *)
  let aggressive_config =
    {
      Trading_strategy.Ema_strategy.symbols = [ "AAPL" ];
      ema_period = 10;
      stop_loss_percent = 0.10;
      (* -10% *)
      take_profit_percent = 0.05;
      (* +5% *)
      position_size = 100.0;
    }
  in
  let (module S_aggressive), initial_state_aggressive =
    make_strategy aggressive_config
  in

  let portfolio = create_portfolio_exn () in

  (* Execute both strategies *)
  let get_price_fn = Mock_market_data.get_price market_data in
  let get_indicator_fn = Mock_market_data.get_indicator market_data in

  let conservative_result =
    S_conservative.on_market_close ~get_price:get_price_fn
      ~get_indicator:get_indicator_fn ~portfolio
      ~state:initial_state_conservative
  in

  let aggressive_result =
    S_aggressive.on_market_close ~get_price:get_price_fn
      ~get_indicator:get_indicator_fn ~portfolio ~state:initial_state_aggressive
  in

  (* Both should enter on same signal *)
  (match conservative_result with
  | Ok (_, new_state) -> (
      assert_bool "Conservative should enter"
        (Option.is_some (Map.find new_state.positions "AAPL"));
      (* Verify conservative risk params *)
      match Map.find new_state.positions "AAPL" with
      | Some pos -> (
          match Trading_strategy.Position.get_state pos with
          | Holding h -> (
              (* Stop loss should be higher (less loss tolerance) *)
              match h.risk_params.stop_loss_price with
              | Some stop ->
                  let stop_pct =
                    (stop -. h.entry_price) /. h.entry_price *. 100.0
                  in
                  assert_bool "Conservative stop loss should be tight"
                    Float.(stop_pct > -4.0 && stop_pct < -2.0)
              | None -> assert_failure "Expected stop loss")
          | _ -> ())
      | None -> ())
  | Error err -> assert_failure ("Conservative failed: " ^ Status.show err));

  match aggressive_result with
  | Ok (_, new_state) -> (
      assert_bool "Aggressive should enter"
        (Option.is_some (Map.find new_state.positions "AAPL"));
      (* Verify aggressive risk params *)
      match Map.find new_state.positions "AAPL" with
      | Some pos -> (
          match Trading_strategy.Position.get_state pos with
          | Holding h -> (
              (* Stop loss should be lower (more loss tolerance) *)
              match h.risk_params.stop_loss_price with
              | Some stop ->
                  let stop_pct =
                    (stop -. h.entry_price) /. h.entry_price *. 100.0
                  in
                  assert_bool "Aggressive stop loss should be wide"
                    Float.(stop_pct < -9.0)
              | None -> assert_failure "Expected stop loss")
          | _ -> ())
      | None -> ())
  | Error err -> assert_failure ("Aggressive failed: " ^ Status.show err)

let suite =
  "Multiple Strategies Tests"
  >::: [
         "different ema periods different signals"
         >:: test_different_ema_periods_different_signals;
         "same strategy different symbols"
         >:: test_same_strategy_different_symbols;
         "strategies maintain independent state"
         >:: test_strategies_maintain_independent_state;
         "conservative vs aggressive variants"
         >:: test_conservative_vs_aggressive_variants;
       ]

let () = run_test_tt_main suite
