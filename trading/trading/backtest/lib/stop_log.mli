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
  | Strategy_signal of { label : string; detail : string option }
      (** Strategy-emitted exit reason — mirrors
          {!Position.exit_reason.StrategySignal}. [label] is the stable string
          identifier surfaced as the [exit_trigger] column value in [trades.csv]
          (e.g. ["stage3_force_exit"]). [detail] carries an optional
          strategy-side payload that downstream tuner / audit tools can inspect
          (e.g. ["weeks_in_stage3=3"]) — the trades.csv writer ignores it. *)
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

val with_fill_price : exit_trigger -> fill_price:float -> exit_trigger
(** Replace a stop-loss or take-profit trigger's [actual_price] with the
    executed fill price. Strategy reasons carry the observed bar price until
    a fill is joined; that observation must not classify an executed exit.
    Preserves the trigger level and all other exit reasons. *)

(** Granular classification of how a stop-driven exit fired, derived from the
    {!exit_trigger} variant + the gap between trigger level and actual fill.
    Surfaced on per-trade context exports for downstream tuner / ML use.

    - [Gap_through]: actual fill was significantly worse than the stop level
      (more than {!gap_down_threshold_pct} past the stop): for a long, below it
      (the bar gapped down through the stop); for a short, above it (gapped up).
      Indicates a price gap past the stop, not a clean stop-hit. Named
      side-neutrally since #3147; [trades.csv] labels it by side
      ([Trade_context.stop_trigger_kind_label]: [gap_down] long, [gap_up]
      short).
    - [Intraday]: actual fill at or near the stop level. The typical case where
      the stop was hit during normal trading.
    - [End_of_period]: position was force-closed at end-of-run by the simulator
      without a strategy-emitted [TriggerExit] (matches
      {!exit_trigger.End_of_period}).
    - [Non_stop_exit]: the exit was not a stop trigger — take-profit,
      signal-reversal, time-expiry, or rebalance. *)
type stop_trigger_kind =
  | Gap_through
  | Intraday
  | End_of_period
  | Non_stop_exit
[@@deriving show, eq, sexp]

val gap_down_threshold_pct : float
(** Threshold gap (as a fraction of stop price) that distinguishes a
    {!Gap_through} fill from an {!Intraday} fill. A long stop with
    [actual_price < stop_price * (1 - threshold)] counts as a gap-down
    (symmetric for shorts). Default 0.005 (50 basis points) — conservative
    enough that typical bid-ask noise on liquid US equities does not trip it but
    real overnight gaps do. *)

val classify_stop_trigger_kind :
  ?gap_threshold_pct:float ->
  side:Trading_base.Types.position_side ->
  exit_trigger ->
  stop_trigger_kind
