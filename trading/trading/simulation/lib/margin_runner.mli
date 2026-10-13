(** Per-step margin mechanics for the simulator (issue #859 Phase 2).

    Adapts the Phase-1 {!Trading_portfolio.Portfolio_margin} primitives to the
    simulator's per-day tick: accrue one trading day of short borrow fee, then
    flag any short position whose maintenance margin has been breached. Both
    operations are strategy-agnostic — margin is a broker mechanic that any
    strategy opening short positions benefits from, not Weinstein-specific
    logic.

    All entry points are pure functions; the simulator's caller threads the
    updated [Portfolio.t] and the generated margin-call transitions back into
    its per-step state.

    {b Default-off invariant.} When [margin_config.enabled = false] (the
    {!Trading_portfolio.Margin_config} default), every function in this module
    is a bit-equal no-op: portfolio state is returned unchanged and no
    transitions are generated. This lets the simulator hold long-only baselines
    bit-equal until the flag is opted into via configuration.

    Authority: [dev/plans/short-side-margin-2026-05-13.md] §2. *)

open Core
module Margin_config = Trading_portfolio.Margin_config
module Portfolio = Trading_portfolio.Portfolio
module Position = Trading_strategy.Position

val mark_prices : Trading_engine.Types.price_bar list -> (string * float) list
(** Project per-symbol [(symbol, close_price)] from today's price bars. Pure
    helper exposed so callers (tests, runner) can build the same input the
    margin primitives consume. *)

val accrue_borrow_fee :
  margin_config:Margin_config.t ->
  portfolio:Portfolio.t ->
  prices:(string * float) list ->
  Portfolio.t
(** Apply one trading day of borrow-fee accrual to [portfolio]. Thin wrapper
    over {!Trading_portfolio.Portfolio_margin.accrue_daily_borrow_fee}.

    Returns [portfolio] unchanged when [margin_config.enabled = false] or when
    the portfolio holds no short positions. *)

val accrue_long_margin_interest :
  long_margin_rate_annual_pct:float -> portfolio:Portfolio.t -> Portfolio.t
(** Capitalize one trading day of long-margin interest onto the portfolio's
    outstanding [long_margin_debit] (margin M1b-2). Thin wrapper over
    {!Trading_portfolio.Portfolio_margin.accrue_daily_long_margin_interest}.

    Returns [portfolio] unchanged at the default rate ([0.0]) or with no debit,
    so long-only / cash-account baselines stay bit-equal. Gated by the rate, not
    [Margin_config.enabled] — long leverage is a separate dial. *)

val margin_call_transitions :
  margin_config:Margin_config.t ->
  portfolio:Portfolio.t ->
  positions:Position.t String.Map.t ->
  prices:(string * float) list ->
  date:Date.t ->
  Position.transition list
(** Build [TriggerExit] transitions for every short position whose maintenance
    margin has been breached on this tick.

    For each symbol flagged by
    {!Trading_portfolio.Portfolio_margin.check_maintenance_margin}, the
    corresponding strategy-side {!Position.t} is located by matching on symbol
    + [Holding] state (other states represent positions already in the
      open/close pipeline; the simulator's regular fill machinery handles them).
      The transition carries
      [exit_reason = StrategySignal { label = "margin_call"; detail = Some
       "<key=value>" }] so downstream audit / trades.csv writers group the exits
      correctly. The free-form [detail] payload encodes the entry-avg-cost and
      current price for forensic review without adding a new variant to the
      shared {!Position.exit_reason} surface.

    Returns the empty list when [margin_config.enabled = false], when there are
    no shorts breaching maintenance, or when no matching [Holding] position can
    be located for the flagged symbol (e.g. the short is already mid-exit on
    this tick). *)

val dedup_strategy_exits_for_margin :
  strategy_transitions:Position.transition list ->
  margin_trans:Position.transition list ->
  Position.transition list
(** Drop any [TriggerExit] in [strategy_transitions] whose [position_id] matches
    a transition in [margin_trans]. Resolves the same-tick same-position
    collision described in issue #1266: the [Position.t] state machine accepts
    [Holding _ -> TriggerExit] only once per position, so a strategy-side
    stop-loss exit and a margin-call exit targeting the same short on the same
    bar would otherwise crash the second application. Margin wins by priority —
    it carries forensic detail ([entry_avg_cost], [current_price]) the
    strategy's exit doesn't.

    Only [TriggerExit] kinds are filtered. Other strategy transitions on the
    same position-id (e.g. [UpdateRiskParams]) pass through unchanged. *)

val drop_margin_exits_for_traded_stops :
  strategy_transitions:Position.transition list ->
  margin_trans:Position.transition list ->
  positions:Position.t String.Map.t ->
  today_bars:Trading_engine.Types.price_bar list ->
  Position.transition list
(** Issue #3206. Remove from [margin_trans] every transition whose position has
    a [StopLoss] [TriggerExit] in [strategy_transitions] AND whose own bar in
    [today_bars] trades through that stop level
    ({!Trigger_bar_stop_fill.bar_reaches_stop}; side from the position: long
    stop = Sell, short stop = Buy). With trigger-bar stop fills armed the stop
    is a resting order that fills intraday on that bar (book §5.7), while the
    maintenance checks run on the close, so the stop wins and the later
    {!dedup_strategy_exits_for_margin} then finds nothing to collide with. A
    stop the bar did not reach (e.g. a catastrophic-stop exit) or a position
    with no bar today keeps the margin-wins rule. Margin transitions for
    positions without a strategy [StopLoss] pass through unchanged. *)

val tick :
  margin_config:Margin_config.t ->
  long_margin_rate_annual_pct:float ->
  maintenance_long_pct:float ->
  stop_beats_margin_cover:bool ->
  portfolio:Portfolio.t ->
  positions:Position.t String.Map.t ->
  today_bars:Trading_engine.Types.price_bar list ->
  date:Date.t ->
  strategy_transitions:Position.transition list ->
  Portfolio.t * Position.transition list
(** One simulator-tick worth of margin mechanics: accrue daily short borrow fee,
    capitalize daily long-margin interest ([long_margin_rate_annual_pct], margin
    M1b-2), then append three families of forced exits to [strategy_transitions]
    — short-side maintenance force-covers ({!margin_call_transitions}),
    long-side maintenance force-reduces ([maintenance_long_pct], margin M2, via
    {!Long_maintenance.maintenance_reduce_transitions}), and short-side buy-in
    stress covers ([margin_config.short_buyin_stress_mode], margin M3b, via
    {!Short_buyin.buyin_stress_transitions}) — all on the weekly-close (Friday)
    cadence. No-op on portfolio state and transitions when
    [margin_config.enabled = false], [long_margin_rate_annual_pct = 0.0],
    [maintenance_long_pct = 0.0], and
    [margin_config.short_buyin_stress_mode = false] (preserves baselines
    bit-equal).

    Resolves same-tick same-position [TriggerExit] collisions between the
    strategy and margin sources via {!dedup_strategy_exits_for_margin}: margin
    transitions (short covers, long reduces, buy-ins) win, strategy exits for
    the same position-id are dropped. See issue #1266 for the dotcom-2000-2002
    crash this prevents. Within the margin sources, a short flagged by both the
    maintenance check and the buy-in mode is covered once — the maintenance
    [margin_call] wins (richer forensic detail), the duplicate [buyin_stress] is
    dropped.

    [stop_beats_margin_cover] (issue #3206, default off upstream): when [true],
    a margin transition is first dropped for any position whose strategy
    [StopLoss] exit traded on today's bar
    ({!drop_margin_exits_for_traded_stops}), so the stop (filled on the trigger
    bar when the caller armed [Trigger_bar_stop_fill]) wins the collision
    instead of the margin cover. [false] keeps margin-wins, bit-identical. The
    caller passes [true] only when trigger-bar stop fills are armed. *)
