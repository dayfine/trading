open OUnit2
open Core
open Trading_strategy.Position
open Matchers

let date_of_string s = Date.of_string s

(* Test helpers *)

let make_entering ?(id = "pos-1") ?(symbol = "AAPL") ?(target = 100.0)
    ?(entry_price = 150.0) () =
  let transition =
    {
      position_id = id;
      date = date_of_string "2024-01-01";
      kind =
        CreateEntering
          {
            symbol;
            target_quantity = target;
            entry_price;
            reasoning =
              TechnicalSignal { indicator = "EMA"; description = "Test" };
          };
    }
  in
  match create_entering transition with
  | Ok pos -> pos
  | Error err -> failwith ("Failed to create entering: " ^ Status.show err)

let apply_entry_fill pos ~filled_quantity =
  let transition =
    {
      position_id = pos.id;
      date = date_of_string "2024-01-01";
      kind = EntryFill { filled_quantity; fill_price = 150.0 };
    }
  in
  match apply_transition pos transition with
  | Ok pos' -> pos'
  | Error err -> failwith ("Failed to apply fill: " ^ Status.show err)

let make_holding ?(id = "pos-1") ?(symbol = "AAPL") ?(quantity = 100.0)
    ?(entry_price = 150.0) () =
  {
    id;
    symbol;
    entry_reasoning =
      TechnicalSignal { indicator = "EMA"; description = "Test" };
    exit_reason = None;
    state =
      Holding
        {
          quantity;
          entry_price;
          entry_date = date_of_string "2024-01-02";
          risk_params =
            {
              stop_loss_price = Some 142.5;
              take_profit_price = Some 165.0;
              max_hold_days = Some 30;
            };
        };
    last_updated = date_of_string "2024-01-02";
    portfolio_lot_ids = [];
  }

(* ==================== Creation Tests ==================== *)

let test_create_entering _ =
  let transition =
    {
      position_id = "pos-1";
      date = date_of_string "2024-01-01";
      kind =
        CreateEntering
          {
            symbol = "AAPL";
            target_quantity = 100.0;
            entry_price = 150.0;
            reasoning =
              TechnicalSignal { indicator = "EMA"; description = "Test" };
          };
    }
  in
  assert_that
    (create_entering transition)
    (is_ok_and_holds (fun pos ->
         assert_that pos
           (equal_to
              ({
                 id = "pos-1";
                 symbol = "AAPL";
                 entry_reasoning =
                   TechnicalSignal { indicator = "EMA"; description = "Test" };
                 exit_reason = None;
                 state =
                   Entering
                     {
                       target_quantity = 100.0;
                       entry_price = 150.0;
                       filled_quantity = 0.0;
                       created_date = date_of_string "2024-01-01";
                     };
                 last_updated = date_of_string "2024-01-01";
                 portfolio_lot_ids = [];
               }
                : t))))

(* ==================== Entry Transitions ==================== *)

let test_entry_fill_partial _ =
  let pos = make_entering () in
  let transition =
    {
      position_id = "pos-1";
      date = date_of_string "2024-01-02";
      kind = EntryFill { filled_quantity = 50.0; fill_price = 150.0 };
    }
  in
  assert_that
    (apply_transition pos transition)
    (is_ok_and_holds (fun pos' ->
         match get_state pos' with
         | Entering entering ->
             assert_that entering.filled_quantity (float_equal 50.0)
         | _ -> assert_failure "Expected Entering state"))

let test_entry_fill_multiple _ =
  let pos = make_entering () in
  let pos = apply_entry_fill pos ~filled_quantity:50.0 in
  let transition =
    {
      position_id = "pos-1";
      date = date_of_string "2024-01-02";
      kind = EntryFill { filled_quantity = 30.0; fill_price = 150.0 };
    }
  in
  assert_that
    (apply_transition pos transition)
    (is_ok_and_holds (fun pos' ->
         match get_state pos' with
         | Entering entering ->
             assert_that entering.filled_quantity (float_equal 80.0)
         | _ -> assert_failure "Expected Entering state"))

let test_entry_fill_exceeds_target _ =
  let pos = make_entering ~target:100.0 () in
  let pos = apply_entry_fill pos ~filled_quantity:90.0 in
  let transition =
    {
      position_id = "pos-1";
      date = date_of_string "2024-01-02";
      kind = EntryFill { filled_quantity = 20.0; fill_price = 150.0 };
    }
  in
  assert_that
    (apply_transition pos transition)
    (is_error_with Status.Invalid_argument ~msg:"exceeds target")

