(** Strategy lifecycle demonstration test

    This test demonstrates the complete lifecycle with proper separation of
    concerns:

    - STRATEGY: Makes decisions (when to enter/exit) based on market data and
      positions. Produces CreateEntering and TriggerExit transitions.

    - ENGINE (test scope): Maintains positions state, simulates order fills,
      produces EntryFill/EntryComplete and ExitFill/ExitComplete transitions.

    The flow: 1. Strategy sees market conditions -> produces CreateEntering 2.
    Engine creates position in Entering state 3. Engine simulates fill ->
    produces EntryFill 4. Engine completes entry -> produces EntryComplete
    (Entering -> Holding) 5. Strategy sees Holding position + price target hit
    -> produces TriggerExit 6. Engine simulates fill -> produces ExitFill 7.
    Engine completes exit -> produces ExitComplete (Exiting -> Closed) *)

open OUnit2
open Core
open Trading_strategy

let date_of_string s = Date.of_string s

(** Helper to unwrap Result with Status error *)
let unwrap_result result msg =
  match result with
  | Ok value -> value
  | Error err -> failwith (Printf.sprintf "%s: %s" msg (Status.show err))

(** Dummy strategy that makes entry/exit decisions based on price *)
module DummyStrategy = struct
  let name = "DummyDecisionStrategy" [@@warning "-32"]
  let position_counter = ref 0

  let on_market_close ~get_price ~get_indicator:_ ~positions =
    let transitions =
      (* Check if we should enter: no position and price is 50.0 *)
      match (Map.find positions "TEST", get_price "TEST") with
      | None, Some price when Float.(price.Types.Daily_price.close_price = 50.0)
        ->
          position_counter := !position_counter + 1;
          [
            {
              Position.position_id = Printf.sprintf "TEST-%d" !position_counter;
              date = price.Types.Daily_price.date;
              kind =
                CreateEntering
                  {
                    symbol = "TEST";
                    target_quantity = 100.0;
                    entry_price = 50.0;
                    reasoning =
                      TechnicalSignal
                        {
                          indicator = "PRICE";
                          description = "Entry at target price";
                        };
                  };
            };
          ]
      (* Check if we should exit: in Holding and price >= 60.0 *)
      | Some position, Some price -> (
          match Position.get_state position with
          | Holding holding
            when Float.(price.Types.Daily_price.close_price >= 60.0) ->
              let current_price = price.Types.Daily_price.close_price in
              let profit_pct =
                (current_price -. holding.entry_price)
                /. holding.entry_price *. 100.0
              in
              [
                {
                  Position.position_id = position.id;
                  date = price.Types.Daily_price.date;
                  kind =
                    TriggerExit
                      {
                        exit_reason =
                          TakeProfit
                            {
                              target_price = 60.0;
                              actual_price = current_price;
                              profit_percent = profit_pct;
                            };
                        exit_price = 60.0;
                      };
                };
              ]
          | _ -> [])
      | _ -> []
    in
    Result.return { Strategy_interface.transitions }
end

(** Apply a CreateEntering transition by creating the position *)
let apply_create_entering positions transition =
  match transition.Position.kind with
  | CreateEntering _ -> (
      match Position.create_entering transition with
      | Ok position ->
          Map.set positions ~key:position.Position.symbol ~data:position
      | Error err ->
          failwith
            (Printf.sprintf "CreateEntering failed: %s" (Status.show err)))
  | _ -> positions

(** Apply a transition to an existing position *)
let apply_to_existing positions transition =
  match transition.Position.kind with
  | CreateEntering _ -> apply_create_entering positions transition
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
              (* Update in map by symbol *)
              Map.set positions ~key:position.symbol ~data:updated_position
          | Error err ->
              failwith
                (Printf.sprintf "Transition failed: %s" (Status.show err)))
      | None ->
          failwith
            (Printf.sprintf "Position not found: %s" transition.position_id))

(** Apply all transitions to positions map *)
let apply_transitions positions transitions =
  List.fold transitions ~init:positions ~f:apply_to_existing

(** ENGINE: Simulate order fills for Entering positions *)
let engine_fill_entry_orders positions date =
  Map.fold positions ~init:[] ~f:(fun ~key:_ ~data:position acc ->
      match Position.get_state position with
      | Entering entering ->
          (* Simulate immediate fill at entry price *)
          let fill_transition =
            {
              Position.position_id = position.id;
              date;
              kind =
                EntryFill
                  {
                    filled_quantity = entering.target_quantity;
                    fill_price = entering.entry_price;
                  };
            }
          in
          fill_transition :: acc
      | _ -> acc)

(** ENGINE: Complete filled entries (move Entering -> Holding) *)
let engine_complete_entries positions date =
  Map.fold positions ~init:[] ~f:(fun ~key:_ ~data:position acc ->
      match Position.get_state position with
      | Entering e when Float.(e.filled_quantity = e.target_quantity) ->
          (* Entry is fully filled, complete it *)
          let complete_transition =
            {
              Position.position_id = position.id;
              date;
              kind =
                EntryComplete
                  {
                    risk_params =
                      {
                        stop_loss_price = Some (e.entry_price *. 0.9);
                        take_profit_price = Some (e.entry_price *. 1.2);
                        max_hold_days = Some 30;
                      };
                  };
            }
          in
          complete_transition :: acc
      | _ -> acc)

