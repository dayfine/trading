(** Long-side maintenance force-reduce (levered long-short realism, M2).

    The long-book mirror of the short-side maintenance force-cover
    ({!Trading_portfolio.Portfolio_margin.check_maintenance_margin} +
    {!Margin_runner.margin_call_transitions}): when a levered long book's equity
    has eroded relative to its marked long exposure, the broker calls the loan
    and forces a partial deleveraging. This module decides {e which} held longs
    to shed and emits the corresponding [TriggerExit] transitions.

    {1 The maintenance ratio}

    For the long book, [equity = equity_cash + marked_long_exposure] where
    [equity_cash = current_cash - long_margin_debit]
    ({!Trading_portfolio.Portfolio_margin.equity_cash}, margin M1b-2) and
    [marked_long_exposure] is the sum of [quantity * today's mark] over held
    long positions that have a mark today. A breach is
    [equity /. marked_long_exposure < maintenance_long_pct]. The check operates
    on {e marked} (priced-today) long exposure only; a held long with no bar
    today is excluded from both the exposure and the reduce candidates (it
    cannot be marked or filled today).

    {b Short book excluded.} Shorts' marked P&L is deliberately {e not} folded
    into this long-maintenance equity — the short book carries its own,
    independent maintenance surface
    ({!Trading_portfolio.Portfolio_margin.check_maintenance_margin}). The
    numerator here is the standard long-account equity (cash net of the long
    debit, plus long market value), exact for the long-only levered book this
    mechanism targets.

    {b An unlevered book never fires.} With no debit and non-negative cash,
    [equity_cash >= 0] so [equity >= marked_long_exposure] and the ratio is
    [>= 1.0], above any sane [maintenance_long_pct]. Only leverage
    ([long_margin_debit > 0] pushing [equity_cash] down) can breach — exactly
    the Run-E "levering on short proceeds" artifact this prices.

    {1 Cadence}

    Weekly-close (Friday) only, to match the strategy spine — the reduce runs at
    the weekly boundary, not every daily tick. {b Bar-cadence limitation:} the
    marks are daily closes, so this check cannot see an intraweek
    gap-through-maintenance move (a Monday-to-Thursday crash is only observed at
    Friday's close). Modelling those gap paths is M3/M4 stress-path territory,
    not this runner.

    {1 The reduce ordering — the design center}

    On a breach the runner sells the {b weakest holdings first}, weakness being
    {b ascending unrealized return since entry} ([mark /. entry_price - 1.0]),
    ties broken by symbol for determinism. Rationale (the Portfolio_floor
    bottom-tick lesson: the ORDER is where these mechanisms go wrong):

    - Selling any long at its mark leaves equity unchanged (proceeds convert
      marked value to cash / debit-paydown 1:1) and shrinks the denominator, so
      {e which} names are sold does not change how fast the ratio is restored —
      it only decides which names the book keeps. Shedding the worst-P&L names
      keeps the winners, which is the tail-preserving choice (the edge is the
      let-winners-run fat tail).
    - {b Not the laggard-rotation metric.} {!Laggard_rotation_runner} ranks by
      relative strength vs. the benchmark over a rolling window — a different
      quantity that needs benchmark history and a [Bar_reader], neither
      available at this fill/margin seam. A margin reduce wants the position
      closest to being underwater (the least costly, most prudent to shed),
      which is unrealized return since entry, computed directly here.

    Reduction is {b incremental and whole-position} (mirroring the short-side
    force-cover, which closes whole flagged shorts): the runner sells weakest
    holdings one at a time until
    [equity /. marked_long_exposure >= maintenance_long_pct *. (1 +.
     restore_buffer_pct)], then stops — stronger positions are untouched. It
    never liquidates the whole book in one sweep unless equity is fully wiped
    ([equity <= 0]), in which case no partial reduce can restore the ratio and
    the book is liquidated (a margin call that cannot be met).

    {b Debit interaction (M1b-2 semantics).} Each forced sale's proceeds pay
    down [long_margin_debit] first (via
    {!Trading_portfolio.Portfolio_margin.apply_single_trade_with_long_margin} at
    the fill seam) before adding to cash — paying down the debit is itself what
    lifts [equity_cash], and thus the ratio, back above the requirement.

    {b Default-off invariant (experiment-flag-discipline R1).} At
    [maintenance_long_pct = 0.0] (the config default — a cash account has no
    maintenance requirement) every entry point returns [[]]: the mechanism never
    fires and every existing golden/baseline replays bit-identically.

    Authority: [dev/plans/levered-longshort-margin-realism-2026-07-14.md] §M2.
*)

open Core
module Portfolio = Trading_portfolio.Portfolio
module Position = Trading_strategy.Position

val restore_buffer_pct : float
(** The small restore buffer: the reduce target ratio is
    [maintenance_long_pct *. (1.0 +. restore_buffer_pct)], leaving headroom
    above the bare requirement so ordinary mark noise on the next weekly check
    does not immediately re-trigger a reduce. [0.02] (2%). *)

type long_holding = {
  position_id : string;
  symbol : string;
  quantity : float;  (** Shares held (positive for a long). *)
  entry_price : float;
      (** Average entry price; positive by position invariant. *)
  mark : float;  (** Today's close for the symbol. *)
}
(** A held long marked at today's close — the unit the reduce selector ranks and
    sheds. Exposed so the ordering can be pinned directly with plain data. *)

val select_reductions :
  equity:float ->
  maintenance_long_pct:float ->
  holdings:long_holding list ->
  long_holding list
(** Pure weakest-first incremental reduce selector. Returns the sublist of
    [holdings] to force-exit (whole positions), ordered weakest-first (ascending
    [mark /. entry_price - 1.0], ties by symbol).

    Returns [[]] (no reduce) when any of:
    - [maintenance_long_pct <= 0.0] (R1 no-op),
    - [holdings] is empty or their total marked value is [<= 0.0],
    - the ratio is not breached
      ([equity /. marked_long_exposure >= maintenance_long_pct]).

    On a breach it sheds weakest holdings until the running
    [marked_long_exposure] falls to at most [equity /. target_ratio] where
    [target_ratio = maintenance_long_pct *. (1.0 +. restore_buffer_pct)], then
    stops (stronger positions untouched). When [equity <= 0.0] no positive
    exposure can satisfy the ratio, so every holding is returned (full
    liquidation of an insolvent book). *)

val maintenance_reduce_transitions :
  maintenance_long_pct:float ->
  portfolio:Portfolio.t ->
  positions:Position.t String.Map.t ->
  prices:(string * float) list ->
  date:Date.t ->
  Position.transition list
(** Build [TriggerExit] transitions for the held longs {!select_reductions}
    picks on a maintenance breach. Returns [[]] when [date] is not a Friday
    (weekly cadence), when [maintenance_long_pct <= 0.0] (R1), when there are no
    priced held longs, or when the ratio is not breached.

    Each emitted transition carries
    [exit_reason = StrategySignal { label = "maintenance_reduce"; detail = Some
     "<key=value>" }] (so forensics / trades.csv separate margin reduces from
    strategy exits) and [exit_price] equal to the symbol's mark. [equity] is
    computed as [Portfolio_margin.equity_cash portfolio +. marked_long_exposure]
    over the priced held longs. *)
