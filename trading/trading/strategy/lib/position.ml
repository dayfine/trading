(** Position lifecycle state machine *)

open Core

(** {1 Position States} *)

type entry_reasoning =
  | TechnicalSignal of { indicator : string; description : string }
  | PricePattern of string
  | Rebalancing
  | ManualDecision of { description : string }
[@@deriving show, eq]

type risk_params = {
  stop_loss_price : float option;
  take_profit_price : float option;
  max_hold_days : int option;
}
[@@deriving show, eq]

type exit_reason =
  | TakeProfit of {
      target_price : float;
      actual_price : float;
      profit_percent : float;
    }
  | StopLoss of {
      stop_price : float;
      actual_price : float;
      loss_percent : float;
    }
  | SignalReversal of { description : string }
  | TimeExpired of { days_held : int; max_days : int }
  | Underperforming of { days_held : int; current_return : float }
  | PortfolioRebalancing
[@@deriving show, eq]

type entering_state = {
  id : string;
  symbol : string;
  target_quantity : float;
  entry_price : float;
  filled_quantity : float;
  created_date : Date.t;
  reasoning : entry_reasoning;
}
[@@deriving show, eq]

type holding_state = {
  id : string;
  symbol : string;
  quantity : float;
  entry_price : float;
  entry_date : Date.t;
  entry_reasoning : entry_reasoning;
  risk_params : risk_params;
}
[@@deriving show, eq]

type exiting_state = {
  id : string;
  symbol : string;
  holding_state : holding_state;
  exit_reason : exit_reason;
  target_quantity : float;
  exit_price : float;
  filled_quantity : float;
  started_date : Date.t;
}
[@@deriving show, eq]

type closed_state = {
  id : string;
  symbol : string;
  quantity : float;
  entry_price : float;
  exit_price : float;
  gross_pnl : float;
  entry_date : Date.t;
  exit_date : Date.t;
  days_held : int;
  entry_reasoning : entry_reasoning;
  close_reason : exit_reason;
}
[@@deriving show, eq]

type position_state =
  | Entering of entering_state
  | Holding of holding_state
  | Exiting of exiting_state
  | Closed of closed_state
[@@deriving show, eq]

type t = { state : position_state; last_updated : Date.t } [@@deriving show, eq]

(** {1 Transitions} *)

type transition =
  | EntryFill of {
      position_id : string;
      filled_quantity : float;
      fill_price : float;
      fill_date : Date.t;
    }
  | EntryComplete of {
      position_id : string;
      risk_params : risk_params;
      completion_date : Date.t;
    }
  | CancelEntry of {
      position_id : string;
      reason : string;
      cancel_date : Date.t;
    }
  | TriggerExit of {
      position_id : string;
      exit_reason : exit_reason;
      exit_price : float;
      trigger_date : Date.t;
    }
  | UpdateRiskParams of {
      position_id : string;
      new_risk_params : risk_params;
      update_date : Date.t;
    }
  | ExitFill of {
      position_id : string;
      filled_quantity : float;
      fill_price : float;
      fill_date : Date.t;
    }
  | ExitComplete of { position_id : string; completion_date : Date.t }
[@@deriving show, eq]

(** {1 Helper Functions} *)

let _get_position_id = function
  | Entering s -> s.id
  | Holding s -> s.id
  | Exiting s -> s.id
  | Closed s -> s.id

let _validate_position_id state transition_id =
  let state_id = _get_position_id state in
  if String.equal state_id transition_id then Ok ()
  else
    Error
      (Status.invalid_argument_error
         (Printf.sprintf "Position ID mismatch: expected %s, got %s" state_id
            transition_id))

let _validate_positive name value =
  if Float.(value > 0.0) then Ok ()
  else
    Error
      (Status.invalid_argument_error
         (Printf.sprintf "%s must be positive: %.2f" name value))

let _validate_quantity_bounds filled target =
  if Float.(filled <= target) then Ok ()
  else
    Error
      (Status.invalid_argument_error
         (Printf.sprintf "Filled quantity (%.2f) exceeds target (%.2f)" filled
            target))

(** {1 Position Operations} *)

let create_entering ~id ~symbol ~target_quantity ~entry_price ~created_date
    ~reasoning =
  {
    state =
      Entering
        {
          id;
          symbol;
          target_quantity;
          entry_price;
          filled_quantity = 0.0;
          created_date;
          reasoning;
        };
    last_updated = created_date;
  }

let get_id t = _get_position_id t.state

let get_symbol t =
  match t.state with
  | Entering s -> s.symbol
  | Holding s -> s.symbol
  | Exiting s -> s.symbol
  | Closed s -> s.symbol

let get_state t = t.state
let is_closed t = match t.state with Closed _ -> true | _ -> false

(** {1 Transition Application} *)