(** ENGINE: Simulate order fills for Exiting positions *)
let engine_fill_exit_orders positions date =
  Map.fold positions ~init:[] ~f:(fun ~key:_ ~data:position acc ->
      match Position.get_state position with
      | Exiting exiting ->
          (* Simulate immediate fill at exit price *)
          let fill_transition =
            {
              Position.position_id = position.id;
              date;
              kind =
                ExitFill
                  {
                    filled_quantity = exiting.quantity;
                    fill_price = exiting.exit_price;
                  };
            }
          in
          fill_transition :: acc
      | _ -> acc)

(** ENGINE: Complete filled exits (move Exiting -> Closed) *)
let engine_complete_exits positions date =
  Map.fold positions ~init:[] ~f:(fun ~key:_ ~data:position acc ->
      match Position.get_state position with
      | Exiting e when Float.(e.filled_quantity = e.target_quantity) ->
          (* Exit is fully filled, complete it *)
          let complete_transition =
            { Position.position_id = position.id; date; kind = ExitComplete }
          in
          complete_transition :: acc
      | _ -> acc)

(** Test: Complete lifecycle with strategy making decisions and engine filling
    orders *)
let test_complete_lifecycle _ =
  (* ENGINE maintains positions state *)
  let positions = ref String.Map.empty in

  (* Day 1: Price = 50.0, no position *)
  let price_day1 =
    {
      Types.Daily_price.date = date_of_string "2024-01-01";
      open_price = 50.0;
      high_price = 51.0;
      low_price = 49.0;
      close_price = 50.0;
      volume = 1000;
      adjusted_close = 50.0;
    }
  in

  (* STRATEGY decides to enter *)
  let strategy_output =
    unwrap_result
      (DummyStrategy.on_market_close
         ~get_price:(fun sym ->
           if String.equal sym "TEST" then Some price_day1 else None)
         ~get_indicator:(fun _ _ _ _ -> None)
         ~positions:!positions)
      "Strategy day 1"
  in
  assert_equal 1 (List.length strategy_output.transitions);

  (* ENGINE creates position from CreateEntering *)
  positions := apply_transitions !positions strategy_output.transitions;
  assert_equal 1 (Map.length !positions);
  let pos = Map.find_exn !positions "TEST" in
  (match Position.get_state pos with
  | Entering _ -> ()
  | _ -> assert_failure "Expected Entering after CreateEntering");

  (* ENGINE fills entry order *)
  let engine_fills =
    engine_fill_entry_orders !positions (date_of_string "2024-01-01")
  in
  assert_equal 1 (List.length engine_fills);
  positions := apply_transitions !positions engine_fills;

  (* ENGINE completes entry -> Holding *)
  let engine_completes =
    engine_complete_entries !positions (date_of_string "2024-01-01")
  in
  assert_equal 1 (List.length engine_completes);
  positions := apply_transitions !positions engine_completes;

  let pos = Map.find_exn !positions "TEST" in
  (match Position.get_state pos with
  | Holding h ->
      assert_bool "Should be holding 100 shares" Float.(h.quantity = 100.0)
  | _ -> assert_failure "Expected Holding after EntryComplete");

  (* Day 2: Price = 60.0, position in Holding *)
  let price_day2 =
    {
      Types.Daily_price.date = date_of_string "2024-01-02";
      open_price = 60.0;
      high_price = 61.0;
      low_price = 59.0;
      close_price = 60.0;
      volume = 1000;
      adjusted_close = 60.0;
    }
  in

  (* STRATEGY decides to exit (price hit target) *)
  let strategy_output =
    unwrap_result
      (DummyStrategy.on_market_close
         ~get_price:(fun sym ->
           if String.equal sym "TEST" then Some price_day2 else None)
         ~get_indicator:(fun _ _ _ _ -> None)
         ~positions:!positions)
      "Strategy day 2"
  in
  assert_equal 1 (List.length strategy_output.transitions);

  (* Apply TriggerExit -> Exiting *)
  positions := apply_transitions !positions strategy_output.transitions;
  let pos = Map.find_exn !positions "TEST" in
  (match Position.get_state pos with
  | Exiting _ -> ()
  | _ -> assert_failure "Expected Exiting after TriggerExit");

  (* ENGINE fills exit order *)
  let engine_fills =
    engine_fill_exit_orders !positions (date_of_string "2024-01-02")
  in
  assert_equal 1 (List.length engine_fills);
  positions := apply_transitions !positions engine_fills;

  (* ENGINE completes exit -> Closed *)
  let engine_completes =
    engine_complete_exits !positions (date_of_string "2024-01-02")
  in
  assert_equal 1 (List.length engine_completes);
  positions := apply_transitions !positions engine_completes;

  let pos = Map.find_exn !positions "TEST" in
  assert_bool "Position should be closed" (Position.is_closed pos);
  match Position.get_state pos with
  | Closed c ->
      assert_bool "Closed quantity should be 100.0" Float.(c.quantity = 100.0);
      assert_bool "Entry price should be 50.0" Float.(c.entry_price = 50.0);
      assert_bool "Exit price should be 60.0" Float.(c.exit_price = 60.0)
  | _ -> assert_failure "Expected Closed after ExitComplete"

let suite =
  "Strategy Lifecycle Tests"
  >::: [ "complete lifecycle" >:: test_complete_lifecycle ]

let () = run_test_tt_main suite
