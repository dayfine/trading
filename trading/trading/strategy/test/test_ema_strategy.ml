(** EMA Strategy Tests - using stateless API with engine pattern *)

open OUnit2
open Core
open Trading_strategy

let date_of_string s = Date.of_string s

(** Helper to unwrap Result with Status error *)
let unwrap_result result msg =
  match result with
  | Ok value -> value
  | Error err -> failwith (Printf.sprintf "%s: %s" msg (Status.show err))

(** Apply a transition to positions map *)
let apply_transition positions transition =
  match transition.Position.kind with
  | CreateEntering _ -> (
      match Position.create_entering transition with
      | Ok position ->
          Map.set positions ~key:position.Position.symbol ~data:position
      | Error err ->
          failwith
            (Printf.sprintf "CreateEntering failed: %s" (Status.show err)))
  | _ -> (
      (* Find position by ID and apply transition *)
      let position_opt =
        Map.to_alist positions
        |> List.find_map ~f:(fun (_symbol, pos) ->
               if String.equal pos.Position.id transition.position_id then
                 Some pos
               else None)
      in
      match position_opt with
      | Some position -> (
          match Position.apply_transition position transition with
          | Ok updated_position ->
              Map.set positions ~key:position.symbol ~data:updated_position
          | Error err ->
              failwith
                (Printf.sprintf "Transition failed: %s" (Status.show err)))
      | None ->
          failwith
            (Printf.sprintf "Position not found: %s" transition.position_id))

(** Apply all transitions *)
let apply_transitions positions transitions =
  List.fold transitions ~init:positions ~f:apply_transition

