(** Position lifecycle state machine

    This module implements an explicit state machine for managing the lifecycle
    of trading positions from creation to closure.

    {1 Overview}

    A position represents an open or closed trade in a single security. The
    position moves through a well-defined lifecycle with explicit states and
    transitions, ensuring all position changes are tracked and validated.

    {1 State Machine}

    Positions progress through four states:

    {v
      Entering ──→ Holding ──→ Exiting ──→ Closed
         ↓                        ↑
         └────────────────────────┘
              (cancel before fill)
    v}

    - {b Entering}: Order placed, waiting for fills (partial fills allowed)
    - {b Holding}: Position open, monitoring for exit signals
    - {b Exiting}: Exit triggered, waiting for fills to close
    - {b Closed}: Position fully closed, P&L realized

    {1 Transitions}

    State changes occur via explicit transition events:
    - [EntryFill]: Entry order filled (partially or fully)
    - [EntryComplete]: Entry fully filled, move to Holding
    - [CancelEntry]: Cancel entry before any fills
    - [TriggerExit]: Exit signal detected, start closing
    - [UpdateRiskParams]: Modify stop loss / take profit while holding
    - [ExitFill]: Exit order filled (partially or fully)
    - [ExitComplete]: Exit fully filled, position closed

    Each transition is validated for:
    - State compatibility (can only apply valid transitions to current state)
    - Position ID matching (prevent applying transitions to wrong position)
    - Data consistency (quantities, prices must be positive and within bounds)
    - Business rules (can't complete entry with no fills, etc.)

    {1 Design Rationale}

    {b Why explicit states?} Makes the position lifecycle visible and
    debuggable. Instead of implicit state scattered across fields, the state is
    explicit.

    {b Why transitions?} Provides a clear audit trail of all position changes.
    Every state change is represented as an event that can be logged, replayed,
    or analyzed.

    {b Why validation?} Prevents invalid state transitions and ensures data
    consistency. The state machine enforces business rules automatically.

    {1 Usage Example}

    {[
      (* Create position in Entering state *)
      let pos =
        Position.create_entering ~id:"AAPL-1" ~symbol:"AAPL"
          ~target_quantity:100.0 ~entry_price:150.0
          ~created_date:(Date.today ())
          ~reasoning:
            (TechnicalSignal { indicator = "EMA"; description = "..." })
      in

      (* Apply fill transition *)
      let pos =
        Position.apply_transition pos
          (EntryFill
             {
               position_id = "AAPL-1";
               filled_quantity = 100.0;
               fill_price = 150.25;
               fill_date = Date.today ();
             })
        |> Status.ok_exn
      in

      (* Complete entry, move to Holding *)
      let pos =
        Position.apply_transition pos
          (EntryComplete
             {
               position_id = "AAPL-1";
               risk_params =
                 {
                   stop_loss_price = Some 142.50;
                   take_profit_price = Some 165.00;
                   max_hold_days = None;
                 };
               completion_date = Date.today ();
             })
        |> Status.ok_exn
      in

      (* Position now in Holding state *)
      match Position.get_state pos with
      | Holding h -> Printf.printf "Holding %f shares\\n" h.quantity
      | _ -> ()
    ]} *)

open Core

(** {1 Position States} *)

(** Entry reasoning - why we're entering this position *)
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
(** Risk parameters for position management *)

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
  | TimeExpired of { days_held : int; max_days : int }
  | Underperforming of { days_held : int; current_return : float }
  | PortfolioRebalancing
[@@deriving show, eq]

(** Position state variants - only state-specific data *)
type position_state =
  | Entering of {
      target_quantity : float;
      entry_price : float;  (** Limit price for entry order *)
      filled_quantity : float;
      created_date : Date.t;
    }  (** State: Attempting to open a position *)
  | Holding of {
      quantity : float;
      entry_price : float;  (** Average entry price *)
      entry_date : Date.t;
      risk_params : risk_params;
    }  (** State: Position is open, monitoring for exit *)
  | Exiting of {
      quantity : float;  (** Position quantity being exited *)
      entry_price : float;  (** Original entry price *)
      entry_date : Date.t;  (** Original entry date *)
      target_quantity : float;  (** Amount to exit *)
      exit_price : float;  (** Price for exit order *)
      filled_quantity : float;  (** Amount exited so far *)
      started_date : Date.t;  (** When exit started *)
    }  (** State: Attempting to close position *)
  | Closed of {
      quantity : float;  (** Final position quantity *)
      entry_price : float;  (** Average entry price *)
      exit_price : float;  (** Average exit price *)
      gross_pnl : float option;  (** Populated by engine from portfolio *)
      entry_date : Date.t;  (** Entry date *)
      exit_date : Date.t;  (** Exit date *)
      days_held : int;  (** Days between entry and exit *)
    }  (** State: Position fully closed *)
[@@deriving show, eq]

type t = {
  id : string;  (** Unique position identifier *)
  symbol : string;  (** Trading symbol *)
  entry_reasoning : entry_reasoning;  (** Why we entered (set once) *)
  exit_reason : exit_reason option;  (** Why we're exiting (set when exiting) *)
  state : position_state;  (** Current position state *)
  last_updated : Date.t;  (** Last state change date *)
  portfolio_lot_ids : string list;
      (** Portfolio lot IDs associated with this position.

          Links this strategy position to the corresponding lots in the
          portfolio for tracking quantity and cost basis. Initially empty when
          position is created. Populated when entry fills execute and portfolio
          lots are created. *)
}
[@@deriving show, eq]
(** Position with normalized data - common fields at top level, state-specific
    data in variants *)

(** {1 Transitions} *)

(** Transition-specific data - only what's unique to each transition *)
type transition_kind =
  | EntryFill of { filled_quantity : float; fill_price : float }
      (** Entry order filled (partial or complete) *)
  | EntryComplete of { risk_params : risk_params }
      (** Entry fully filled, transition to holding *)
  | CancelEntry of { reason : string }  (** Cancel entry before any fills *)
  | TriggerExit of { exit_reason : exit_reason; exit_price : float }
      (** Exit condition triggered *)
  | UpdateRiskParams of { new_risk_params : risk_params }
      (** Update stop loss / take profit levels *)
  | ExitFill of { filled_quantity : float; fill_price : float }
      (** Exit order filled (partial or complete) *)
  | ExitComplete  (** Exit fully filled, position closed *)
[@@deriving show, eq]

type transition = {
  position_id : string;  (** Position this transition applies to *)
  date : Date.t;  (** When this transition occurred *)
  kind : transition_kind;  (** Transition-specific data *)
}
[@@deriving show, eq]
(** Transition event with common fields normalized *)

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
    - Business rules violated *)

val get_state : t -> position_state
(** Get current state *)

val is_closed : t -> bool
(** Check if position is in Closed state *)
