open OUnit2
open Core
open Matchers
open Test_helpers

let date_of_string s = Date.of_string s

(** Helper to create portfolio *)
let create_portfolio_exn () =
  Trading_portfolio.Portfolio.create ~initial_cash:100000.0 ()

(** Helper to create strategy module and initial state from config *)
let make_strategy config = Trading_strategy.Buy_and_hold_strategy.make config

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
  let (module S), initial_state = make_strategy config in
  let portfolio = create_portfolio_exn () in

  (* Execute strategy - should enter immediately *)
  let get_price_fn = Mock_market_data.get_price market_data in
  let get_indicator_fn = Mock_market_data.get_indicator market_data in
  let result =
    S.on_market_close ~get_price:get_price_fn ~get_indicator:get_indicator_fn
      ~portfolio ~state:initial_state
  in

  match result with
  | Ok (output, new_state) -> (
      (* Strategy should not produce execution transitions *)
      assert_equal 0
        (List.length output.transitions)
        ~msg:"Strategy should not produce entry transitions";
      (* Should have created position in Entering state *)
      match Map.find new_state.positions "AAPL" with
      | Some position -> (
          match Trading_strategy.Position.get_state position with
          | Entering entering ->
              assert_that entering.target_quantity (float_equal 100.0)
          | _ -> assert_failure "Expected Entering state")
      | None -> assert_failure "Expected position to exist")
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
  let (module S), initial_state = make_strategy config in
  let portfolio = create_portfolio_exn () in

  (* Day 1: Before entry date - should not enter *)
  let get_price_fn = Mock_market_data.get_price market_data in
  let get_indicator_fn = Mock_market_data.get_indicator market_data in
  let result1 =
    S.on_market_close ~get_price:get_price_fn ~get_indicator:get_indicator_fn
      ~portfolio ~state:initial_state
  in

  (match result1 with
  | Ok (output, new_state) ->
      assert_equal 0 (List.length output.transitions);
      assert_bool "Should not have position"
        (Option.is_none (Map.find new_state.positions "AAPL"))
  | Error err -> assert_failure ("Day 1 failed: " ^ Status.show err));

  (* Day 2: On entry date - should enter *)
  let market_data' =
    Mock_market_data.advance market_data ~date:(date_of_string "2024-01-05")
  in
  let get_price_fn' = Mock_market_data.get_price market_data' in
  let get_indicator_fn' = Mock_market_data.get_indicator market_data' in
  let result2 =
    S.on_market_close ~get_price:get_price_fn' ~get_indicator:get_indicator_fn'
      ~portfolio ~state:initial_state
  in

  match result2 with
  | Ok (output, new_state) -> (
      assert_equal 0
        (List.length output.transitions)
        ~msg:"Should not produce transitions";
      (* Should have position in Entering state *)
      match Map.find new_state.positions "AAPL" with
      | Some position -> (
          match Trading_strategy.Position.get_state position with
          | Entering _ -> ()
          | _ -> assert_failure "Expected Entering state")
      | None -> assert_failure "Should have position")
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
  let (module S), initial_state = make_strategy config in
  let portfolio = create_portfolio_exn () in

  (* Day 1: Enter position *)
  let get_price_fn = Mock_market_data.get_price market_data in
  let get_indicator_fn = Mock_market_data.get_indicator market_data in
  let result1 =
    S.on_market_close ~get_price:get_price_fn ~get_indicator:get_indicator_fn
      ~portfolio ~state:initial_state
  in
  let state1 =
    match result1 with
    | Ok (output, s) ->
        assert_equal 0
          (List.length output.transitions)
          ~msg:"Entry should not produce transitions";
        assert_bool "Should have position"
          (Option.is_some (Map.find s.positions "AAPL"));
        s
    | Error err -> failwith ("Day 1 failed: " ^ Status.show err)
  in

  (* Day 2: After entry - should never produce exit transitions *)
  let market_data' =
    Mock_market_data.advance market_data ~date:(date_of_string "2024-01-10")
  in
  let get_price_fn' = Mock_market_data.get_price market_data' in
  let get_indicator_fn' = Mock_market_data.get_indicator market_data' in
  let result2 =
    S.on_market_close ~get_price:get_price_fn' ~get_indicator:get_indicator_fn'
      ~portfolio ~state:state1
  in

  let state2 =
    match result2 with
    | Ok (output, s) ->
        (* Buy-and-hold never exits - should have no transitions *)
        assert_equal 0
          (List.length output.transitions)
          ~msg:"Buy-and-hold should never produce exit transitions";
        assert_bool "Should still have position"
          (Option.is_some (Map.find s.positions "AAPL"));
        s
    | Error err -> failwith ("Day 2 failed: " ^ Status.show err)
  in

  (* Day 3: Much later - still no exit transitions *)
  let market_data'' =
    Mock_market_data.advance market_data ~date:(date_of_string "2024-01-25")
  in
  let get_price_fn'' = Mock_market_data.get_price market_data'' in
  let get_indicator_fn'' = Mock_market_data.get_indicator market_data'' in
  let result3 =
    S.on_market_close ~get_price:get_price_fn''
      ~get_indicator:get_indicator_fn'' ~portfolio ~state:state2
  in

  match result3 with
  | Ok (output, new_state) ->
      assert_equal 0
        (List.length output.transitions)
        ~msg:"Buy-and-hold should never produce exit transitions";
      assert_bool "Should still have position"
        (Option.is_some (Map.find new_state.positions "AAPL"))
  | Error err -> assert_failure ("Day 3 failed: " ^ Status.show err)

let suite =
  "Buy and Hold Strategy Tests"
  >::: [
         "enter immediately" >:: test_enter_immediately;
         "wait for entry date" >:: test_wait_for_entry_date;
         "holds indefinitely" >:: test_holds_indefinitely;
       ]

let () = run_test_tt_main suite
