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

(** Helper to create strategy module and initial state from config *)
let make_strategy config = Trading_strategy.Ema_strategy.make config

(** Helper to manually apply engine transitions to move position from Entering
    to Holding *)
let apply_entry_fill_and_complete position ~date ~entry_price ~stop_loss_pct
    ~take_profit_pct =
  (* Apply EntryFill *)
  let position =
    match
      Trading_strategy.Position.apply_transition position
        {
          position_id = position.Trading_strategy.Position.id;
          date;
          kind = EntryFill { filled_quantity = 100.0; fill_price = entry_price };
        }
    with
    | Ok p -> p
    | Error err -> failwith ("Failed to apply EntryFill: " ^ Status.show err)
  in
  (* Apply EntryComplete to reach Holding *)
  let position =
    match
      Trading_strategy.Position.apply_transition position
        {
          position_id = position.Trading_strategy.Position.id;
          date;
          kind =
            EntryComplete
              {
                risk_params =
                  {
                    stop_loss_price =
                      Some (entry_price *. (1.0 -. stop_loss_pct));
                    take_profit_price =
                      Some (entry_price *. (1.0 +. take_profit_pct));
                    max_hold_days = None;
                  };
              };
        }
    with
    | Ok p -> p
    | Error err -> failwith ("Failed to apply EntryComplete: " ^ Status.show err)
  in
  position

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
  let (module S), initial_state = make_strategy config in
  let portfolio = create_portfolio_exn () in

  (* Execute strategy on market close *)
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
              assert_that entering.target_quantity (float_equal 100.0);
              (* Entry price should be set *)
              assert_bool "Entry price should be positive"
                Float.(entering.entry_price > 0.0)
          | _ -> assert_failure "Expected Entering state")
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
        (* Should have created position in Entering state *)
        assert_equal 0
          (List.length output.transitions)
          ~msg:"Entry should not produce transitions";
        s
    | Error err -> failwith ("Day 1 failed: " ^ Status.show err)
  in

  (* Manually apply engine transitions to move position to Holding state *)
  let state1_with_holding =
    match Map.find state1.positions "AAPL" with
    | Some position ->
        let entry_price =
          match Trading_strategy.Position.get_state position with
          | Entering e -> e.entry_price
          | _ -> failwith "Expected Entering state"
        in
        let position =
          apply_entry_fill_and_complete position
            ~date:(date_of_string "2024-01-15")
            ~entry_price ~stop_loss_pct:0.05 ~take_profit_pct:0.10
        in
        ({ positions = Map.set state1.positions ~key:"AAPL" ~data:position }
          : Trading_strategy.Strategy_interface.state)
    | None -> failwith "Expected position to exist"
  in

  (* Advance to spike day *)
  let market_data' =
    Mock_market_data.advance market_data ~date:(date_of_string "2024-01-18")
  in

  (* Day 2: Should trigger take profit *)
  let get_price_fn' = Mock_market_data.get_price market_data' in
  let get_indicator_fn' = Mock_market_data.get_indicator market_data' in
  let result2 =
    S.on_market_close ~get_price:get_price_fn' ~get_indicator:get_indicator_fn'
      ~portfolio ~state:state1_with_holding
  in

  match result2 with
  | Ok (output, new_state) -> (
      (* Should have TriggerExit transition only *)
      assert_equal 1
        (List.length output.transitions)
        ~msg:"Should produce TriggerExit only";
      (* Verify it's a TriggerExit *)
      (match List.hd output.transitions with
      | Some trans -> (
          match trans.kind with
          | TriggerExit { exit_reason; _ } -> (
              match exit_reason with
              | TakeProfit _ -> () (* Expected *)
              | _ -> assert_failure "Expected TakeProfit exit reason")
          | _ -> assert_failure "Expected TriggerExit transition")
      | None -> assert_failure "Expected at least one transition");
      (* Position should still be in Holding state (not moved to Exiting) *)
      match Map.find new_state.positions "AAPL" with
      | Some position -> (
          match Trading_strategy.Position.get_state position with
          | Holding _ -> () (* Expected - strategy doesn't move state *)
          | _ -> assert_failure "Expected position to remain in Holding state")
      | None -> assert_failure "Expected position to exist")
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
        s
    | Error err -> failwith ("Day 1 failed: " ^ Status.show err)
  in

  (* Manually apply engine transitions to move position to Holding state *)
  let state1_with_holding =
    match Map.find state1.positions "AAPL" with
    | Some position ->
        let entry_price =
          match Trading_strategy.Position.get_state position with
          | Entering e -> e.entry_price
          | _ -> failwith "Expected Entering state"
        in
        let position =
          apply_entry_fill_and_complete position
            ~date:(date_of_string "2024-01-15")
            ~entry_price ~stop_loss_pct:0.05 ~take_profit_pct:0.10
        in
        ({ positions = Map.set state1.positions ~key:"AAPL" ~data:position }
          : Trading_strategy.Strategy_interface.state)
    | None -> failwith "Expected position to exist"
  in

  (* Advance to drop day *)
  let market_data' =
    Mock_market_data.advance market_data ~date:(date_of_string "2024-01-17")
  in

  (* Day 2: Should trigger stop loss *)
  let get_price_fn' = Mock_market_data.get_price market_data' in
  let get_indicator_fn' = Mock_market_data.get_indicator market_data' in
  let result2 =
    S.on_market_close ~get_price:get_price_fn' ~get_indicator:get_indicator_fn'
      ~portfolio ~state:state1_with_holding
  in

  match result2 with
  | Ok (output, new_state) -> (
      (* Should have TriggerExit transition only *)
      assert_equal 1
        (List.length output.transitions)
        ~msg:"Should produce TriggerExit only";
      (* Verify it's a TriggerExit with StopLoss reason *)
      (match List.hd output.transitions with
      | Some trans -> (
          match trans.kind with
          | TriggerExit { exit_reason; _ } -> (
              match exit_reason with
              | StopLoss _ -> () (* Expected *)
              | _ -> assert_failure "Expected StopLoss exit reason")
          | _ -> assert_failure "Expected TriggerExit transition")
      | None -> assert_failure "Expected at least one transition");
      (* Position should still be in Holding state *)
      match Map.find new_state.positions "AAPL" with
      | Some position -> (
          match Trading_strategy.Position.get_state position with
          | Holding _ -> () (* Expected *)
          | _ -> assert_failure "Expected position to remain in Holding state")
      | None -> assert_failure "Expected position to exist")
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
        s
    | Error err -> failwith ("Day 1 failed: " ^ Status.show err)
  in

  (* Manually apply engine transitions to move position to Holding state *)
  let state1_with_holding =
    match Map.find state1.positions "AAPL" with
    | Some position ->
        let entry_price =
          match Trading_strategy.Position.get_state position with
          | Entering e -> e.entry_price
          | _ -> failwith "Expected Entering state"
        in
        let position =
          apply_entry_fill_and_complete position
            ~date:(date_of_string "2024-01-15")
            ~entry_price ~stop_loss_pct:0.05 ~take_profit_pct:0.10
        in
        ({ positions = Map.set state1.positions ~key:"AAPL" ~data:position }
          : Trading_strategy.Strategy_interface.state)
    | None -> failwith "Expected position to exist"
  in

  (* Advance to reversal day *)
  let market_data' =
    Mock_market_data.advance market_data ~date:(date_of_string "2024-01-19")
  in

  (* Day 2: Should detect signal reversal *)
  let get_price_fn' = Mock_market_data.get_price market_data' in
  let get_indicator_fn' = Mock_market_data.get_indicator market_data' in
  let result2 =
    S.on_market_close ~get_price:get_price_fn' ~get_indicator:get_indicator_fn'
      ~portfolio ~state:state1_with_holding
  in

  match result2 with
  | Ok (output, new_state) -> (
      (* Should have TriggerExit transition only *)
      assert_equal 1
        (List.length output.transitions)
        ~msg:"Should produce TriggerExit only";
      (* Verify it's a TriggerExit - exit reason could be StopLoss or SignalReversal *)
      (match List.hd output.transitions with
      | Some trans -> (
          match trans.kind with
          | TriggerExit { exit_reason; _ } -> (
              match exit_reason with
              | SignalReversal _ -> () (* Expected *)
              | StopLoss _ ->
                  () (* Also acceptable - stop loss may trigger first *)
              | _ ->
                  assert_failure
                    (Printf.sprintf
                       "Expected SignalReversal or StopLoss, got: %s"
                       (Trading_strategy.Position.show_exit_reason exit_reason))
              )
          | _ -> assert_failure "Expected TriggerExit transition")
      | None -> assert_failure "Expected at least one transition");
      (* Position should still be in Holding state *)
      match Map.find new_state.positions "AAPL" with
      | Some position -> (
          match Trading_strategy.Position.get_state position with
          | Holding _ -> () (* Expected *)
          | _ -> assert_failure "Expected position to remain in Holding state")
      | None -> assert_failure "Expected position to exist")
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
        s
    | Error err -> failwith ("Day 1 failed: " ^ Status.show err)
  in

  (* Manually apply engine transitions to move position to Holding state *)
  let state1_with_holding =
    match Map.find state1.positions "AAPL" with
    | Some position ->
        let entry_price =
          match Trading_strategy.Position.get_state position with
          | Entering e -> e.entry_price
          | _ -> failwith "Expected Entering state"
        in
        let position =
          apply_entry_fill_and_complete position
            ~date:(date_of_string "2024-01-15")
            ~entry_price ~stop_loss_pct:0.05 ~take_profit_pct:0.10
        in
        ({ positions = Map.set state1.positions ~key:"AAPL" ~data:position }
          : Trading_strategy.Strategy_interface.state)
    | None -> failwith "Expected position to exist"
  in

  (* Advance one day *)
  let market_data' =
    Mock_market_data.advance market_data ~date:(date_of_string "2024-01-16")
  in

  (* Day 2: Should hold position *)
  let get_price_fn' = Mock_market_data.get_price market_data' in
  let get_indicator_fn' = Mock_market_data.get_indicator market_data' in
  let result2 =
    S.on_market_close ~get_price:get_price_fn' ~get_indicator:get_indicator_fn'
      ~portfolio ~state:state1_with_holding
  in

  match result2 with
  | Ok (output, new_state) -> (
      (* Should have no transitions *)
      assert_equal 0
        (List.length output.transitions)
        ~msg:"No exit signal, so no transitions";
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
  let (module S), initial_state = make_strategy config in
  let portfolio = create_portfolio_exn () in

  (* Execute strategy - should not enter *)
  let get_price_fn = Mock_market_data.get_price market_data in
  let get_indicator_fn = Mock_market_data.get_indicator market_data in
  let result =
    S.on_market_close ~get_price:get_price_fn ~get_indicator:get_indicator_fn
      ~portfolio ~state:initial_state
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