(** Classify the kind of stop trigger from the trigger-level vs actual-fill gap
    on a {!Stop_loss} variant.

    For [Stop_loss { stop_price; actual_price }]:
    - Long: [actual_price < stop_price * (1 - gap)] → [Gap_through]; else
      [Intraday].
    - Short: [actual_price > stop_price * (1 + gap)] → [Gap_through]; else
      [Intraday].

    The {!End_of_period} variant maps to {!stop_trigger_kind.End_of_period}. All
    other variants ({!Take_profit}, {!Signal_reversal}, {!Time_expired},
    {!Underperforming}, {!Portfolio_rebalancing}, {!Strategy_signal}) classify
    as {!Non_stop_exit}.

    [gap_threshold_pct] defaults to {!gap_down_threshold_pct}. Pure function —
    same inputs always produce the same output. *)

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
      (** The initial stop installed at entry. Taken from
          {!record_installed_stop} (the strategy's installed stop, reported at
          the entry decision) or from the [EntryComplete] transition's
          [stop_loss_price] when that carries one; whichever arrives last wins.
          The simulator's [EntryComplete] carries no stop, so for the Weinstein
          strategy the first source is the one that fills it (issue #2974).

          When the stop machine's decisions are recorded
          ({!record_stop_decision}), the first decision's [stop_before] — the
          level the machine actually held at the fill — replaces the
          decision-time install. The two differ when a ticket rested across a
          split: the machine's state was rescaled while the ticket waited, but
          no transition reported it (issue #3075, AAON-wein-951: installed 83.21
          at the 2023 decision, held 55.475 at the 2024 fill).

          {b Split while held} (issue #3127): when a later stop decision shows
          the machine rescaled by a split, this level is rescaled by the same
          factor, like {!max_stop}. It is then on the price basis of the exit,
          the basis [trades.csv] restates [entry_price] onto, so [entry_stop],
          [max_stop] and [exit_stop] of one row compare directly with its prices
          (CTO 2021: 50.38 pre-split became 16.79 beside an entry of 19.48).
          Without stop decisions it stays the level as installed.

          [None] when no source ever reported a level. *)
  exit_stop : float option;
      (** Stop-loss price at the time of exit: the last level installed, or the
          last level a {!record_stop_decision} showed the machine holding,
          whichever came later. The second source catches a split rescale while
          the position is held, which no transition reports. *)
  exit_trigger : exit_trigger option;
      (** What caused the exit. [None] if position is still open. *)
  max_stop : float option;
      (** The {b most-protective} stop level ever installed on this position —
          the running maximum of every installed level for a long, the running
          minimum for a short. Seeded from the initial stop ({!entry_stop}),
          then advanced by each [UpdateRiskParams] or {!record_stop_move} that
          installs a more protective level. [None] when no stop was ever
          installed (no initial stop and no [UpdateRiskParams] carrying a
          [stop_loss_price]).

          Side is taken from the position's [CreateEntering] transition. The
          collector tolerates a stream that never carries one — a position first
          seen at [EntryComplete] or [UpdateRiskParams] — and treats it as
          [Long]. The record convention is long-only, so that default is the
          common path rather than a fallback. It decides the direction of both
          this field and {!n_stop_raises}.

          Distinct from {!exit_stop}, which is the {e last} installed level: a
          split adjustment or any other rescale-downward rewrites [exit_stop]
          but leaves [max_stop] at the high-water mark, so the two together show
          whether the ratchet ever moved and whether it later gave ground.

          {b Split rescales}: when a {!record_stop_decision} shows the machine
          holding a {e less} protective level than the log's current one, that
          gap is a split rescale (the machine never gives ground otherwise), and
          [max_stop] is rescaled by the same factor so it stays on the current
          price basis as [exit_stop] and the two compare directly. Without stop
          decisions (a stream of transitions only) it remains a high-water mark
          over raw installed levels: on a position that went through a split it
          stays on the pre-split price scale while [exit_stop] is post-split, so
          compare the two only within one price scale. *)
  n_stop_raises : int;
      (** How many stop moves installed a level {b strictly more protective}
          than the level installed immediately before it (strictly higher for a
          long, strictly lower for a short). A move is an [UpdateRiskParams]
          transition or a {!record_stop_move} report (the stop state machine's
          [Entered_tightening] install, which emits no transition).

          Excludes the initial install ({!entry_stop}) — a position whose stop
          never moves after entry scores 0, and one raise after entry scores 1.
          Also excludes the first install seen on a position that had no prior
          level (an [UpdateRiskParams] arriving before any initial stop): that
          is an install, not a raise. Before issue #2974 the Weinstein
          strategy's initial stop never reached this log (its [EntryComplete]
          carries none), so every such position hit that case and under-counted
          by one.

          {b Split adjustments cannot inflate this for longs.} A split rescales
          price {e and} stop {b downward} together, so the post-split level is
          strictly {e less} protective than the pre-split one and the
          strictly-more-protective test rejects it. A genuine ratchet that
          happens to occur after a split still counts, because it is compared
          against the (already rescaled) previous level, not against a pre-split
          one. *)
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
    - [CreateEntering] records symbol, position_id and the position's side (the
      side decides which direction counts as "more protective" for
      {!stop_info.max_stop} / {!stop_info.n_stop_raises})
    - [EntryComplete] stamps {!stop_info.entry_date} with the most recent
      {!set_current_date}, and — only when its risk_params carry a
      [stop_loss_price] — records that level as the initial stop and seeds
      {!stop_info.max_stop} with it. A [None] stop leaves any level already
      booked by {!record_installed_stop} intact.
    - [UpdateRiskParams] updates current stop-loss price, advances
      {!stop_info.max_stop} when the new level is more protective, and
      increments {!stop_info.n_stop_raises} when it is strictly so
    - [TriggerExit] records exit trigger and final stop level. A simulator
      margin exit ([margin_call] / [buyin_stress] / [maintenance_reduce]) does
      {b not} overwrite a trigger already recorded for the same position on the
      same transition date (#3147): [Margin_runner] drops a colliding strategy
      exit (a stop-loss, a force liquidation) in favour of its own, and the
      label keeps the strategy's decision, as [trade_audit.sexp] and
      [force_liquidations.sexp] record it. A margin exit with no same-day
      strategy exit is still labelled by its own label.
    - [ExitComplete] without a preceding [TriggerExit] tags
      [exit_trigger = End_of_period] (simulator end-of-run auto-close). An
      [ExitComplete] that follows a [TriggerExit] keeps the strategy's original
      trigger — the fallback is only applied when [exit_trigger] is still
      [None]. *)

