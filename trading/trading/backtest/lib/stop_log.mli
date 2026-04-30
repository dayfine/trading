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
  | End_of_period
      (** Position was force-closed at the end of the backtest period without a
          preceding strategy-emitted [TriggerExit]. The simulator's end-of-run
          auto-close path emits [ExitFill] + [ExitComplete] but no
          [TriggerExit], so the collector tags the resulting [stop_info] with
          this fallback to avoid an empty [exit_trigger] column in [trades.csv].
      *)
[@@deriving show, eq, sexp]

val exit_trigger_of_reason : Position.exit_reason -> exit_trigger
(** Map a {!Position.exit_reason} (the strategy-emitted form) into an
    {!exit_trigger} (the audit-friendly form). Pure translation — no information
    loss except that the [PortfolioRebalancing] / no-detail variants drop their
    associated metadata, mirroring the in-collector behaviour. Public so other
    backtest-side audit modules can produce the same mapping without duplicating
    the case-split. *)

type stop_info = {
  position_id : string;  (** Strategy position ID *)
  symbol : string;  (** Ticker symbol *)
  entry_date : Core.Date.t option;
      (** Date the [EntryComplete] transition fired for this position — i.e. the
          fill date of the entry leg. [None] when the collector observed an
          [EntryComplete] without a prior {!set_current_date} call (e.g. unit
          tests that drive transitions directly without simulating a calendar).
          Populated automatically when the runner threads [set_current_date] per
          simulation step. *)
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

val set_current_date : t -> Core.Date.t -> unit
(** Set the current calendar date observed by subsequent {!record_transitions}
    calls. The runner threads this per simulation step so that an
    [EntryComplete] transition stamps {!stop_info.entry_date} with the
    simulator's current step date. Tests that drive transitions directly can
    either call this to control the stamped date or leave it unset (in which
    case [entry_date = None]). *)

val record_transitions : t -> Position.transition list -> unit
(** Observe a batch of transitions (from one [on_market_close] call) and update
    internal state. Extracts:
    - [CreateEntering] records symbol and position_id
    - [EntryComplete] records initial stop-loss price from risk_params and
      stamps {!stop_info.entry_date} with the most recent {!set_current_date}.
    - [UpdateRiskParams] updates current stop-loss price
    - [TriggerExit] records exit trigger and final stop level
    - [ExitComplete] without a preceding [TriggerExit] tags
      [exit_trigger = End_of_period] (simulator end-of-run auto-close). An
      [ExitComplete] that follows a [TriggerExit] keeps the strategy's original
      trigger — the fallback is only applied when [exit_trigger] is still
      [None]. *)

val get_stop_infos : t -> stop_info list
(** Return stop info for all positions that have been observed, sorted by
    [position_id]. Positions still in Holding state will have
    [exit_trigger = None]. *)
