(** Position lifecycle state machine *)

open Core

(** {1 Position States} *)

(** Entry reasoning - why we're entering this position *)
type entry_reasoning =
  | TechnicalSignal of {
      indicator : string;
      description : string;
    }
  | PricePattern of string
  | Rebalancing
[@@deriving show, eq]

(** Risk parameters for position management *)
type risk_params = {
  stop_loss_price : float option;
  take_profit_price : float option;
  max_hold_days : int option;
}
[@@deriving show, eq]

(** Exit reason - why we're closing this position *)
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
  | TimeExpired of {
      days_held : int;
      max_days : int;
    }
  | Underperforming of {
      days_held : int;
      current_return : float;
    }
  | PortfolioRebalancing
[@@deriving show, eq]

(** State: Attempting to open a position *)
type entering_state = {
  id : string;
  symbol : string;
  target_quantity : float;
  entry_price : float;  (** Limit price for entry order *)
  filled_quantity : float;
  created_date : Date.t;
  reasoning : entry_reasoning;
}
[@@deriving show, eq]

(** State: Position is open, monitoring for exit *)
type holding_state = {
  id : string;
  symbol : string;
  quantity : float;
  entry_price : float;  (** Average entry price *)
  entry_date : Date.t;
  entry_reasoning : entry_reasoning;
  risk_params : risk_params;
}
[@@deriving show, eq]

(** State: Attempting to close position *)
type exiting_state = {
  id : string;
  symbol : string;
  holding_state : holding_state;
  exit_reason : exit_reason;
  target_quantity : float;  (** Amount to exit *)
  exit_price : float;  (** Price for exit order *)
  filled_quantity : float;
  started_date : Date.t;
}
[@@deriving show, eq]

(** State: Position fully closed *)
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

(** Position state - exactly one of four states *)
type position_state =
  | Entering of entering_state
  | Holding of holding_state
  | Exiting of exiting_state
  | Closed of closed_state
[@@deriving show, eq]

(** Position with state and metadata *)
type t = {
  state : position_state;
  last_updated : Date.t;
}
[@@deriving show, eq]

(** {1 Transitions} *)

(** Transition events that change position state *)
type transition =
  | EntryFill of {
      position_id : string;
      filled_quantity : float;
      fill_price : float;
      fill_date : Date.t;
    }
      (** Entry order filled (partial or complete) *)
  | EntryComplete of {
      position_id : string;
      risk_params : risk_params;
      completion_date : Date.t;
    }
      (** Entry fully filled, transition to holding *)
  | CancelEntry of {
      position_id : string;
      reason : string;
      cancel_date : Date.t;
    }
      (** Cancel entry before any fills *)
  | TriggerExit of {
      position_id : string;
      exit_reason : exit_reason;
      exit_price : float;
      trigger_date : Date.t;
    }
      (** Exit condition triggered *)
  | UpdateRiskParams of {
      position_id : string;
      new_risk_params : risk_params;
      update_date : Date.t;
    }
      (** Update stop loss / take profit levels *)
  | ExitFill of {
      position_id : string;
      filled_quantity : float;
      fill_price : float;
      fill_date : Date.t;
    }
      (** Exit order filled (partial or complete) *)
  | ExitComplete of {
      position_id : string;
      completion_date : Date.t;
    }
      (** Exit fully filled, position closed *)
[@@deriving show, eq]

(** {1 Position Operations} *)

val create_entering :
  id:string ->
  symbol:string ->
  target_quantity:float ->
  entry_price:float ->
  created_date:Date.t ->
  reasoning:entry_reasoning ->
  t
(** Create a new position in Entering state *)

val apply_transition : t -> transition -> t Status.status_or
(** Apply a transition to a position.

    Returns Error if:
    - Transition is invalid for current state
    - Position ID doesn't match
    - Data is inconsistent
    - Business rules violated
*)

val get_id : t -> string
(** Get position ID *)

val get_symbol : t -> string
(** Get position symbol *)

val get_state : t -> position_state
(** Get current state *)

val is_closed : t -> bool
(** Check if position is in Closed state *)