val record_installed_stop :
  t -> position_id:string -> symbol:string -> level:float -> unit
(** Book [level] as [position_id]'s initial stop: sets {!stop_info.entry_stop},
    makes it the current level ({!stop_info.exit_stop} until something moves it)
    and seeds {!stop_info.max_stop}. Never counts as a raise.

    The backtest wires this to the strategy's entry-decision audit event
    ([Audit_recorder.entry_event.installed_stop]), which fires before the
    position's [CreateEntering] is recorded — so the position may be first seen
    here; its side is filled in later by [CreateEntering]. This is the only
    source of the initial stop for the Weinstein strategy, whose simulator-side
    [EntryComplete] carries none (issue #2974). *)

val record_stop_move : t -> position_id:string -> level:float -> unit
(** Observe a stop move that no transition carries (the strategy's
    [Entered_tightening] install, reported via
    [Audit_recorder.t.record_stop_move]). Treated exactly like an
    [UpdateRiskParams] to [level]: it becomes the current level, advances
    {!stop_info.max_stop} when more protective, and increments
    {!stop_info.n_stop_raises} when strictly so. *)

val record_stop_decision :
  t -> position_id:string -> stop_before:float -> stop_after:float -> unit
(** Observe one advance of the position's stop state machine: the level it held
    going into the step ([stop_before]) and the level it left ([stop_after]).
    The backtest wires this to [Audit_recorder.t.record_stop_decision] (issue
    #2977), so the log follows the level the machine actually enforces rather
    than only what transitions report (issue #3075). Reporting only: nothing
    here feeds the strategy.

    - The position's {b first} decision is its fill: [stop_before] becomes
      {!stop_info.entry_stop}, the current level and the {!stop_info.max_stop}
      seed, replacing a decision-time install the machine no longer holds.
    - A later decision whose [stop_before] differs from the current level is a
      level change no transition carried. More protective: installed as a move
      (a raise when strictly so); its transition, when it arrives, is then an
      unchanged re-install. Less protective: a split rescale; the current level
      takes it and {!stop_info.max_stop} and {!stop_info.entry_stop} are
      rescaled by the same factor (#3127).
    - [stop_after] is then installed like an [UpdateRiskParams]: it becomes the
      current level, advances {!stop_info.max_stop}, and counts as a raise when
      strictly more protective. A move also reported by a transition counts
      once, whichever arrives first.

    A reverse split for a long (stop moved {e up} by a rescale), or a forward
    split for a short (stop moved {e down}), reads as a raise: this function
    sees levels, not the split factor, so it cannot tell the two apart. *)

val get_stop_infos : t -> stop_info list
(** Return stop info for all positions that have been observed, sorted by
    [position_id]. Positions still in Holding state will have
    [exit_trigger = None]. *)
