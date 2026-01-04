(** Strategy lifecycle demonstration test

    This test demonstrates the complete lifecycle of a strategy using a minimal
    dummy implementation. It shows: 1. Strategy produces transitions 2.
    Transitions are applied to update positions 3. Positions flow through
    states: Entering -> Holding -> Exiting -> Closed 4. The positions map is
    managed by the test (caller), not the strategy *)

open OUnit2
open Core
open Trading_strategy

let date_of_string s = Date.of_string s

(** Helper to unwrap Result with Status error *)
let unwrap_result result msg =
  match result with
  | Ok value -> value
  | Error err -> failwith (Printf.sprintf "%s: %s" msg (Status.show err))

(** Dummy strategy that produces predetermined transitions for testing *)
module DummyStrategy = struct
  (* Track which day we're on to produce different transitions *)
  let day_counter = ref 0
  let reset () = day_counter := 0
  let name = "DummyLifecycleStrategy" [@@warning "-32"]

  let on_market_close ~get_price:_ ~get_indicator:_ ~positions =
    day_counter := !day_counter + 1;
    let day = !day_counter in

    let transitions =
      match day with
      (* Day 1: Create new position *)
      | 1 ->
          [
            {
              Position.position_id = "TEST-1";
              date = date_of_string "2024-01-01";
              kind =
                CreateEntering
                  {
                    symbol = "TEST";
                    target_quantity = 100.0;
                    entry_price = 50.0;
                    reasoning =
                      TechnicalSignal
                        { indicator = "DUMMY"; description = "Test entry" };
                  };
            };
          ]
      (* Day 2: Fill entry *)
      | 2 ->
          if Map.mem positions "TEST" then
            [
              {
                Position.position_id = "TEST-1";
                date = date_of_string "2024-01-02";
                kind = EntryFill { filled_quantity = 100.0; fill_price = 50.0 };
              };
            ]
          else []
      (* Day 3: Complete entry (move to Holding) *)
      | 3 ->
          if Map.mem positions "TEST" then
            [
              {
                Position.position_id = "TEST-1";
                date = date_of_string "2024-01-03";
                kind =
                  EntryComplete
                    {
                      risk_params =
                        {
                          stop_loss_price = Some 45.0;
                          take_profit_price = Some 60.0;
                          max_hold_days = Some 30;
                        };
                    };
              };
            ]
          else []
      (* Day 4: Trigger exit *)
      | 4 ->
          if Map.mem positions "TEST" then
            [
              {
                Position.position_id = "TEST-1";
                date = date_of_string "2024-01-04";
                kind =
                  TriggerExit
                    {
                      exit_reason =
                        TakeProfit
                          {
                            target_price = 60.0;
                            actual_price = 60.5;
                            profit_percent = 21.0;
                          };
                      exit_price = 60.0;
                    };
              };
            ]
          else []
      (* Day 5: Fill exit *)
      | 5 ->
          if Map.mem positions "TEST" then
            [
              {
                Position.position_id = "TEST-1";
                date = date_of_string "2024-01-05";
                kind = ExitFill { filled_quantity = 100.0; fill_price = 60.5 };
              };
            ]
          else []
      (* Day 6: Complete exit (move to Closed) *)
      | 6 ->
          if Map.mem positions "TEST" then
            [
              {
                Position.position_id = "TEST-1";
                date = date_of_string "2024-01-06";
                kind = ExitComplete;
              };
            ]
          else []
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

(** Test: Complete lifecycle from strategy creation to position closure *)
let test_complete_lifecycle _ =
  (* Reset day counter *)
  DummyStrategy.reset ();

  (* Initial state: empty positions *)
  let positions_day0 = String.Map.empty in

  (* Day 1: Strategy produces CreateEntering *)
  let output_day1 =
    unwrap_result
      (DummyStrategy.on_market_close
         ~get_price:(fun _ -> None)
         ~get_indicator:(fun _ _ _ -> None)
         ~positions:positions_day0)
      "Day 1"
  in
  assert_equal 1 (List.length output_day1.transitions);

  (* Apply transitions -> position created in Entering state *)
  let positions_day1 =
    apply_transitions positions_day0 output_day1.transitions
  in
  assert_equal 1 (Map.length positions_day1);
  let pos_day1 = Map.find_exn positions_day1 "TEST" in
  (match Position.get_state pos_day1 with
  | Entering _ -> ()
  | _ -> assert_failure "Expected Entering state after CreateEntering");

  (* Day 2: Fill entry *)
  let output_day2 =
    unwrap_result
      (DummyStrategy.on_market_close
         ~get_price:(fun _ -> None)
         ~get_indicator:(fun _ _ _ -> None)
         ~positions:positions_day1)
      "Day 2"
  in
  let positions_day2 =
    apply_transitions positions_day1 output_day2.transitions
  in
  let pos_day2 = Map.find_exn positions_day2 "TEST" in
  (match Position.get_state pos_day2 with
  | Entering e ->
      assert_bool "Filled quantity should be 100.0"
        Float.(e.filled_quantity = 100.0)
  | _ -> assert_failure "Expected Entering state after EntryFill");

  (* Day 3: Complete entry -> Holding *)
  let output_day3 =
    unwrap_result
      (DummyStrategy.on_market_close
         ~get_price:(fun _ -> None)
         ~get_indicator:(fun _ _ _ -> None)
         ~positions:positions_day2)
      "Day 3"
  in
  let positions_day3 =
    apply_transitions positions_day2 output_day3.transitions
  in
  let pos_day3 = Map.find_exn positions_day3 "TEST" in
  (match Position.get_state pos_day3 with
  | Holding h ->
      assert_bool "Quantity should be 100.0" Float.(h.quantity = 100.0)
  | _ -> assert_failure "Expected Holding state after EntryComplete");

  (* Day 4: Trigger exit -> Exiting *)
  let output_day4 =
    unwrap_result
      (DummyStrategy.on_market_close
         ~get_price:(fun _ -> None)
         ~get_indicator:(fun _ _ _ -> None)
         ~positions:positions_day3)
      "Day 4"
  in
  let positions_day4 =
    apply_transitions positions_day3 output_day4.transitions
  in
  let pos_day4 = Map.find_exn positions_day4 "TEST" in
  (match Position.get_state pos_day4 with
  | Exiting _ -> ()
  | _ -> assert_failure "Expected Exiting state after TriggerExit");

  (* Day 5: Fill exit *)
  let output_day5 =
    unwrap_result
      (DummyStrategy.on_market_close
         ~get_price:(fun _ -> None)
         ~get_indicator:(fun _ _ _ -> None)
         ~positions:positions_day4)
      "Day 5"
  in
  let positions_day5 =
    apply_transitions positions_day4 output_day5.transitions
  in
  let pos_day5 = Map.find_exn positions_day5 "TEST" in
  (match Position.get_state pos_day5 with
  | Exiting e ->
      assert_bool "Exit filled quantity should be 100.0"
        Float.(e.filled_quantity = 100.0)
  | _ -> assert_failure "Expected Exiting state after ExitFill");

  (* Day 6: Complete exit -> Closed *)
  let output_day6 =
    unwrap_result
      (DummyStrategy.on_market_close
         ~get_price:(fun _ -> None)
         ~get_indicator:(fun _ _ _ -> None)
         ~positions:positions_day5)
      "Day 6"
  in
  let positions_day6 =
    apply_transitions positions_day5 output_day6.transitions
  in
  let pos_day6 = Map.find_exn positions_day6 "TEST" in
  assert_bool "Position should be closed" (Position.is_closed pos_day6);
  match Position.get_state pos_day6 with
  | Closed c ->
      assert_bool "Closed quantity should be 100.0" Float.(c.quantity = 100.0);
      assert_bool "Entry price should be 50.0" Float.(c.entry_price = 50.0);
      (* Exit price comes from TriggerExit (60.0), not fill price (60.5) *)
      assert_bool "Exit price should be 60.0" Float.(c.exit_price = 60.0)
  | _ -> assert_failure "Expected Closed state after ExitComplete"

let suite =
  "Strategy Lifecycle Tests"
  >::: [ "complete lifecycle" >:: test_complete_lifecycle ]

let () = run_test_tt_main suite
