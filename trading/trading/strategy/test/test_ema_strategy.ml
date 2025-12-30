open OUnit2
open Core
open Matchers
open Test_helpers

let date_of_string s = Date.of_string s

(** Helper to create EMA strategy config *)
let make_config ?(symbols = [ "AAPL" ]) ?(ema_period = 10) ?(stop_loss = 0.05)
    ?(take_profit = 0.10) ?(position_size = 100.0) () =
  {
    Trading_strategy.Ema_strategy.symbols;
    ema_period;
    stop_loss_percent = stop_loss;
    take_profit_percent = take_profit;
    position_size;
  }

(** Helper to create portfolio *)
let create_portfolio_exn () =
  Trading_portfolio.Portfolio.create ~initial_cash:100000.0 ()

(** Test: Entry signal when price crosses above EMA *)
let test_entry_signal _ =
  (* Create uptrend price data *)
  let prices =
    Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:15 ~base_price:140.0 ~trend:(Price_generators.Uptrend 1.0)
      ~volatility:0.01
  in
  let market_data =
    Mock_market_data.create
      ~data:[ ("AAPL", prices) ]
      ~ema_periods:[ 10 ]
      ~current_date:(date_of_string "2024-01-15")
  in

  let config = make_config () in
  let state = Trading_strategy.Ema_strategy.init ~config in
  let portfolio = create_portfolio_exn () in

  (* Execute strategy on market close *)
  let result =
    Trading_strategy.Ema_strategy.on_market_close ~market_data
      ~get_price:Mock_market_data.get_price ~get_ema:Mock_market_data.get_ema
      ~portfolio ~state
  in

  match result with
  | Ok (output, new_state) -> (
      (* Should have created position transitions *)
      assert_bool "Should have transitions" (List.length output.transitions > 0);
      (* Should have EntryFill and EntryComplete transitions *)
      assert_equal 2 (List.length output.transitions);
      (* Should have created buy order *)
      (* Should have active position in Holding state *)
      match Map.find new_state.positions "AAPL" with
      | Some position -> (
          match Trading_strategy.Position.get_state position with
          | Holding holding -> (
              assert_that holding.quantity (float_equal 100.0);
              (* Verify stop loss is set and is below entry price *)
              match holding.risk_params.stop_loss_price with
              | Some stop_loss ->
                  assert_bool "Stop loss should be below entry price"
                    Float.(stop_loss < holding.entry_price)
              | None -> assert_failure "Expected stop loss to be set")
          | _ -> assert_failure "Expected Holding state")
      | None -> assert_failure "Expected active position")
  | Error err -> assert_failure ("Strategy failed: " ^ Status.show err)

(** Test: Take profit when price rises to target *)
let test_take_profit _ =
  (* Create strong uptrend price data *)
  let prices =
    Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:20 ~base_price:140.0 ~trend:(Price_generators.Uptrend 1.5)
      ~volatility:0.01
  in
  (* Add a spike on day 18 to trigger take profit *)
  let prices_with_spike =
    Price_generators.with_spike prices
      ~spike_date:(date_of_string "2024-01-18")
      ~spike_percent:10.0
  in
  let market_data =
    Mock_market_data.create
      ~data:[ ("AAPL", prices_with_spike) ]
      ~ema_periods:[ 10 ]
      ~current_date:(date_of_string "2024-01-15")
  in

  let config = make_config () in
  let state = Trading_strategy.Ema_strategy.init ~config in
  let portfolio = create_portfolio_exn () in

  (* Day 1: Enter position *)
  let result1 =
    Trading_strategy.Ema_strategy.on_market_close ~market_data
      ~get_price:Mock_market_data.get_price ~get_ema:Mock_market_data.get_ema
      ~portfolio ~state
  in
  let state1 =
    match result1 with
    | Ok (_, s) -> s
    | Error err -> failwith ("Day 1 failed: " ^ Status.show err)
  in

  (* Advance to spike day *)
  let market_data' =
    Mock_market_data.advance market_data ~date:(date_of_string "2024-01-18")
  in

  (* Day 2: Should trigger take profit *)
  let result2 =
    Trading_strategy.Ema_strategy.on_market_close ~market_data:market_data'
      ~get_price:Mock_market_data.get_price ~get_ema:Mock_market_data.get_ema
      ~portfolio ~state:state1
  in

  match result2 with
  | Ok (output, new_state) -> (
      (* Should have exit transitions *)
      assert_bool "Should have exit transitions"
        (List.length output.transitions > 0);
      (* Should have TriggerExit, ExitFill, ExitComplete *)
      assert_equal 3 (List.length output.transitions);
      (* Should have sell order *)
      (* Position should be closed *)
      match Map.find new_state.positions "AAPL" with
      | Some position -> (
          match Trading_strategy.Position.get_state position with
          | Closed closed ->
              (* Should have positive realized P&L *)
              assert_bool "Should have profit" Float.(closed.gross_pnl > 0.0)
          | _ -> assert_failure "Expected Closed state")
      | None -> assert_failure "Expected closed position")
  | Error err -> assert_failure ("Take profit failed: " ^ Status.show err)

