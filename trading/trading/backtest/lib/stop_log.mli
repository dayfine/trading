(** Per-trade stop logging for backtest diagnostics.

    Captures stop-level information from strategy transitions so each round-trip
    trade in the backtest output can be annotated with:
    - The initial stop level set at entry
    - The stop level at the time of exit
    - Which rule triggered the exit (stop-loss hit, take-profit, signal
      reversal, etc.)

    This module does NOT modify the strategy or simulator — it observes
    transitions emitted by the strategy and records stop-relevant information as
    a side effect. *)

open Trading_strategy

(** {1 Types} *)

(** Why the position was exited, as recorded from the strategy's transition. *)
type exit_trigger =
  | Stop_loss of { stop_price : float; actual_price : float }
      (** Trailing stop was hit *)
  | Take_profit of { target_price : float; actual_price : float }
      (** Take-profit target reached *)
  | Signal_reversal of { description : string }
      (** Technical signal reversed *)
  | Time_expired of { days_held : int; max_days : int }  (** Held too long *)
  | Underperforming of { days_held : int; current_return : float }
      (** Position underperformed *)
  | Portfolio_rebalancing  (** Closed for rebalancing *)
[@@deriving show, eq, sexp]

type stop_info = {
  position_id : string;  (** Strategy position ID *)
  symbol : string;  (** Ticker symbol *)
  entry_stop : float option;
      (** Stop-loss price set when position entered Holding state *)
  exit_stop : float option;
      (** Stop-loss price at the time of exit (may have been updated via
          trailing) *)
  exit_trigger : exit_trigger option;
      (** What caused the exit. [None] if position is still open. *)
}
[@@deriving show, eq, sexp]
(** Stop information for a single round-trip trade. Keyed by position_id so it
    can be joined with [Metrics.trade_metrics] via symbol + entry_date. *)

(** {1 Collector} *)

type t
(** Mutable collector that accumulates stop info from observed transitions. *)

val create : unit -> t
(** Create an empty collector. *)

val record_transitions : t -> Position.transition list -> unit
(** Observe a batch of transitions (from one [on_market_close] call) and update
    internal state. Extracts:
    - [CreateEntering] records symbol and position_id
    - [EntryComplete] records initial stop-loss price from risk_params
    - [UpdateRiskParams] updates current stop-loss price
    - [TriggerExit] records exit trigger and final stop level *)

val get_stop_infos : t -> stop_info list
(** Return stop info for all positions that have been observed, sorted by
    [position_id]. Positions still in Holding state will have
    [exit_trigger = None]. *)
