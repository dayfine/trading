open OUnit2
open Core
open Matchers
open Test_helpers

let date_of_string s = Date.of_string s

(** Helper to create portfolio *)
let create_portfolio_exn () =
  Trading_portfolio.Portfolio.create ~initial_cash:100000.0 ()

(** Test: Buy and hold enters position immediately when no entry date specified
*)
let test_enter_immediately _ =
  (* Create uptrend price data *)
  let prices =
    Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:10 ~base_price:150.0 ~trend:(Price_generators.Uptrend 0.5)
      ~volatility:0.01
  in
  let market_data =
    Mock_market_data.create
      ~data:[ ("AAPL", prices) ]
      ~ema_periods:[]
      ~current_date:(date_of_string "2024-01-05")
  in

  let config =
    {
      Trading_strategy.Buy_and_hold_strategy.symbols = [ "AAPL" ];
      position_size = 100.0;
      entry_date = None;
    }
  in
  let state = Trading_strategy.Buy_and_hold_strategy.init ~config in
  let portfolio = create_portfolio_exn () in

  (* Execute strategy - should enter immediately *)
  let result =
    Trading_strategy.Buy_and_hold_strategy.on_market_close ~market_data
      ~get_price:Mock_market_data.get_price ~get_ema:Mock_market_data.get_ema
      ~portfolio ~state
  in

  match result with
  | Ok (output, new_state) ->
      (* Should have created position transitions *)
      assert_equal 2 (List.length output.transitions);
      (* EntryFill + EntryComplete *)
      (* Should have active position *)
      assert_bool "Should have active position"
        (Option.is_some (Map.find new_state.positions "AAPL"));
      assert_bool "Entry should be executed"
        (Option.value ~default:false (Map.find new_state.entries_executed "AAPL"))
  | Error err -> assert_failure ("Strategy failed: " ^ Status.show err)

(** Test: Buy and hold waits for specific entry date *)
let test_wait_for_entry_date _ =
  let prices =
    Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:10 ~base_price:150.0 ~trend:Price_generators.Sideways
      ~volatility:0.01
  in
  let market_data =
    Mock_market_data.create
      ~data:[ ("AAPL", prices) ]
      ~ema_periods:[]
      ~current_date:(date_of_string "2024-01-03")
  in

  let config =
    {
      Trading_strategy.Buy_and_hold_strategy.symbols = [ "AAPL" ];
      position_size = 100.0;
      entry_date = Some (date_of_string "2024-01-05");
    }
  in
  let state = Trading_strategy.Buy_and_hold_strategy.init ~config in
  let portfolio = create_portfolio_exn () in

  (* Day 1: Before entry date - should not enter *)
  let result1 =
    Trading_strategy.Buy_and_hold_strategy.on_market_close ~market_data
      ~get_price:Mock_market_data.get_price ~get_ema:Mock_market_data.get_ema
      ~portfolio ~state
  in

  (match result1 with
  | Ok (output, new_state) ->
      assert_equal 0 (List.length output.transitions);
      assert_bool "Should not have position"
        (Option.is_none (Map.find new_state.positions "AAPL"));
      assert_bool "Entry should not be executed"
        (not (Option.value ~default:false (Map.find new_state.entries_executed "AAPL")))
  | Error err -> assert_failure ("Day 1 failed: " ^ Status.show err));

  (* Day 2: On entry date - should enter *)
  let market_data' =
    Mock_market_data.advance market_data ~date:(date_of_string "2024-01-05")
  in
  let result2 =
    Trading_strategy.Buy_and_hold_strategy.on_market_close
      ~market_data:market_data' ~get_price:Mock_market_data.get_price
      ~get_ema:Mock_market_data.get_ema ~portfolio ~state
  in

  match result2 with
  | Ok (output, new_state) ->
      assert_equal 2 (List.length output.transitions);
      assert_bool "Should have position"
        (Option.is_some (Map.find new_state.positions "AAPL"));
      assert_bool "Entry should be executed"
        (Option.value ~default:false (Map.find new_state.entries_executed "AAPL"))
  | Error err -> assert_failure ("Day 2 failed: " ^ Status.show err)

