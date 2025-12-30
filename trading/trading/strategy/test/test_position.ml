open OUnit2
open Core
open Trading_strategy.Position
open Matchers

let date_of_string s = Date.of_string s

(* Test helpers *)

let make_entering ?(id = "pos-1") ?(symbol = "AAPL") ?(target = 100.0)
    ?(entry_price = 150.0) ?(filled = 0.0) () =
  let pos =
    create_entering ~id ~symbol ~target_quantity:target ~entry_price
      ~created_date:(date_of_string "2024-01-01")
      ~reasoning:(TechnicalSignal { indicator = "EMA"; description = "Test" })
  in
  match pos.state with
  | Entering entering ->
      { pos with state = Entering { entering with filled_quantity = filled } }
  | _ -> failwith "Expected Entering state"

let make_holding ?(id = "pos-1") ?(symbol = "AAPL") ?(quantity = 100.0)
    ?(entry_price = 150.0) () =
  {
    state =
      Holding
        {
          id;
          symbol;
          quantity;
          entry_price;
          entry_date = date_of_string "2024-01-02";
          entry_reasoning =
            TechnicalSignal { indicator = "EMA"; description = "Test" };
          risk_params =
            {
              stop_loss_price = Some 142.5;
              take_profit_price = Some 165.0;
              max_hold_days = Some 30;
            };
        };
    last_updated = date_of_string "2024-01-02";
  }

(* ==================== Creation Tests ==================== *)

let test_create_entering _ =
  let pos =
    create_entering ~id:"pos-1" ~symbol:"AAPL" ~target_quantity:100.0
      ~entry_price:150.0
      ~created_date:(date_of_string "2024-01-01")
      ~reasoning:(TechnicalSignal { indicator = "EMA"; description = "Test" })
  in
  assert_equal "pos-1" (get_id pos);
  assert_equal "AAPL" (get_symbol pos);
  assert_equal false (is_closed pos);
  match get_state pos with
  | Entering entering ->
      assert_that entering.target_quantity (float_equal 100.0);
      assert_that entering.filled_quantity (float_equal 0.0)
  | _ -> assert_failure "Expected Entering state"

(* ==================== Entry Transitions ==================== *)

let test_entry_fill_partial _ =
  let pos = make_entering ~filled:0.0 () in
  let transition =
    EntryFill
      {
        position_id = "pos-1";
        filled_quantity = 50.0;
        fill_price = 150.0;
        fill_date = date_of_string "2024-01-02";
      }
  in
  match apply_transition pos transition with
  | Ok pos' -> (
      match get_state pos' with
      | Entering entering ->
          assert_that entering.filled_quantity (float_equal 50.0)
      | _ -> assert_failure "Expected Entering state")
  | Error err -> assert_failure ("Transition failed: " ^ Status.show err)

let test_entry_fill_multiple _ =
  let pos = make_entering ~filled:50.0 () in
  let transition =
    EntryFill
      {
        position_id = "pos-1";
        filled_quantity = 30.0;
        fill_price = 150.0;
        fill_date = date_of_string "2024-01-02";
      }
  in
  match apply_transition pos transition with
  | Ok pos' -> (
      match get_state pos' with
      | Entering entering ->
          assert_that entering.filled_quantity (float_equal 80.0)
      | _ -> assert_failure "Expected Entering state")
  | Error err -> assert_failure ("Transition failed: " ^ Status.show err)

let test_entry_fill_exceeds_target _ =
  let pos = make_entering ~target:100.0 ~filled:90.0 () in
  let transition =
    EntryFill
      {
        position_id = "pos-1";
        filled_quantity = 20.0;
        fill_price = 150.0;
        fill_date = date_of_string "2024-01-02";
      }
  in
  assert_that (apply_transition pos transition) is_error

let test_entry_complete _ =
  let pos = make_entering ~filled:100.0 () in
  let transition =
    EntryComplete
      {
        position_id = "pos-1";
        risk_params =
          {
            stop_loss_price = Some 142.5;
            take_profit_price = Some 165.0;
            max_hold_days = Some 30;
          };
        completion_date = date_of_string "2024-01-02";
      }
  in
  match apply_transition pos transition with
  | Ok pos' -> (
      match get_state pos' with
      | Holding holding ->
          assert_that holding.quantity (float_equal 100.0);
          assert_that holding.entry_price (float_equal 150.0);
          assert_that holding.risk_params.stop_loss_price
            (is_some_and (float_equal 142.5))
      | _ -> assert_failure "Expected Holding state")
  | Error err -> assert_failure ("Transition failed: " ^ Status.show err)

