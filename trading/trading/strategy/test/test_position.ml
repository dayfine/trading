open OUnit2
open Core
open Trading_strategy.Position
open Matchers

let date_of_string s = Date.of_string s

(* Test helpers *)

let no_risk_params =
  { stop_loss_price = None; take_profit_price = None; max_hold_days = None }

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
            side = Long;
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

let apply_or_fail pos kind =
  let transition =
    { position_id = pos.id; date = date_of_string "2024-01-10"; kind }
  in
  match apply_transition pos transition with
  | Ok pos' -> pos'
  | Error err -> failwith ("Failed to apply transition: " ^ Status.show err)

let make_holding ?(id = "pos-1") ?(symbol = "AAPL") ?(quantity = 100.0)
    ?(entry_price = 150.0) () =
  {
    id;
    symbol;
    side = Long;
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
            side = Long;
            target_quantity = 100.0;
            entry_price = 150.0;
            reasoning =
              TechnicalSignal { indicator = "EMA"; description = "Test" };
          };
    }
  in
  assert_that
    (create_entering transition)
    (is_ok_and_holds
       (equal_to
          ({
             id = "pos-1";
             symbol = "AAPL";
             side = Long;
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
            : t)))

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
    (is_ok_and_holds
       (field
          (fun pos' -> get_state pos')
          (matching ~msg:"Expected Entering state"
             (function Entering e -> Some e.filled_quantity | _ -> None)
             (float_equal 50.0))))

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
    (is_ok_and_holds
       (field
          (fun pos' -> get_state pos')
          (matching ~msg:"Expected Entering state"
             (function Entering e -> Some e.filled_quantity | _ -> None)
             (float_equal 80.0))))

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
    (is_ok_and_holds
       (field
          (fun pos' -> get_state pos')
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
    (is_ok_and_holds
       (all_of
          [
            field (fun pos' -> is_closed pos') (equal_to true);
            field
              (fun pos' -> get_state pos')
              (matching ~msg:"Expected Closed state"
                 (function Closed c -> Some c.quantity | _ -> None)
                 (float_equal 0.0));
          ]))

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
    (is_ok_and_holds
       (all_of
          [
            field
              (fun pos' -> get_state pos')
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
                      risk_params =
                        {
                          stop_loss_price = Some 142.5;
                          take_profit_price = Some 165.0;
                          max_hold_days = Some 30;
                        };
                    }
                   : position_state));
            field
              (fun pos' -> pos'.exit_reason)
              (is_some_and
                 (equal_to
                    (TakeProfit
                       {
                         target_price = 165.0;
                         actual_price = 165.5;
                         profit_percent = 10.3;
                       }
                      : exit_reason)));
          ]))

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
    (is_ok_and_holds
       (field
          (fun pos' -> get_state pos')
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
      side = Long;
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
            risk_params = no_risk_params;
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
    (is_ok_and_holds
       (field
          (fun pos' -> get_state pos')
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
                  risk_params = no_risk_params;
                }
               : position_state))))

let test_exit_complete _ =
  let pos =
    {
      id = "pos-1";
      symbol = "AAPL";
      side = Long;
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
            risk_params = no_risk_params;
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
    (is_ok_and_holds
       (all_of
          [
            field (fun pos' -> is_closed pos') (equal_to true);
            field
              (fun pos' -> get_state pos')
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
                   : position_state));
          ]))

(* ==================== Partial Exit Transitions ==================== *)

(* risk_params that [make_holding] installs; the partial-exit path must carry
   these through Exiting and back onto the trimmed Holding. *)
let holding_risk_params =
  {
    stop_loss_price = Some 142.5;
    take_profit_price = Some 165.0;
    max_hold_days = Some 30;
  }

let take_profit_reason =
  TakeProfit
    { target_price = 165.0; actual_price = 165.5; profit_percent = 10.3 }

let partial_exit_kind ?(exit_price = 165.0) target_quantity =
  TriggerPartialExit
    { exit_reason = take_profit_reason; exit_price; target_quantity }

let exit_fill_kind ~filled_quantity =
  ExitFill { filled_quantity; fill_price = 165.5 }