(** Test: Buy and hold never exits - holds indefinitely *)
let test_holds_indefinitely _ =
  let prices =
    Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:30 ~base_price:150.0 ~trend:(Price_generators.Uptrend 1.0)
      ~volatility:0.02
  in
  let market_data =
    Mock_market_data.create
      ~data:[ ("AAPL", prices) ]
      ~ema_periods:[]
      ~current_date:(date_of_string "2024-01-05")
  in

  let config =
    {
      Trading_strategy.Buy_and_hold_strategy.symbols = [ "AAPL" ];
      position_size = 100.0;
      entry_date = None;
    }
  in
  let state = Trading_strategy.Buy_and_hold_strategy.init ~config in
  let portfolio = create_portfolio_exn () in

  (* Day 1: Enter position *)
  let result1 =
    Trading_strategy.Buy_and_hold_strategy.on_market_close ~market_data
      ~get_price:Mock_market_data.get_price ~get_ema:Mock_market_data.get_ema
      ~portfolio ~state
  in
  let state1 =
    match result1 with
    | Ok (_, s) -> s
    | Error err -> failwith ("Day 1 failed: " ^ Status.show err)
  in

  (* Day 2: After entry - should hold (no exit) *)
  let market_data' =
    Mock_market_data.advance market_data ~date:(date_of_string "2024-01-10")
  in
  let result2 =
    Trading_strategy.Buy_and_hold_strategy.on_market_close
      ~market_data:market_data' ~get_price:Mock_market_data.get_price
      ~get_ema:Mock_market_data.get_ema ~portfolio ~state:state1
  in

  (match result2 with
  | Ok (output, new_state) -> (
      (* Should have no new transitions or orders *)
      assert_equal 0 (List.length output.transitions);
      (* Position should still be active *)
      assert_bool "Should still have position"
        (Option.is_some (Map.find new_state.positions "AAPL"));
      (* Verify position is in Holding state *)
      match Map.find new_state.positions "AAPL" with
      | Some pos -> (
          match Trading_strategy.Position.get_state pos with
          | Holding h ->
              (* Verify no exit criteria *)
              assert_bool "Should have no stop loss"
                (Option.is_none h.risk_params.stop_loss_price);
              assert_bool "Should have no take profit"
                (Option.is_none h.risk_params.take_profit_price);
              assert_bool "Should have no max hold days"
                (Option.is_none h.risk_params.max_hold_days)
          | _ -> assert_failure "Expected Holding state")
      | None -> assert_failure "Expected active position")
  | Error err -> assert_failure ("Day 2 failed: " ^ Status.show err));

  (* Day 3: Much later - still holding *)
  let market_data'' =
    Mock_market_data.advance market_data ~date:(date_of_string "2024-01-25")
  in
  let state2 =
    match result2 with
    | Ok (_, s) -> s
    | Error err -> failwith ("Can't get state2: " ^ Status.show err)
  in
  let result3 =
    Trading_strategy.Buy_and_hold_strategy.on_market_close
      ~market_data:market_data'' ~get_price:Mock_market_data.get_price
      ~get_ema:Mock_market_data.get_ema ~portfolio ~state:state2
  in

  match result3 with
  | Ok (output, new_state) ->
      assert_equal 0 (List.length output.transitions);
      assert_bool "Should still have position"
        (Option.is_some (Map.find new_state.positions "AAPL"))
  | Error err -> assert_failure ("Day 3 failed: " ^ Status.show err)

(** Test: Position has no risk parameters (no exit criteria) *)
let test_no_risk_parameters _ =
  let prices =
    Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:5 ~base_price:100.0 ~trend:Price_generators.Sideways
      ~volatility:0.01
  in
  let market_data =
    Mock_market_data.create
      ~data:[ ("AAPL", prices) ]
      ~ema_periods:[]
      ~current_date:(date_of_string "2024-01-01")
  in

  let config =
    {
      Trading_strategy.Buy_and_hold_strategy.symbols = [ "AAPL" ];
      position_size = 50.0;
      entry_date = None;
    }
  in
  let state = Trading_strategy.Buy_and_hold_strategy.init ~config in
  let portfolio = create_portfolio_exn () in

  let result =
    Trading_strategy.Buy_and_hold_strategy.on_market_close ~market_data
      ~get_price:Mock_market_data.get_price ~get_ema:Mock_market_data.get_ema
      ~portfolio ~state
  in

  match result with
  | Ok (_, new_state) -> (
      match Map.find new_state.positions "AAPL" with
      | Some pos -> (
          match Trading_strategy.Position.get_state pos with
          | Holding h ->
              assert_that h.risk_params.stop_loss_price is_none;
              assert_that h.risk_params.take_profit_price is_none;
              assert_that h.risk_params.max_hold_days is_none
          | _ -> assert_failure "Expected Holding state")
      | None -> assert_failure "Expected position")
  | Error err -> assert_failure ("Failed: " ^ Status.show err)

let suite =
  "Buy and Hold Strategy Tests"
  >::: [
         "enter immediately" >:: test_enter_immediately;
         "wait for entry date" >:: test_wait_for_entry_date;
         "holds indefinitely" >:: test_holds_indefinitely;
         "no risk parameters" >:: test_no_risk_parameters;
       ]

let () = run_test_tt_main suite