(** Test: Stop loss when price falls *)
let test_stop_loss _ =
  (* Create downtrend price data *)
  let prices =
    Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:20 ~base_price:150.0 ~trend:(Price_generators.Uptrend 0.5)
      ~volatility:0.01
  in
  (* Add a sharp drop on day 17 to trigger stop loss *)
  let prices_with_drop =
    Price_generators.with_spike prices
      ~spike_date:(date_of_string "2024-01-17")
      ~spike_percent:(-8.0)
  in
  let market_data =
    Mock_market_data.create
      ~data:[ ("AAPL", prices_with_drop) ]
      ~ema_periods:[ 10 ]
      ~current_date:(date_of_string "2024-01-15")
  in

  let config = make_config () in
  let state = Trading_strategy.Ema_strategy.init ~config in
  let portfolio = create_portfolio_exn () in

  (* Day 1: Enter position *)
  let result1 =
    Trading_strategy.Ema_strategy.on_market_close ~market_data
      ~get_price:Mock_market_data.get_price ~get_ema:Mock_market_data.get_ema
      ~portfolio ~state
  in
  let state1 =
    match result1 with
    | Ok (_, s) -> s
    | Error err -> failwith ("Day 1 failed: " ^ Status.show err)
  in

  (* Advance to drop day *)
  let market_data' =
    Mock_market_data.advance market_data ~date:(date_of_string "2024-01-17")
  in

  (* Day 2: Should trigger stop loss *)
  let result2 =
    Trading_strategy.Ema_strategy.on_market_close ~market_data:market_data'
      ~get_price:Mock_market_data.get_price ~get_ema:Mock_market_data.get_ema
      ~portfolio ~state:state1
  in

  match result2 with
  | Ok (output, new_state) -> (
      (* Should have exit transitions *)
      assert_equal 3 (List.length output.transitions);
      (* Position should be closed with loss *)
      match Map.find new_state.positions "AAPL" with
      | Some position -> (
          match Trading_strategy.Position.get_state position with
          | Closed closed ->
              (* Should have negative realized P&L *)
              assert_bool "Should have loss" Float.(closed.gross_pnl < 0.0)
          | _ -> assert_failure "Expected Closed state")
      | None -> assert_failure "Expected closed position")
  | Error err -> assert_failure ("Stop loss failed: " ^ Status.show err)

(** Test: Signal reversal when price crosses below EMA *)
let test_signal_reversal _ =
  (* Create price data with reversal pattern *)
  let uptrend_prices =
    Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:15 ~base_price:140.0 ~trend:(Price_generators.Uptrend 1.0)
      ~volatility:0.01
  in
  let downtrend_prices =
    Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-16")
      ~days:5 ~base_price:155.0 ~trend:(Price_generators.Downtrend 2.0)
      ~volatility:0.01
  in
  let prices = uptrend_prices @ downtrend_prices in
  let market_data =
    Mock_market_data.create
      ~data:[ ("AAPL", prices) ]
      ~ema_periods:[ 10 ]
      ~current_date:(date_of_string "2024-01-15")
  in

  let config = make_config () in
  let state = Trading_strategy.Ema_strategy.init ~config in
  let portfolio = create_portfolio_exn () in

  (* Day 1: Enter position *)
  let result1 =
    Trading_strategy.Ema_strategy.on_market_close ~market_data
      ~get_price:Mock_market_data.get_price ~get_ema:Mock_market_data.get_ema
      ~portfolio ~state
  in
  let state1 =
    match result1 with
    | Ok (_, s) -> s
    | Error err -> failwith ("Day 1 failed: " ^ Status.show err)
  in

  (* Advance to reversal day *)
  let market_data' =
    Mock_market_data.advance market_data ~date:(date_of_string "2024-01-19")
  in

  (* Day 2: Should detect signal reversal *)
  let result2 =
    Trading_strategy.Ema_strategy.on_market_close ~market_data:market_data'
      ~get_price:Mock_market_data.get_price ~get_ema:Mock_market_data.get_ema
      ~portfolio ~state:state1
  in

  match result2 with
  | Ok (output, new_state) -> (
      (* Should have exit transitions *)
      assert_equal 3 (List.length output.transitions);
      (* Position should be closed *)
      match Map.find new_state.positions "AAPL" with
      | Some position -> (
          match Trading_strategy.Position.get_state position with
          | Closed _ -> ()
          | _ -> assert_failure "Expected Closed state")
      | None -> assert_failure "Expected closed position")
  | Error err -> assert_failure ("Signal reversal failed: " ^ Status.show err)