let apply_transition t transition =
  let open Result.Let_syntax in
  match (t.state, transition) with
  (* Entering state transitions *)
  | ( Entering entering,
      EntryFill { position_id; filled_quantity; fill_price; fill_date } ) ->
      let%bind () = _validate_position_id t.state position_id in
      let%bind () = _validate_positive "fill_price" fill_price in
      let%bind () = _validate_positive "filled_quantity" filled_quantity in
      let new_filled = entering.filled_quantity +. filled_quantity in
      let%bind () =
        _validate_quantity_bounds new_filled entering.target_quantity
      in
      let new_entering = { entering with filled_quantity = new_filled } in
      Ok { state = Entering new_entering; last_updated = fill_date }
  | ( Entering entering,
      EntryComplete { position_id; risk_params; completion_date } ) ->
      let%bind () = _validate_position_id t.state position_id in
      if Float.(entering.filled_quantity <= 0.0) then
        Error
          (Status.invalid_argument_error "Cannot complete entry with no fills")
      else
        let holding =
          {
            id = entering.id;
            symbol = entering.symbol;
            quantity = entering.filled_quantity;
            entry_price = entering.entry_price;
            entry_date = completion_date;
            entry_reasoning = entering.reasoning;
            risk_params;
          }
        in
        Ok { state = Holding holding; last_updated = completion_date }
  | Entering entering, CancelEntry { position_id; reason = _; cancel_date } ->
      let%bind () = _validate_position_id t.state position_id in
      if Float.(entering.filled_quantity > 0.0) then
        Error
          (Status.invalid_argument_error
             "Cannot cancel entry after fills occurred")
      else
        let closed =
          {
            id = entering.id;
            symbol = entering.symbol;
            quantity = 0.0;
            entry_price = entering.entry_price;
            exit_price = entering.entry_price;
            gross_pnl = 0.0;
            entry_date = entering.created_date;
            exit_date = cancel_date;
            days_held = Date.diff cancel_date entering.created_date;
            entry_reasoning = entering.reasoning;
            close_reason = PortfolioRebalancing;
          }
        in
        Ok { state = Closed closed; last_updated = cancel_date }
  (* Holding state transitions *)
  | ( Holding holding,
      TriggerExit { position_id; exit_reason; exit_price; trigger_date } ) ->
      let%bind () = _validate_position_id t.state position_id in
      let%bind () = _validate_positive "exit_price" exit_price in
      let exiting =
        {
          id = holding.id;
          symbol = holding.symbol;
          holding_state = holding;
          exit_reason;
          target_quantity = holding.quantity;
          exit_price;
          filled_quantity = 0.0;
          started_date = trigger_date;
        }
      in
      Ok { state = Exiting exiting; last_updated = trigger_date }
  | ( Holding holding,
      UpdateRiskParams { position_id; new_risk_params; update_date } ) ->
      let%bind () = _validate_position_id t.state position_id in
      let updated_holding = { holding with risk_params = new_risk_params } in
      Ok { state = Holding updated_holding; last_updated = update_date }
  (* Exiting state transitions *)
  | ( Exiting exiting,
      ExitFill { position_id; filled_quantity; fill_price; fill_date } ) ->
      let%bind () = _validate_position_id t.state position_id in
      let%bind () = _validate_positive "fill_price" fill_price in
      let%bind () = _validate_positive "filled_quantity" filled_quantity in
      let new_filled = exiting.filled_quantity +. filled_quantity in
      let%bind () =
        _validate_quantity_bounds new_filled exiting.target_quantity
      in
      let new_exiting = { exiting with filled_quantity = new_filled } in
      Ok { state = Exiting new_exiting; last_updated = fill_date }
  | Exiting exiting, ExitComplete { position_id; completion_date } ->
      let%bind () = _validate_position_id t.state position_id in
      if Float.(exiting.filled_quantity <= 0.0) then
        Error
          (Status.invalid_argument_error "Cannot complete exit with no fills")
      else
        let holding = exiting.holding_state in
        let gross_pnl =
          (exiting.exit_price -. holding.entry_price) *. exiting.filled_quantity
        in
        let closed =
          {
            id = exiting.id;
            symbol = exiting.symbol;
            quantity = exiting.filled_quantity;
            entry_price = holding.entry_price;
            exit_price = exiting.exit_price;
            gross_pnl;
            entry_date = holding.entry_date;
            exit_date = completion_date;
            days_held = Date.diff completion_date holding.entry_date;
            entry_reasoning = holding.entry_reasoning;
            close_reason = exiting.exit_reason;
          }
        in
        Ok { state = Closed closed; last_updated = completion_date }
  (* Invalid transitions *)
  | Closed _, _ ->
      Error
        (Status.invalid_argument_error
           "Cannot apply transitions to closed position")
  | _, transition ->
      Error
        (Status.invalid_argument_error
           (Printf.sprintf "Invalid transition %s for current state"
              (show_transition transition)))
