(** Force-liquidation policy — defense in depth beyond stops.

    Closes G4 from [dev/notes/short-side-gaps-2026-04-29.md]. When the primary
    stop machinery fails to protect a trade and unrealized loss compounds
    unchecked, this policy fires a forced close. The event is logged + emitted
    as a signal — every fired event is evidence that stops did not do their job.

    {1 Two trigger conditions}

    - {b Per-position}: a single position's unrealized loss exceeds the
      side-specific threshold ([max_long_unrealized_loss_fraction] for longs,
      [max_short_unrealized_loss_fraction] for shorts) of its cost basis.
      Force-close that position only. Asymmetric per Weinstein's stop-loss
      rules: a long's downside is capped at 100% (price floor at 0); a short's
      downside is unbounded (price has no ceiling), so shorts are held to a
      tighter loss budget.
    - {b Portfolio-floor}: total portfolio value drops below
      [min_portfolio_value_fraction_of_peak] of the highest portfolio value
      observed since the strategy started. Force-close ALL positions and halt
      new entries until macro flips.

    {1 Design}

    The [check] function is pure — given a snapshot of positions, prices, and
    the current peak, it returns the full list of force-liquidation events to
    emit on this tick. Peak tracking and halt state live separately in
    [Peak_tracker] (mutable) so callers can wire the lifetime to their own
    strategy-state closure.

    Both checks fire after [Stops_runner.update] in
    [Weinstein_strategy._on_market_close], so a position that already exited via
    a regular stop on the same tick is not double-counted (it is no longer in
    [Holding] state).

    Strict broker-margin semantics (collateral pre-locked at short entry,
    refunded on cover) are deliberately deferred — see
    [dev/notes/short-side-gaps-2026-04-29.md] §G4. *)

open Core

(** {1 Configuration} *)

type config = {
  max_long_unrealized_loss_fraction : float;
      (** Per-position trigger for {b longs}: force-close a long position when
          its unrealized loss exceeds this fraction of cost basis. Default
          [0.25] (25% of cost basis lost). Set to [Float.infinity] to disable.
      *)
  max_short_unrealized_loss_fraction : float;
      (** Per-position trigger for {b shorts}: force-close a short position when
          its unrealized loss exceeds this fraction of cost basis. Default
          [0.15] (15% of cost basis lost) — tighter than longs because short
          downside is unbounded. Set to [Float.infinity] to disable. *)
  min_portfolio_value_fraction_of_peak : float;
      (** Portfolio-floor trigger: force-close all positions and halt new
          entries when [portfolio_value < peak * fraction]. Default [0.4] (40%
          of peak — i.e. 60% drawdown from peak). Set to [0.0] to disable the
          portfolio trigger. *)
}
[@@deriving show, eq, sexp]
(** All thresholds — nothing hardcoded. *)

val default_config : config
(** [{ max_long_unrealized_loss_fraction = 0.25;
     max_short_unrealized_loss_fraction = 0.15;
     min_portfolio_value_fraction_of_peak = 0.4 }]. *)

(** {1 Event} *)

(** Why a force-liquidation event fired. *)
type reason =
  | Per_position
      (** Per-position threshold exceeded — only this position is closed. *)
  | Portfolio_floor
      (** Portfolio-floor threshold exceeded — all open positions are closed and
          new entries are halted until macro flips. *)
[@@deriving show, eq, sexp]

type event = {
  symbol : string;
  position_id : string;
  date : Date.t;
  side : Trading_base.Types.position_side;
  entry_price : float;
  current_price : float;
  quantity : float;  (** Position size (always positive). *)
  cost_basis : float;  (** [entry_price * quantity]. *)
  unrealized_pnl : float;
      (** Signed dollar P&L. Long: [(current - entry) * quantity]. Short:
          [(entry - current) * quantity]. *)
  unrealized_pnl_pct : float;
      (** [unrealized_pnl / cost_basis]. Negative for losses. *)
  reason : reason;
}
[@@deriving show, eq, sexp]
(** Single force-liquidation event. One per position closed. *)

(** {1 Per-position math} *)

val unrealized_pnl :
  side:Trading_base.Types.position_side ->
  entry_price:float ->
  current_price:float ->
  quantity:float ->
  float
(** Signed dollar P&L for a position. Long: [(current - entry) * quantity].
    Short: [(entry - current) * quantity]. Quantity is always positive. *)

(** {1 Peak tracking + halt state} *)

(** Halt state. Once [Halted], force-liquidation suppresses new entries until
    [reset] is called (typically when macro flips off Bearish). *)
type halt_state = Active | Halted [@@deriving show, eq, sexp]

(** Mutable peak-portfolio-value tracker. Maintains [peak] monotonically:
    [observe] only raises it. The [halt_state] flips to [Halted] when a
    portfolio-floor event fires; callers must call [reset] to resume entries. *)
module Peak_tracker : sig
  type t

  val create : unit -> t
  (** Empty tracker — peak starts at [0.0], halt_state at [Active]. *)

  val peak : t -> float
  val halt_state : t -> halt_state

  val observe : t -> portfolio_value:float -> unit
  (** Raise the tracked peak to [max peak portfolio_value]. *)

  val mark_halted : t -> unit
  (** Flip [halt_state] to [Halted]. Idempotent. *)

  val reset : t -> unit
  (** Flip [halt_state] back to [Active]. Idempotent. Peak is preserved. *)
end

(** {1 Check} *)

type position_input = {
  symbol : string;
  position_id : string;
  side : Trading_base.Types.position_side;
  entry_price : float;
  current_price : float;
  quantity : float;
}
[@@deriving show, eq, sexp]
(** Per-position input for [check]. Quantity is always positive; [side]
    distinguishes long vs short. *)

val check :
  config:config ->
  date:Date.t ->
  positions:position_input list ->
  portfolio_value:float ->
  peak_tracker:Peak_tracker.t ->
  event list
(** Run both triggers and return the full list of force-liquidation events to
    emit this tick.

    Side effects: [peak_tracker] is updated to the new peak; [halt_state] is
    flipped to [Halted] when a portfolio-floor trigger fires.

    {b Order of precedence}: the portfolio-floor check runs first. When it
    fires, every position in [positions] yields a [Portfolio_floor] event and no
    per-position events are emitted on this tick (avoid double-counting).
    Otherwise, each position is checked independently against the per-position
    threshold. *)