let test_entry_fill_multiple_validation_errors _ =
  let pos = make_entering ~target:100.0 () in
  let pos = apply_entry_fill pos ~filled_quantity:90.0 in
  let transition =
    {
      position_id = "pos-1";
      date = date_of_string "2024-01-02";
      kind = EntryFill { filled_quantity = 20.0; fill_price = -10.0 };
    }
  in
  let result = apply_transition pos transition in
  assert_that result
    (is_error_with Status.Invalid_argument ~msg:"fill_price must be positive");
  assert_that result
    (is_error_with Status.Invalid_argument ~msg:"exceeds target")

let test_entry_complete _ =
  let pos = make_entering () in
  let pos = apply_entry_fill pos ~filled_quantity:100.0 in
  let transition =
    {
      position_id = "pos-1";
      date = date_of_string "2024-01-02";
      kind =
        EntryComplete
          {
            risk_params =
              {
                stop_loss_price = Some 142.5;
                take_profit_price = Some 165.0;
                max_hold_days = Some 30;
              };
          };
    }
  in
  assert_that
    (apply_transition pos transition)
    (is_ok_and_holds (fun pos' ->
         assert_that (get_state pos')
           (equal_to
              (Holding
                 {
                   quantity = 100.0;
                   entry_price = 150.0;
                   entry_date = date_of_string "2024-01-02";
                   risk_params =
                     {
                       stop_loss_price = Some 142.5;
                       take_profit_price = Some 165.0;
                       max_hold_days = Some 30;
                     };
                 }
                : position_state))))

let test_entry_complete_no_fills _ =
  let pos = make_entering () in
  let transition =
    {
      position_id = "pos-1";
      date = date_of_string "2024-01-02";
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
  assert_that
    (apply_transition pos transition)
    (is_error_with Status.Invalid_argument ~msg:"no fills")

let test_cancel_entry_no_fills _ =
  let pos = make_entering () in
  let transition =
    {
      position_id = "pos-1";
      date = date_of_string "2024-01-02";
      kind = CancelEntry { reason = "Signal invalidated" };
    }
  in
  assert_that
    (apply_transition pos transition)
    (is_ok_and_holds (fun pos' ->
         assert_that (is_closed pos') (equal_to true);
         match get_state pos' with
         | Closed closed -> assert_that closed.quantity (float_equal 0.0)
         | _ -> assert_failure "Expected Closed state"))

let test_cancel_entry_with_fills _ =
  let pos = make_entering () in
  let pos = apply_entry_fill pos ~filled_quantity:50.0 in
  let transition =
    {
      position_id = "pos-1";
      date = date_of_string "2024-01-02";
      kind = CancelEntry { reason = "Signal invalidated" };
    }
  in
  assert_that
    (apply_transition pos transition)
    (is_error_with Status.Invalid_argument ~msg:"after fills occurred")

(* ==================== Holding Transitions ==================== *)

let test_trigger_exit _ =
  let pos = make_holding () in
  let transition =
    {
      position_id = "pos-1";
      date = date_of_string "2024-01-10";
      kind =
        TriggerExit
          {
            exit_reason =
              TakeProfit
                {
                  target_price = 165.0;
                  actual_price = 165.5;
                  profit_percent = 10.3;
                };
            exit_price = 165.0;
          };
    }
  in
  assert_that
    (apply_transition pos transition)
    (is_ok_and_holds (fun pos' ->
         assert_that (get_state pos')
           (equal_to
              (Exiting
                 {
                   quantity = 100.0;
                   entry_price = 150.0;
                   entry_date = date_of_string "2024-01-02";
                   target_quantity = 100.0;
                   exit_price = 165.0;
                   filled_quantity = 0.0;
                   started_date = date_of_string "2024-01-10";
                 }
                : position_state));
         assert_that pos'.exit_reason
           (is_some_and
              (equal_to
                 (TakeProfit
                    {
                      target_price = 165.0;
                      actual_price = 165.5;
                      profit_percent = 10.3;
                    }
                   : exit_reason)))))

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
    {
      position_id = "pos-1";
      date = date_of_string "2024-01-05";
      kind = UpdateRiskParams { new_risk_params = new_params };
    }
  in
  assert_that
    (apply_transition pos transition)
    (is_ok_and_holds (fun pos' ->
         assert_that (get_state pos')
           (equal_to
              (Holding
                 {
                   quantity = 100.0;
                   entry_price = 150.0;
                   entry_date = date_of_string "2024-01-02";
                   risk_params = new_params;
                 }
                : position_state))))

(* ==================== Exit Transitions ==================== *)

let test_exit_fill _ =
  let pos =
    {
      id = "pos-1";
      symbol = "AAPL";
      entry_reasoning =
        TechnicalSignal { indicator = "EMA"; description = "Test" };
      exit_reason =
        Some
          (TakeProfit
             {
               target_price = 165.0;
               actual_price = 165.5;
               profit_percent = 10.3;
             });
      state =
        Exiting
          {
            quantity = 100.0;
            entry_price = 150.0;
            entry_date = date_of_string "2024-01-02";
            target_quantity = 100.0;
            exit_price = 165.0;
            filled_quantity = 0.0;
            started_date = date_of_string "2024-01-10";
          };
      last_updated = date_of_string "2024-01-10";
      portfolio_lot_ids = [];
    }
  in
  let transition =
    {
      position_id = "pos-1";
      date = date_of_string "2024-01-10";
      kind = ExitFill { filled_quantity = 100.0; fill_price = 165.5 };
    }
  in
  assert_that
    (apply_transition pos transition)
    (is_ok_and_holds (fun pos' ->
         assert_that (get_state pos')
           (equal_to
              (Exiting
                 {
                   quantity = 100.0;
                   entry_price = 150.0;
                   entry_date = date_of_string "2024-01-02";
                   target_quantity = 100.0;
                   exit_price = 165.0;
                   filled_quantity = 100.0;
                   started_date = date_of_string "2024-01-10";
                 }
                : position_state))))

let test_exit_complete _ =
  let pos =
    {
      id = "pos-1";
      symbol = "AAPL";
      entry_reasoning =
        TechnicalSignal { indicator = "EMA"; description = "Test" };
      exit_reason =
        Some
          (TakeProfit
             {
               target_price = 165.0;
               actual_price = 165.5;
               profit_percent = 10.3;
             });
      state =
        Exiting
          {
            quantity = 100.0;
            entry_price = 150.0;
            entry_date = date_of_string "2024-01-02";
            target_quantity = 100.0;
            exit_price = 165.5;
            filled_quantity = 100.0;
            started_date = date_of_string "2024-01-10";
          };
      last_updated = date_of_string "2024-01-10";
      portfolio_lot_ids = [];
    }
  in
  let transition =
    {
      position_id = "pos-1";
      date = date_of_string "2024-01-10";
      kind = ExitComplete;
    }
  in
  assert_that
    (apply_transition pos transition)
    (is_ok_and_holds (fun pos' ->
         assert_that (is_closed pos') (equal_to true);
         assert_that (get_state pos')
           (equal_to
              (Closed
                 {
                   quantity = 100.0;
                   entry_price = 150.0;
                   exit_price = 165.5;
                   gross_pnl = None;
                   entry_date = date_of_string "2024-01-02";
                   exit_date = date_of_string "2024-01-10";
                   days_held = 8;
                 }
                : position_state))))

(* ==================== Invalid Transitions ==================== *)

let test_invalid_transition_from_closed _ =
  let pos =
    {
      id = "pos-1";
      symbol = "AAPL";
      entry_reasoning =
        TechnicalSignal { indicator = "EMA"; description = "Test" };
      exit_reason = None;
      state =
        Closed
          {
            quantity = 100.0;
            entry_price = 150.0;
            exit_price = 165.0;
            gross_pnl = None;
            entry_date = date_of_string "2024-01-02";
            exit_date = date_of_string "2024-01-10";
            days_held = 8;
          };
      last_updated = date_of_string "2024-01-10";
      portfolio_lot_ids = [];
    }
  in
  let transition =
    {
      position_id = "pos-1";
      date = date_of_string "2024-01-11";
      kind = EntryFill { filled_quantity = 50.0; fill_price = 150.0 };
    }
  in
  assert_that
    (apply_transition pos transition)
    (is_error_with Status.Invalid_argument ~msg:"closed position")

let test_wrong_position_id _ =
  let pos = make_entering () in
  let transition =
    {
      position_id = "wrong-id";
      date = date_of_string "2024-01-02";
      kind = EntryFill { filled_quantity = 50.0; fill_price = 150.0 };
    }
  in
  assert_that
    (apply_transition pos transition)
    (is_error_with Status.Invalid_argument ~msg:"ID mismatch")

let test_invalid_state_transition _ =
  let pos = make_holding () in
  let transition =
    {
      position_id = "pos-1";
      date = date_of_string "2024-01-05";
      kind = EntryFill { filled_quantity = 50.0; fill_price = 150.0 };
    }
  in
  assert_that
    (apply_transition pos transition)
    (is_error_with Status.Invalid_argument ~msg:"Invalid transition")

(* ==================== CreateEntering Transition Tests ==================== *)

(** Test: CreateEntering transition contains all required data *)
let test_create_entering_transition_structure _ =
  let transition =
    {
      position_id = "AAPL-1";
      date = date_of_string "2024-01-01";
      kind =
        CreateEntering
          {
            symbol = "AAPL";
            target_quantity = 100.0;
            entry_price = 150.0;
            reasoning =
              TechnicalSignal
                { indicator = "EMA"; description = "Price crossed above EMA" };
          };
    }
  in
  assert_that transition
    (equal_to
       ({
          position_id = "AAPL-1";
          date = date_of_string "2024-01-01";
          kind =
            CreateEntering
              {
                symbol = "AAPL";
                target_quantity = 100.0;
                entry_price = 150.0;
                reasoning =
                  TechnicalSignal
                    {
                      indicator = "EMA";
                      description = "Price crossed above EMA";
                    };
              };
        }
         : transition))

(** Test: CreateEntering can be used to create a position *)
let test_create_entering_creates_position _ =
  let transition =
    {
      position_id = "AAPL-1";
      date = date_of_string "2024-01-01";
      kind =
        CreateEntering
          {
            symbol = "AAPL";
            target_quantity = 100.0;
            entry_price = 150.0;
            reasoning = ManualDecision { description = "Buy and hold" };
          };
    }
  in
  assert_that
    (create_entering transition)
    (is_ok_and_holds (fun pos ->
         assert_that pos
           (equal_to
              ({
                 id = "AAPL-1";
                 symbol = "AAPL";
                 entry_reasoning =
                   ManualDecision { description = "Buy and hold" };
                 exit_reason = None;
                 state =
                   Entering
                     {
                       target_quantity = 100.0;
                       entry_price = 150.0;
                       filled_quantity = 0.0;
                       created_date = date_of_string "2024-01-01";
                     };
                 last_updated = date_of_string "2024-01-01";
                 portfolio_lot_ids = [];
               }
                : t))))

(** Test: Multiple CreateEntering transitions for different symbols *)
let test_multiple_create_entering_transitions _ =
  let transitions =
    [
      {
        position_id = "AAPL-1";
        date = date_of_string "2024-01-01";
        kind =
          CreateEntering
            {
              symbol = "AAPL";
              target_quantity = 100.0;
              entry_price = 150.0;
              reasoning =
                TechnicalSignal { indicator = "EMA"; description = "Uptrend" };
            };
      };
      {
        position_id = "MSFT-1";
        date = date_of_string "2024-01-01";
        kind =
          CreateEntering
            {
              symbol = "MSFT";
              target_quantity = 50.0;
              entry_price = 300.0;
              reasoning = Rebalancing;
            };
      };
    ]
  in

  (* Create positions from transitions *)
  let positions =
    List.filter_map transitions ~f:(fun t ->
        match create_entering t with Ok pos -> Some pos | Error _ -> None)
  in

  (* Verify both positions created successfully *)
  assert_that positions
    (elements_are
       [
         equal_to
           ({
              id = "AAPL-1";
              symbol = "AAPL";
              entry_reasoning =
                TechnicalSignal { indicator = "EMA"; description = "Uptrend" };
              exit_reason = None;
              state =
                Entering
                  {
                    target_quantity = 100.0;
                    entry_price = 150.0;
                    filled_quantity = 0.0;
                    created_date = date_of_string "2024-01-01";
                  };
              last_updated = date_of_string "2024-01-01";
              portfolio_lot_ids = [];
            }
             : t);
         equal_to
           ({
              id = "MSFT-1";
              symbol = "MSFT";
              entry_reasoning = Rebalancing;
              exit_reason = None;
              state =
                Entering
                  {
                    target_quantity = 50.0;
                    entry_price = 300.0;
                    filled_quantity = 0.0;
                    created_date = date_of_string "2024-01-01";
                  };
              last_updated = date_of_string "2024-01-01";
              portfolio_lot_ids = [];
            }
             : t);
       ])

(** Test: CreateEntering with different reasoning types *)
let test_create_entering_with_various_reasoning _ =
  let test_reasoning reasoning expected_pos =
    let transition =
      {
        position_id = "test-1";
        date = date_of_string "2024-01-01";
        kind =
          CreateEntering
            {
              symbol = "TEST";
              target_quantity = 100.0;
              entry_price = 100.0;
              reasoning;
            };
      }
    in
    assert_that
      (create_entering transition)
      (is_ok_and_holds (fun pos ->
           assert_that pos (equal_to (expected_pos : t))))
  in

  (* Test all reasoning types *)
  test_reasoning
    (TechnicalSignal { indicator = "RSI"; description = "Oversold" })
    {
      id = "test-1";
      symbol = "TEST";
      entry_reasoning =
        TechnicalSignal { indicator = "RSI"; description = "Oversold" };
      exit_reason = None;
      state =
        Entering
          {
            target_quantity = 100.0;
            entry_price = 100.0;
            filled_quantity = 0.0;
            created_date = date_of_string "2024-01-01";
          };
      last_updated = date_of_string "2024-01-01";
      portfolio_lot_ids = [];
    };
  test_reasoning (PricePattern "Cup and Handle")
    {
      id = "test-1";
      symbol = "TEST";
      entry_reasoning = PricePattern "Cup and Handle";
      exit_reason = None;
      state =
        Entering
          {
            target_quantity = 100.0;
            entry_price = 100.0;
            filled_quantity = 0.0;
            created_date = date_of_string "2024-01-01";
          };
      last_updated = date_of_string "2024-01-01";
      portfolio_lot_ids = [];
    };
  test_reasoning Rebalancing
    {
      id = "test-1";
      symbol = "TEST";
      entry_reasoning = Rebalancing;
      exit_reason = None;
      state =
        Entering
          {
            target_quantity = 100.0;
            entry_price = 100.0;
            filled_quantity = 0.0;
            created_date = date_of_string "2024-01-01";
          };
      last_updated = date_of_string "2024-01-01";
      portfolio_lot_ids = [];
    };
  test_reasoning
    (ManualDecision { description = "Strong fundamentals" })
    {
      id = "test-1";
      symbol = "TEST";
      entry_reasoning = ManualDecision { description = "Strong fundamentals" };
      exit_reason = None;
      state =
        Entering
          {
            target_quantity = 100.0;
            entry_price = 100.0;
            filled_quantity = 0.0;
            created_date = date_of_string "2024-01-01";
          };
      last_updated = date_of_string "2024-01-01";
      portfolio_lot_ids = [];
    }

(** Test: CreateEntering validation - negative quantity *)
let test_create_entering_negative_quantity _ =
  let transition =
    {
      position_id = "test-1";
      date = date_of_string "2024-01-01";
      kind =
        CreateEntering
          {
            symbol = "TEST";
            target_quantity = -100.0;
            entry_price = 100.0;
            reasoning = Rebalancing;
          };
    }
  in
  assert_that
    (create_entering transition)
    (is_error_with Status.Invalid_argument
       ~msg:"target_quantity must be positive")

(** Test: CreateEntering validation - negative price *)
let test_create_entering_negative_price _ =
  let transition =
    {
      position_id = "test-1";
      date = date_of_string "2024-01-01";
      kind =
        CreateEntering
          {
            symbol = "TEST";
            target_quantity = 100.0;
            entry_price = -100.0;
            reasoning = Rebalancing;
          };
    }
  in
  assert_that
    (create_entering transition)
    (is_error_with Status.Invalid_argument ~msg:"entry_price must be positive")

(** Test: CreateEntering with wrong transition kind *)
let test_create_entering_wrong_transition_kind _ =
  let transition =
    {
      position_id = "test-1";
      date = date_of_string "2024-01-01";
      kind = EntryFill { filled_quantity = 100.0; fill_price = 100.0 };
    }
  in
  assert_that
    (create_entering transition)
    (is_error_with Status.Invalid_argument
       ~msg:"Expected CreateEntering transition")

(* ==================== Test Suite ==================== *)

let suite =
  "Position State Machine Tests"
  >::: [
         "create entering" >:: test_create_entering;
         "entry fill partial" >:: test_entry_fill_partial;
         "entry fill multiple" >:: test_entry_fill_multiple;
         "entry fill exceeds target" >:: test_entry_fill_exceeds_target;
         "entry fill multiple validation errors"
         >:: test_entry_fill_multiple_validation_errors;
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
         "create entering transition structure"
         >:: test_create_entering_transition_structure;
         "create entering creates position"
         >:: test_create_entering_creates_position;
         "multiple create entering transitions"
         >:: test_multiple_create_entering_transitions;
         "create entering with various reasoning"
         >:: test_create_entering_with_various_reasoning;
         "create entering negative quantity"
         >:: test_create_entering_negative_quantity;
         "create entering negative price"
         >:: test_create_entering_negative_price;
         "create entering wrong transition kind"
         >:: test_create_entering_wrong_transition_kind;
       ]

let () = run_test_tt_main suite
