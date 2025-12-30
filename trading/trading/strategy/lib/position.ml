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

type position_state =
  | Entering of {
      target_quantity : float;
      entry_price : float;
      filled_quantity : float;
      created_date : Date.t;
    }
  | Holding of {
      quantity : float;
      entry_price : float;
      entry_date : Date.t;
      risk_params : risk_params;
    }
  | Exiting of {
      quantity : float;
      entry_price : float;
      entry_date : Date.t;
      target_quantity : float;
      exit_price : float;
      filled_quantity : float;
      started_date : Date.t;
    }
  | Closed of {
      quantity : float;
      entry_price : float;
      exit_price : float;
      gross_pnl : float;
      entry_date : Date.t;
      exit_date : Date.t;
      days_held : int;
    }
[@@deriving show, eq]

type t = {
  id : string;
  symbol : string;
  entry_reasoning : entry_reasoning;
  exit_reason : exit_reason option;
  state : position_state;
  last_updated : Date.t;
}
[@@deriving show, eq]

(** {1 Transitions} *)

type transition_kind =
  | EntryFill of { filled_quantity : float; fill_price : float }
  | EntryComplete of { risk_params : risk_params }
  | CancelEntry of { reason : string }
  | TriggerExit of { exit_reason : exit_reason; exit_price : float }
  | UpdateRiskParams of { new_risk_params : risk_params }
  | ExitFill of { filled_quantity : float; fill_price : float }
  | ExitComplete
[@@deriving show, eq]

type transition = {
  position_id : string;
  date : Date.t;
  kind : transition_kind;
}
[@@deriving show, eq]

(** {1 Helper Functions} *)

let _validate_position_id position_id transition_id =
  if String.equal position_id transition_id then Ok ()
  else
    Error
      (Status.invalid_argument_error
         (Printf.sprintf "Position ID mismatch: expected %s, got %s" position_id
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
    id;
    symbol;
    entry_reasoning = reasoning;
    exit_reason = None;
    state =
      Entering
        { target_quantity; entry_price; filled_quantity = 0.0; created_date };
    last_updated = created_date;
  }

let get_state t = t.state
let is_closed t = match t.state with Closed _ -> true | _ -> false

(** {1 Transition Application} *)

let apply_transition t transition =
  let open Result.Let_syntax in
  let%bind () = _validate_position_id t.id transition.position_id in
  match (t.state, transition.kind) with
  (* Entering state transitions *)
  | ( Entering
        {
          target_quantity;
          entry_price;
          filled_quantity = curr_filled;
          created_date;
        },
      EntryFill { filled_quantity; fill_price } ) ->
      let new_filled = curr_filled +. filled_quantity in
      let validations =
        [
          _validate_positive "fill_price" fill_price;
          _validate_positive "filled_quantity" filled_quantity;
          _validate_quantity_bounds new_filled target_quantity;
        ]
      in
      let%bind () = Status.combine_status_list validations in
      Ok
        {
          t with
          state =
            Entering
              {
                target_quantity;
                entry_price;
                filled_quantity = new_filled;
                created_date;
              };
          last_updated = transition.date;
        }
  | ( Entering
        { target_quantity = _; entry_price; filled_quantity; created_date = _ },
      EntryComplete { risk_params } ) ->
      if Float.(filled_quantity <= 0.0) then
        Error
          (Status.invalid_argument_error "Cannot complete entry with no fills")
      else
        Ok
          {
            t with
            state =
              Holding
                {
                  quantity = filled_quantity;
                  entry_price;
                  entry_date = transition.date;
                  risk_params;
                };
            last_updated = transition.date;
          }
  | ( Entering
        { target_quantity = _; entry_price; filled_quantity; created_date },
      CancelEntry { reason = _ } ) ->
      if Float.(filled_quantity > 0.0) then
        Error
          (Status.invalid_argument_error
             "Cannot cancel entry after fills occurred")
      else
        Ok
          {
            t with
            state =
              Closed
                {
                  quantity = 0.0;
                  entry_price;
                  exit_price = entry_price;
                  gross_pnl = 0.0;
                  entry_date = created_date;
                  exit_date = transition.date;
                  days_held = Date.diff transition.date created_date;
                };
            exit_reason = Some PortfolioRebalancing;
            last_updated = transition.date;
          }
  (* Holding state transitions *)
  | ( Holding { quantity; entry_price; entry_date; risk_params = _ },
      TriggerExit { exit_reason; exit_price } ) ->
      let%bind () = _validate_positive "exit_price" exit_price in
      Ok
        {
          t with
          state =
            Exiting
              {
                quantity;
                entry_price;
                entry_date;
                target_quantity = quantity;
                exit_price;
                filled_quantity = 0.0;
                started_date = transition.date;
              };
          exit_reason = Some exit_reason;
          last_updated = transition.date;
        }
  | ( Holding { quantity; entry_price; entry_date; risk_params = _ },
      UpdateRiskParams { new_risk_params } ) ->
      Ok
        {
          t with
          state =
            Holding
              {
                quantity;
                entry_price;
                entry_date;
                risk_params = new_risk_params;
              };
          last_updated = transition.date;
        }
  (* Exiting state transitions *)
  | ( Exiting
        {
          quantity;
          entry_price;
          entry_date;
          target_quantity;
          exit_price;
          filled_quantity = curr_filled;
          started_date;
        },
      ExitFill { filled_quantity; fill_price } ) ->
      let new_filled = curr_filled +. filled_quantity in
      let validations =
        [
          _validate_positive "fill_price" fill_price;
          _validate_positive "filled_quantity" filled_quantity;
          _validate_quantity_bounds new_filled target_quantity;
        ]
      in
      let%bind () = Status.combine_status_list validations in
      Ok
        {
          t with
          state =
            Exiting
              {
                quantity;
                entry_price;
                entry_date;
                target_quantity;
                exit_price;
                filled_quantity = new_filled;
                started_date;
              };
          last_updated = transition.date;
        }
  | ( Exiting
        {
          quantity = _;
          entry_price;
          entry_date;
          target_quantity = _;
          exit_price;
          filled_quantity;
          started_date = _;
        },
      ExitComplete ) ->
      if Float.(filled_quantity <= 0.0) then
        Error
          (Status.invalid_argument_error "Cannot complete exit with no fills")
      else
        let gross_pnl = (exit_price -. entry_price) *. filled_quantity in
        Ok
          {
            t with
            state =
              Closed
                {
                  quantity = filled_quantity;
                  entry_price;
                  exit_price;
                  gross_pnl;
                  entry_date;
                  exit_date = transition.date;
                  days_held = Date.diff transition.date entry_date;
                };
            last_updated = transition.date;
          }
  (* Invalid transitions *)
  | Closed _, _ ->
      Error
        (Status.invalid_argument_error
           "Cannot apply transitions to closed position")
  | _, kind ->
      Error
        (Status.invalid_argument_error
           (Printf.sprintf "Invalid transition %s for current state"
              (show_transition_kind kind)))