(** ENGINE: Simulate fill and complete for entry *)
let engine_fill_and_complete_entry positions date ~stop_loss_pct
    ~take_profit_pct =
  Map.fold positions ~init:[] ~f:(fun ~key:_ ~data:position acc ->
      match Position.get_state position with
      | Entering entering ->
          let entry_price = entering.entry_price in
          let fill =
            {
              Position.position_id = position.id;
              date;
              kind =
                EntryFill
                  {
                    filled_quantity = entering.target_quantity;
                    fill_price = entry_price;
                  };
            }
          in
          let complete =
            {
              Position.position_id = position.id;
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
          in
          fill :: complete :: acc
      | _ -> acc)

(** Test: Entry when price crosses above EMA *)
let test_entry_signal _ =
  let positions = ref String.Map.empty in

  (* Create uptrend price data *)
  let prices =
    Test_helpers.Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:15 ~base_price:140.0 ~trend:(Uptrend 1.0) ~volatility:0.01
  in
  let market_data =
    Test_helpers.Mock_market_data.create
      ~data:[ ("AAPL", prices) ]
      ~ema_periods:[ 10 ]
      ~current_date:(date_of_string "2024-01-15")
  in

  (* Create strategy *)
  let config =
    {
      Ema_strategy.symbols = [ "AAPL" ];
      ema_period = 10;
      stop_loss_percent = 0.05;
      take_profit_percent = 0.10;
      position_size = 100.0;
    }
  in
  let strategy_module = Ema_strategy.make config in
  let (module S) = strategy_module in

  (* Execute strategy *)
  let get_price = Test_helpers.Mock_market_data.get_price market_data in
  let get_indicator = Test_helpers.Mock_market_data.get_indicator market_data in
  let output =
    unwrap_result
      (S.on_market_close ~get_price ~get_indicator ~positions:!positions)
      "Strategy execution"
  in

  (* Should produce CreateEntering *)
  assert_equal 1 (List.length output.transitions);
  positions := apply_transitions !positions output.transitions;

  (* Should have position in Entering state *)
  let pos = Map.find_exn !positions "AAPL" in
  match Position.get_state pos with
  | Entering e ->
      assert_bool "Target quantity" Float.(e.target_quantity = 100.0)
  | _ -> assert_failure "Expected Entering state"

(** Test: Take profit exit *)
let test_take_profit _ =
  let positions = ref String.Map.empty in

  (* Create price data with spike *)
  let prices =
    Test_helpers.Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:20 ~base_price:100.0 ~trend:(Uptrend 0.5) ~volatility:0.01
  in
  let market_data =
    Test_helpers.Mock_market_data.create
      ~data:[ ("AAPL", prices) ]
      ~ema_periods:[ 10 ]
      ~current_date:(date_of_string "2024-01-15")
  in

  let config =
    {
      Ema_strategy.symbols = [ "AAPL" ];
      ema_period = 10;
      stop_loss_percent = 0.05;
      take_profit_percent = 0.10;
      position_size = 100.0;
    }
  in
  let (module S) = Ema_strategy.make config in

  (* Day 1: Enter *)
  let get_price = Test_helpers.Mock_market_data.get_price market_data in
  let get_indicator = Test_helpers.Mock_market_data.get_indicator market_data in
  let output =
    unwrap_result
      (S.on_market_close ~get_price ~get_indicator ~positions:!positions)
      "Day 1"
  in
  positions := apply_transitions !positions output.transitions;

  (* Engine fills and completes entry *)
  let engine_transitions =
    engine_fill_and_complete_entry !positions
      (date_of_string "2024-01-15")
      ~stop_loss_pct:0.05 ~take_profit_pct:0.10
  in
  positions := apply_transitions !positions engine_transitions;

  (* Verify Holding *)
  let pos = Map.find_exn !positions "AAPL" in
  (match Position.get_state pos with
  | Holding _ -> ()
  | _ -> assert_failure "Expected Holding state");

  (* Day 2: Price rises to trigger take profit *)
  (* Create new prices with 12% increase *)
  let prices_with_spike =
    Test_helpers.Price_generators.with_spike prices
      ~spike_date:(date_of_string "2024-01-18")
      ~spike_percent:12.0
  in
  let market_data' =
    Test_helpers.Mock_market_data.create
      ~data:[ ("AAPL", prices_with_spike) ]
      ~ema_periods:[ 10 ]
      ~current_date:(date_of_string "2024-01-18")
  in
  let get_price' = Test_helpers.Mock_market_data.get_price market_data' in
  let get_indicator' =
    Test_helpers.Mock_market_data.get_indicator market_data'
  in
  let output =
    unwrap_result
      (S.on_market_close ~get_price:get_price' ~get_indicator:get_indicator'
         ~positions:!positions)
      "Day 2"
  in

  (* Should produce TriggerExit with TakeProfit *)
  assert_equal 1 (List.length output.transitions);
  match List.hd_exn output.transitions with
  | { kind = TriggerExit { exit_reason = TakeProfit _; _ }; _ } -> ()
  | _ -> assert_failure "Expected TriggerExit with TakeProfit"

(** Test: Stop loss exit *)
let test_stop_loss _ =
  let positions = ref String.Map.empty in

  let prices =
    Test_helpers.Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:20 ~base_price:100.0 ~trend:(Uptrend 0.5) ~volatility:0.01
  in
  let market_data =
    Test_helpers.Mock_market_data.create
      ~data:[ ("AAPL", prices) ]
      ~ema_periods:[ 10 ]
      ~current_date:(date_of_string "2024-01-15")
  in

  let config =
    {
      Ema_strategy.symbols = [ "AAPL" ];
      ema_period = 10;
      stop_loss_percent = 0.05;
      take_profit_percent = 0.10;
      position_size = 100.0;
    }
  in
  let (module S) = Ema_strategy.make config in

  (* Day 1: Enter *)
  let get_price = Test_helpers.Mock_market_data.get_price market_data in
  let get_indicator = Test_helpers.Mock_market_data.get_indicator market_data in
  let output =
    unwrap_result
      (S.on_market_close ~get_price ~get_indicator ~positions:!positions)
      "Day 1"
  in
  positions := apply_transitions !positions output.transitions;

  (* Engine fills and completes *)
  let engine_transitions =
    engine_fill_and_complete_entry !positions
      (date_of_string "2024-01-15")
      ~stop_loss_pct:0.05 ~take_profit_pct:0.10
  in
  positions := apply_transitions !positions engine_transitions;

  (* Day 2: Price drops to trigger stop loss (need >5% drop) *)
  let prices_with_drop =
    Test_helpers.Price_generators.with_spike prices
      ~spike_date:(date_of_string "2024-01-17")
      ~spike_percent:(-10.0)
  in
  let market_data' =
    Test_helpers.Mock_market_data.create
      ~data:[ ("AAPL", prices_with_drop) ]
      ~ema_periods:[ 10 ]
      ~current_date:(date_of_string "2024-01-17")
  in
  let get_price' = Test_helpers.Mock_market_data.get_price market_data' in
  let get_indicator' =
    Test_helpers.Mock_market_data.get_indicator market_data'
  in
  let output =
    unwrap_result
      (S.on_market_close ~get_price:get_price' ~get_indicator:get_indicator'
         ~positions:!positions)
      "Day 2"
  in

  (* Should produce TriggerExit with StopLoss *)
  assert_equal 1 (List.length output.transitions);
  match List.hd_exn output.transitions with
  | { kind = TriggerExit { exit_reason = StopLoss _; _ }; _ } -> ()
  | _ -> assert_failure "Expected TriggerExit with StopLoss"

(** Test: No entry when price is below EMA *)
let test_no_entry_below_ema _ =
  let positions = ref String.Map.empty in

  (* Downtrend - price stays below EMA *)
  let prices =
    Test_helpers.Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:15 ~base_price:150.0 ~trend:(Downtrend 1.0) ~volatility:0.01
  in
  let market_data =
    Test_helpers.Mock_market_data.create
      ~data:[ ("AAPL", prices) ]
      ~ema_periods:[ 10 ]
      ~current_date:(date_of_string "2024-01-15")
  in

  let config =
    {
      Ema_strategy.symbols = [ "AAPL" ];
      ema_period = 10;
      stop_loss_percent = 0.05;
      take_profit_percent = 0.10;
      position_size = 100.0;
    }
  in
  let (module S) = Ema_strategy.make config in

  let get_price = Test_helpers.Mock_market_data.get_price market_data in
  let get_indicator = Test_helpers.Mock_market_data.get_indicator market_data in
  let output =
    unwrap_result
      (S.on_market_close ~get_price ~get_indicator ~positions:!positions)
      "Strategy execution"
  in

  (* Should produce no transitions *)
  assert_equal 0 (List.length output.transitions);
  assert_bool "No position" (Map.is_empty !positions)

let suite =
  "EMA Strategy Tests"
  >::: [
         "entry signal" >:: test_entry_signal;
         "take profit" >:: test_take_profit;
         "stop loss" >:: test_stop_loss;
         "no entry below ema" >:: test_no_entry_below_ema;
       ]

let () = run_test_tt_main suite