(* A partial [TriggerPartialExit] puts the position into Exiting with
   [target_quantity] = the requested trim (not the full held quantity), carrying
   the holding's risk params and original entry price/date. *)
let test_trigger_partial_exit _ =
  let pos = make_holding () in
  assert_that
    (apply_transition pos
       {
         position_id = "pos-1";
         date = date_of_string "2024-01-10";
         kind = partial_exit_kind 40.0;
       })
    (is_ok_and_holds
       (field
          (fun p -> get_state p)
          (equal_to
             (Exiting
                {
                  quantity = 100.0;
                  entry_price = 150.0;
                  entry_date = date_of_string "2024-01-02";
                  target_quantity = 40.0;
                  exit_price = 165.0;
                  filled_quantity = 0.0;
                  started_date = date_of_string "2024-01-10";
                  risk_params = holding_risk_params;
                }
               : position_state))))

(* Full partial-exit round-trip: Holding(100) -> trim 40 -> ExitFill(40) ->
   ExitComplete -> Holding(60) with original entry price/date and risk params
   preserved on the reduced quantity. *)
let test_partial_exit_returns_to_holding _ =
  let pos = make_holding () in
  let pos = apply_or_fail pos (partial_exit_kind 40.0) in
  let pos = apply_or_fail pos (exit_fill_kind ~filled_quantity:40.0) in
  assert_that
    (apply_transition pos
       {
         position_id = "pos-1";
         date = date_of_string "2024-01-12";
         kind = ExitComplete;
       })
    (is_ok_and_holds
       (field
          (fun p -> get_state p)
          (equal_to
             (Holding
                {
                  quantity = 60.0;
                  entry_price = 150.0;
                  entry_date = date_of_string "2024-01-02";
                  risk_params = holding_risk_params;
                }
               : position_state))))

(* A [TriggerPartialExit] whose target equals the full held quantity closes the
   position on ExitComplete, exactly like a [TriggerExit]. *)
let test_partial_exit_full_target_closes _ =
  let pos = make_holding () in
  let pos = apply_or_fail pos (partial_exit_kind ~exit_price:165.5 100.0) in
  let pos = apply_or_fail pos (exit_fill_kind ~filled_quantity:100.0) in
  assert_that
    (apply_transition pos
       {
         position_id = "pos-1";
         date = date_of_string "2024-01-12";
         kind = ExitComplete;
       })
    (is_ok_and_holds
       (all_of
          [
            field (fun p -> is_closed p) (equal_to true);
            field
              (fun p -> get_state p)
              (equal_to
                 (Closed
                    {
                      quantity = 100.0;
                      entry_price = 150.0;
                      exit_price = 165.5;
                      gross_pnl = None;
                      entry_date = date_of_string "2024-01-02";
                      exit_date = date_of_string "2024-01-12";
                      days_held = 10;
                    }
                   : position_state));
          ]))

(* Two partial exits in sequence: Holding(100) -> trim 40 -> Holding(60) ->
   trim 20 -> Holding(40). The remainder keeps tracking its stop each time. *)
let test_second_partial_exit _ =
  let pos = make_holding () in
  let pos = apply_or_fail pos (partial_exit_kind 40.0) in
  let pos = apply_or_fail pos (exit_fill_kind ~filled_quantity:40.0) in
  let pos = apply_or_fail pos ExitComplete in
  let pos = apply_or_fail pos (partial_exit_kind 20.0) in
  let pos = apply_or_fail pos (exit_fill_kind ~filled_quantity:20.0) in
  assert_that
    (apply_transition pos
       {
         position_id = "pos-1";
         date = date_of_string "2024-01-15";
         kind = ExitComplete;
       })
    (is_ok_and_holds
       (field
          (fun p -> get_state p)
          (equal_to
             (Holding
                {
                  quantity = 40.0;
                  entry_price = 150.0;
                  entry_date = date_of_string "2024-01-02";
                  risk_params = holding_risk_params;
                }
               : position_state))))

(* A non-positive trim target is rejected. *)
let test_partial_exit_target_not_positive _ =
  let pos = make_holding () in
  assert_that
    (apply_transition pos
       {
         position_id = "pos-1";
         date = date_of_string "2024-01-10";
         kind = partial_exit_kind 0.0;
       })
    (is_error_with Status.Invalid_argument ~msg:"must be in")

(* A trim target larger than the held quantity is rejected. *)
let test_partial_exit_target_too_large _ =
  let pos = make_holding () in
  assert_that
    (apply_transition pos
       {
         position_id = "pos-1";
         date = date_of_string "2024-01-10";
         kind = partial_exit_kind 150.0;
       })
    (is_error_with Status.Invalid_argument ~msg:"must be in")

(* ==================== Invalid Transitions ==================== *)

let test_invalid_transition_from_closed _ =
  let pos =
    {
      id = "pos-1";
      symbol = "AAPL";
      side = Long;
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
            side = Long;
            target_quantity = 100.0;
            entry_price = 150.0;
            reasoning = ManualDecision { description = "Buy and hold" };
          };
    }
  in
  assert_that
    (create_entering transition)
    (is_ok_and_holds
       (equal_to
          ({
             id = "AAPL-1";
             symbol = "AAPL";
             side = Long;
             entry_reasoning = ManualDecision { description = "Buy and hold" };
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
            : t)))

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
              side = Long;
              target_quantity = 100.0;
              entry_price = 100.0;
              reasoning;
            };
      }
    in
    assert_that
      (create_entering transition)
      (is_ok_and_holds (equal_to (expected_pos : t)))
  in

  (* Test all reasoning types *)
  test_reasoning
    (TechnicalSignal { indicator = "RSI"; description = "Oversold" })
    {
      id = "test-1";
      symbol = "TEST";
      side = Long;
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
      side = Long;
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
      side = Long;
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
      side = Long;
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
            side = Long;
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
            side = Long;
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
         "trigger partial exit" >:: test_trigger_partial_exit;
         "partial exit returns to holding"
         >:: test_partial_exit_returns_to_holding;
         "partial exit full target closes"
         >:: test_partial_exit_full_target_closes;
         "second partial exit" >:: test_second_partial_exit;
         "partial exit target not positive"
         >:: test_partial_exit_target_not_positive;
         "partial exit target too large" >:: test_partial_exit_target_too_large;
         "invalid transition from closed"
         >:: test_invalid_transition_from_closed;
         "wrong position id" >:: test_wrong_position_id;
         "invalid state transition" >:: test_invalid_state_transition;
         "create entering creates position"
         >:: test_create_entering_creates_position;
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
