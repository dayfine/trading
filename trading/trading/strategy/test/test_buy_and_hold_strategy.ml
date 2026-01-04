(** Buy and Hold Strategy Tests - using stateless API with engine pattern *)

open OUnit2
open Core
open Trading_strategy

let date_of_string s = Date.of_string s

(** Helper to unwrap Result *)
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

let apply_transitions positions transitions =
  List.fold transitions ~init:positions ~f:apply_transition

(** ENGINE: Fill and complete entry *)
let engine_fill_and_complete_entry positions date =
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
                        stop_loss_price = None;
                        take_profit_price = None;
                        max_hold_days = None;
                      };
                  };
            }
          in
          fill :: complete :: acc
      | _ -> acc)

(** Test: Buy and hold enters on first day *)
let test_enter_immediately _ =
  let positions = ref String.Map.empty in

  let prices =
    Test_helpers.Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:10 ~base_price:100.0 ~trend:(Uptrend 0.5) ~volatility:0.01
  in
  let market_data =
    Test_helpers.Mock_market_data.create
      ~data:[ ("AAPL", prices) ]
      ~ema_periods:[]
      ~current_date:(date_of_string "2024-01-01")
  in

  let config =
    {
      Buy_and_hold_strategy.symbols = [ "AAPL" ];
      position_size = 100.0;
      entry_date = None;
    }
  in
  let (module S) = Buy_and_hold_strategy.make config in

  let get_price = Test_helpers.Mock_market_data.get_price market_data in
  let output =
    unwrap_result
      (S.on_market_close ~get_price
         ~get_indicator:(fun _ _ _ -> None)
         ~positions:!positions)
      "Strategy execution"
  in

  (* Should produce CreateEntering *)
  assert_equal 1 (List.length output.transitions);
  positions := apply_transitions !positions output.transitions;

  (* Verify Entering state *)
  let pos = Map.find_exn !positions "AAPL" in
  match Position.get_state pos with
  | Entering e -> assert_bool "Quantity" Float.(e.target_quantity = 100.0)
  | _ -> assert_failure "Expected Entering state"

(** Test: Buy and hold enters on specific date *)
let test_enter_on_specific_date _ =
  let positions = ref String.Map.empty in

  let prices =
    Test_helpers.Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:10 ~base_price:100.0 ~trend:(Uptrend 0.5) ~volatility:0.01
  in
  let market_data =
    Test_helpers.Mock_market_data.create
      ~data:[ ("AAPL", prices) ]
      ~ema_periods:[]
      ~current_date:(date_of_string "2024-01-01")
  in

  let config =
    {
      Buy_and_hold_strategy.symbols = [ "AAPL" ];
      position_size = 100.0;
      entry_date = Some (date_of_string "2024-01-05");
    }
  in
  let (module S) = Buy_and_hold_strategy.make config in

  (* Day 1: Should not enter *)
  let get_price = Test_helpers.Mock_market_data.get_price market_data in
  let output =
    unwrap_result
      (S.on_market_close ~get_price
         ~get_indicator:(fun _ _ _ -> None)
         ~positions:!positions)
      "Day 1"
  in
  assert_equal 0 (List.length output.transitions);

  (* Day 5: Should enter *)
  let market_data' =
    Test_helpers.Mock_market_data.advance market_data
      ~date:(date_of_string "2024-01-05")
  in
  let get_price' = Test_helpers.Mock_market_data.get_price market_data' in
  let output =
    unwrap_result
      (S.on_market_close ~get_price:get_price'
         ~get_indicator:(fun _ _ _ -> None)
         ~positions:!positions)
      "Day 5"
  in
  assert_equal 1 (List.length output.transitions);
  positions := apply_transitions !positions output.transitions;

  let pos = Map.find_exn !positions "AAPL" in
  match Position.get_state pos with
  | Entering _ -> ()
  | _ -> assert_failure "Expected Entering state"

(** Test: Holds position indefinitely *)
let test_holds_indefinitely _ =
  let positions = ref String.Map.empty in

  let prices =
    Test_helpers.Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:30 ~base_price:100.0 ~trend:(Uptrend 0.5) ~volatility:0.01
  in
  let market_data =
    Test_helpers.Mock_market_data.create
      ~data:[ ("AAPL", prices) ]
      ~ema_periods:[]
      ~current_date:(date_of_string "2024-01-01")
  in

  let config =
    {
      Buy_and_hold_strategy.symbols = [ "AAPL" ];
      position_size = 100.0;
      entry_date = None;
    }
  in
  let (module S) = Buy_and_hold_strategy.make config in

  (* Day 1: Enter *)
  let get_price = Test_helpers.Mock_market_data.get_price market_data in
  let output =
    unwrap_result
      (S.on_market_close ~get_price
         ~get_indicator:(fun _ _ _ -> None)
         ~positions:!positions)
      "Day 1"
  in
  positions := apply_transitions !positions output.transitions;

  (* Engine fills and completes *)
  let engine_transitions =
    engine_fill_and_complete_entry !positions (date_of_string "2024-01-01")
  in
  positions := apply_transitions !positions engine_transitions;

  (* Day 10, 20, 30: Should hold, no exit *)
  List.iter [ "2024-01-10"; "2024-01-20"; "2024-01-30" ] ~f:(fun date_str ->
      let market_data' =
        Test_helpers.Mock_market_data.advance market_data
          ~date:(date_of_string date_str)
      in
      let get_price' = Test_helpers.Mock_market_data.get_price market_data' in
      let output =
        unwrap_result
          (S.on_market_close ~get_price:get_price'
             ~get_indicator:(fun _ _ _ -> None)
             ~positions:!positions)
          date_str
      in
      (* Should produce no transitions *)
      assert_equal 0 (List.length output.transitions))

(** Test: No entry if already holding *)
let test_no_double_entry _ =
  let positions = ref String.Map.empty in

  let prices =
    Test_helpers.Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:10 ~base_price:100.0 ~trend:(Uptrend 0.5) ~volatility:0.01
  in
  let market_data =
    Test_helpers.Mock_market_data.create
      ~data:[ ("AAPL", prices) ]
      ~ema_periods:[]
      ~current_date:(date_of_string "2024-01-01")
  in

  let config =
    {
      Buy_and_hold_strategy.symbols = [ "AAPL" ];
      position_size = 100.0;
      entry_date = None;
    }
  in
  let (module S) = Buy_and_hold_strategy.make config in

  (* Day 1: Enter *)
  let get_price = Test_helpers.Mock_market_data.get_price market_data in
  let output =
    unwrap_result
      (S.on_market_close ~get_price
         ~get_indicator:(fun _ _ _ -> None)
         ~positions:!positions)
      "Day 1"
  in
  positions := apply_transitions !positions output.transitions;

  (* Day 2: Should not enter again *)
  let market_data' =
    Test_helpers.Mock_market_data.advance market_data
      ~date:(date_of_string "2024-01-02")
  in
  let get_price' = Test_helpers.Mock_market_data.get_price market_data' in
  let output =
    unwrap_result
      (S.on_market_close ~get_price:get_price'
         ~get_indicator:(fun _ _ _ -> None)
         ~positions:!positions)
      "Day 2"
  in
  assert_equal 0 (List.length output.transitions)

let suite =
  "Buy and Hold Strategy Tests"
  >::: [
         "enter immediately" >:: test_enter_immediately;
         "enter on specific date" >:: test_enter_on_specific_date;
         "holds indefinitely" >:: test_holds_indefinitely;
         "no double entry" >:: test_no_double_entry;
       ]

let () = run_test_tt_main suite