let test_entry_complete_no_fills _ =
  let pos = make_entering ~filled:0.0 () in
  let transition =
    EntryComplete
      {
        position_id = "pos-1";
        risk_params =
          {
            stop_loss_price = None;
            take_profit_price = None;
            max_hold_days = None;
          };
        completion_date = date_of_string "2024-01-02";
      }
  in
  assert_that (apply_transition pos transition) is_error

let test_cancel_entry_no_fills _ =
  let pos = make_entering ~filled:0.0 () in
  let transition =
    CancelEntry
      {
        position_id = "pos-1";
        reason = "Signal invalidated";
        cancel_date = date_of_string "2024-01-02";
      }
  in
  match apply_transition pos transition with
  | Ok pos' -> (
      assert_that (is_closed pos') (equal_to true);
      match get_state pos' with
      | Closed closed -> assert_that closed.quantity (float_equal 0.0)
      | _ -> assert_failure "Expected Closed state")
  | Error err -> assert_failure ("Transition failed: " ^ Status.show err)

let test_cancel_entry_with_fills _ =
  let pos = make_entering ~filled:50.0 () in
  let transition =
    CancelEntry
      {
        position_id = "pos-1";
        reason = "Signal invalidated";
        cancel_date = date_of_string "2024-01-02";
      }
  in
  assert_that (apply_transition pos transition) is_error

(* ==================== Holding Transitions ==================== *)

let test_trigger_exit _ =
  let pos = make_holding () in
  let transition =
    TriggerExit
      {
        position_id = "pos-1";
        exit_reason =
          TakeProfit
            {
              target_price = 165.0;
              actual_price = 165.5;
              profit_percent = 10.3;
            };
        exit_price = 165.0;
        trigger_date = date_of_string "2024-01-10";
      }
  in
  match apply_transition pos transition with
  | Ok pos' -> (
      match get_state pos' with
      | Exiting exiting -> (
          assert_that exiting.exit_price (float_equal 165.0);
          assert_that exiting.target_quantity (float_equal 100.0);
          match exiting.exit_reason with
          | TakeProfit { profit_percent; _ } ->
              assert_that profit_percent (float_equal 10.3)
          | _ -> assert_failure "Expected TakeProfit reason")
      | _ -> assert_failure "Expected Exiting state")
  | Error err -> assert_failure ("Transition failed: " ^ Status.show err)

let test_update_risk_params _ =
  let pos = make_holding () in
  let new_params =
    {
      stop_loss_price = Some 145.0;
      take_profit_price = Some 170.0;
      max_hold_days = Some 20;
    }
  in
  let transition =
    UpdateRiskParams
      {
        position_id = "pos-1";
        new_risk_params = new_params;
        update_date = date_of_string "2024-01-05";
      }
  in
  match apply_transition pos transition with
  | Ok pos' -> (
      match get_state pos' with
      | Holding holding ->
          assert_that holding.risk_params.stop_loss_price
            (is_some_and (float_equal 145.0))
      | _ -> assert_failure "Expected Holding state")
  | Error err -> assert_failure ("Transition failed: " ^ Status.show err)

(* ==================== Exit Transitions ==================== *)

let test_exit_fill _ =
  let holding_state =
    {
      id = "pos-1";
      symbol = "AAPL";
      quantity = 100.0;
      entry_price = 150.0;
      entry_date = date_of_string "2024-01-02";
      entry_reasoning =
        TechnicalSignal { indicator = "EMA"; description = "Test" };
      risk_params =
        {
          stop_loss_price = Some 142.5;
          take_profit_price = Some 165.0;
          max_hold_days = Some 30;
        };
    }
  in
  let pos =
    {
      state =
        Exiting
          {
            id = "pos-1";
            symbol = "AAPL";
            holding_state;
            exit_reason =
              TakeProfit
                {
                  target_price = 165.0;
                  actual_price = 165.5;
                  profit_percent = 10.3;
                };
            target_quantity = 100.0;
            exit_price = 165.0;
            filled_quantity = 0.0;
            started_date = date_of_string "2024-01-10";
          };
      last_updated = date_of_string "2024-01-10";
    }
  in
  let transition =
    ExitFill
      {
        position_id = "pos-1";
        filled_quantity = 100.0;
        fill_price = 165.5;
        fill_date = date_of_string "2024-01-10";
      }
  in
  match apply_transition pos transition with
  | Ok pos' -> (
      match get_state pos' with
      | Exiting exiting ->
          assert_that exiting.filled_quantity (float_equal 100.0)
      | _ -> assert_failure "Expected Exiting state")
  | Error err -> assert_failure ("Transition failed: " ^ Status.show err)