(** Test: No action when holding position with no exit signal *)
let test_hold_position _ =
  (* Create steady uptrend *)
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

  let config = make_config () in
  let state = Trading_strategy.Ema_strategy.init ~config in
  let portfolio = create_portfolio_exn () in

  (* Day 1: Enter position *)
  let result1 =
    Trading_strategy.Ema_strategy.on_market_close ~market_data
      ~get_price:Mock_market_data.get_price ~get_ema:Mock_market_data.get_ema
      ~portfolio ~state
  in
  let state1 =
    match result1 with
    | Ok (_, s) -> s
    | Error err -> failwith ("Day 1 failed: " ^ Status.show err)
  in

  (* Advance one day *)
  let market_data' =
    Mock_market_data.advance market_data ~date:(date_of_string "2024-01-16")
  in

  (* Day 2: Should hold position *)
  let result2 =
    Trading_strategy.Ema_strategy.on_market_close ~market_data:market_data'
      ~get_price:Mock_market_data.get_price ~get_ema:Mock_market_data.get_ema
      ~portfolio ~state:state1
  in

  match result2 with
  | Ok (output, new_state) -> (
      (* Should have no transitions *)
      assert_equal 0 (List.length output.transitions);
      (* Should have no orders *)
      (* Position should still be in Holding state *)
      match Map.find new_state.positions "AAPL" with
      | Some position -> (
          match Trading_strategy.Position.get_state position with
          | Holding _ -> ()
          | _ -> assert_failure "Expected Holding state")
      | None -> assert_failure "Expected active position")
  | Error err -> assert_failure ("Hold position failed: " ^ Status.show err)

(** Test: No entry when price is below EMA *)
let test_no_entry_below_ema _ =
  (* Create downtrend where price stays below EMA *)
  let prices =
    Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:15 ~base_price:150.0 ~trend:(Price_generators.Downtrend 1.0)
      ~volatility:0.01
  in
  let market_data =
    Mock_market_data.create
      ~data:[ ("AAPL", prices) ]
      ~ema_periods:[ 10 ]
      ~current_date:(date_of_string "2024-01-15")
  in

  let config = make_config () in
  let state = Trading_strategy.Ema_strategy.init ~config in
  let portfolio = create_portfolio_exn () in

  (* Execute strategy - should not enter *)
  let result =
    Trading_strategy.Ema_strategy.on_market_close ~market_data
      ~get_price:Mock_market_data.get_price ~get_ema:Mock_market_data.get_ema
      ~portfolio ~state
  in

  match result with
  | Ok (output, new_state) ->
      (* Should have no transitions *)
      assert_equal 0 (List.length output.transitions);
      (* Should have no orders *)
      (* Should have no active position *)
      assert_bool "Should have no position"
        (Option.is_none (Map.find new_state.positions "AAPL"))
  | Error err -> assert_failure ("No entry test failed: " ^ Status.show err)

let suite =
  "EMA Strategy Tests"
  >::: [
         "entry signal" >:: test_entry_signal;
         "take profit" >:: test_take_profit;
         "stop loss" >:: test_stop_loss;
         "signal reversal" >:: test_signal_reversal;
         "hold position" >:: test_hold_position;
         "no entry below ema" >:: test_no_entry_below_ema;
       ]

let () = run_test_tt_main suite
