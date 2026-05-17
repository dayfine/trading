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

val tick :
  margin_config:Margin_config.t ->
  portfolio:Portfolio.t ->
  positions:Position.t String.Map.t ->
  today_bars:Trading_engine.Types.price_bar list ->
  date:Date.t ->
  strategy_transitions:Position.transition list ->
  Portfolio.t * Position.transition list
(** One simulator-tick worth of margin mechanics: accrue daily borrow fee, then
    append any maintenance-margin-breach exits to [strategy_transitions]. No-op
    when [margin_config.enabled = false] (preserves baselines bit-equal). *)