let test_exit_complete _ =
  let holding_state =
    {
      id = "pos-1";
      symbol = "AAPL";
      quantity = 100.0;
      entry_price = 150.0;
      entry_date = date_of_string "2024-01-02";
      entry_reasoning =
        TechnicalSignal { indicator = "EMA"; description = "Test" };
      risk_params =
        {
          stop_loss_price = Some 142.5;
          take_profit_price = Some 165.0;
          max_hold_days = Some 30;
        };
    }
  in
  let pos =
    {
      state =
        Exiting
          {
            id = "pos-1";
            symbol = "AAPL";
            holding_state;
            exit_reason =
              TakeProfit
                {
                  target_price = 165.0;
                  actual_price = 165.5;
                  profit_percent = 10.3;
                };
            target_quantity = 100.0;
            exit_price = 165.5;
            filled_quantity = 100.0;
            started_date = date_of_string "2024-01-10";
          };
      last_updated = date_of_string "2024-01-10";
    }
  in
  let transition =
    ExitComplete
      { position_id = "pos-1"; completion_date = date_of_string "2024-01-10" }
  in
  match apply_transition pos transition with
  | Ok pos' -> (
      assert_that (is_closed pos') (equal_to true);
      match get_state pos' with
      | Closed closed ->
          assert_that closed.quantity (float_equal 100.0);
          assert_that closed.entry_price (float_equal 150.0);
          assert_that closed.exit_price (float_equal 165.5);
          assert_that closed.gross_pnl (float_equal 1550.0)
      | _ -> assert_failure "Expected Closed state")
  | Error err -> assert_failure ("Transition failed: " ^ Status.show err)

(* ==================== Invalid Transitions ==================== *)

let test_invalid_transition_from_closed _ =
  let pos =
    {
      state =
        Closed
          {
            id = "pos-1";
            symbol = "AAPL";
            quantity = 100.0;
            entry_price = 150.0;
            exit_price = 165.0;
            gross_pnl = 1500.0;
            entry_date = date_of_string "2024-01-02";
            exit_date = date_of_string "2024-01-10";
            days_held = 8;
            entry_reasoning =
              TechnicalSignal { indicator = "EMA"; description = "Test" };
            close_reason =
              TakeProfit
                {
                  target_price = 165.0;
                  actual_price = 165.0;
                  profit_percent = 10.0;
                };
          };
      last_updated = date_of_string "2024-01-10";
    }
  in
  let transition =
    EntryFill
      {
        position_id = "pos-1";
        filled_quantity = 50.0;
        fill_price = 150.0;
        fill_date = date_of_string "2024-01-11";
      }
  in
  assert_that (apply_transition pos transition) is_error

let test_wrong_position_id _ =
  let pos = make_entering () in
  let transition =
    EntryFill
      {
        position_id = "wrong-id";
        filled_quantity = 50.0;
        fill_price = 150.0;
        fill_date = date_of_string "2024-01-02";
      }
  in
  assert_that (apply_transition pos transition) is_error

let test_invalid_state_transition _ =
  let pos = make_holding () in
  let transition =
    EntryFill
      {
        position_id = "pos-1";
        filled_quantity = 50.0;
        fill_price = 150.0;
        fill_date = date_of_string "2024-01-05";
      }
  in
  assert_that (apply_transition pos transition) is_error

(* ==================== Test Suite ==================== *)

let suite =
  "Position State Machine Tests"
  >::: [
         "create entering" >:: test_create_entering;
         "entry fill partial" >:: test_entry_fill_partial;
         "entry fill multiple" >:: test_entry_fill_multiple;
         "entry fill exceeds target" >:: test_entry_fill_exceeds_target;
         "entry complete" >:: test_entry_complete;
         "entry complete no fills" >:: test_entry_complete_no_fills;
         "cancel entry no fills" >:: test_cancel_entry_no_fills;
         "cancel entry with fills" >:: test_cancel_entry_with_fills;
         "trigger exit" >:: test_trigger_exit;
         "update risk params" >:: test_update_risk_params;
         "exit fill" >:: test_exit_fill;
         "exit complete" >:: test_exit_complete;
         "invalid transition from closed"
         >:: test_invalid_transition_from_closed;
         "wrong position id" >:: test_wrong_position_id;
         "invalid state transition" >:: test_invalid_state_transition;
       ]

let () = run_test_tt_main suite
