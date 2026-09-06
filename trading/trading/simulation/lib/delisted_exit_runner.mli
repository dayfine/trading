(** Exits a held position when its symbol's delisting marker is reached.

    A symbol's [active_through] (the manifest's per-symbol last-active day,
    surfaced by [Snapshot_runtime.Daily_panels.active_through_for]) says the
    series ENDS on that date because the security stopped existing — a cash
    merger, an acquisition, a bankruptcy delisting. Once
    [date > active_through], holding the position is meaningless: no further bar
    will ever arrive.

    This is a {b first-class, EXPECTED exit}, not a fallback. It runs BEFORE
    {!Stale_exit_runner} — see {!Forced_exit_step}, which owns that ordering —
    in the simulator step precisely so that a {e marked} delisting never reaches
    the stale safety net and never counts as a data-quality flag. After this
    runs, a ["stale_force_exit"] row can only mean "a symbol stopped printing
    bars and nothing in the warehouse explains why" — which is a defect by
    definition. See [dev/plans/delisting-data-fix-2026-09-06.md] §"Principle:
    fallbacks are quality flags, not mechanisms".

    {2 Data-driven, not a strategy mechanism — no config flag}

    There is deliberately no knob here. Whether a position exits is a function
    of the {b data} (does the warehouse carry a marker for this symbol?), not of
    a tuning choice, so [experiment-flag-discipline.md] R1's "default-off"
    obligation is met structurally:
    {b no warehouse populates [active_through] today} (the EODHD bar parser
    leaves it [None] and no enrichment pass exists yet — PR-A of the plan adds
    one), so every lookup returns [None], every run is a no-op, and every golden
    is bit-identical. When the warehouses are rebuilt with markers, it fires as
    intended without a spec change.

    Mechanically, the runner is armed wherever
    [Simulator.dependencies.active_through_for] is supplied; under
    {!Backtest.Panel_runner} that is unconditional (it is read straight off the
    run's [Daily_panels.t]).

    The runner is strategy-agnostic: it operates on the broker portfolio and the
    generic [Position.t] state machine. Mechanics are shared with
    {!Stale_exit_runner} via {!Forced_exit}; only the selection policy and the
    label differ. *)

open Core

val exit_reason : Date.t -> Trading_strategy.Position.exit_reason
(** [exit_reason active_through] is the [Position.exit_reason] stamped on the
    exit: a [StrategySignal] tagged [label = "delisted"], with
    [detail = Some "active_through=<d>"].

    ["delisted"] is the value that reaches the [exit_trigger] column of
    [trades.csv] (via [Backtest.Stop_log.record_transitions], #2687). Unlike
    ["stale_force_exit"] / ["margin_call"] / the force-liquidation labels, it is
    {b not} counted as a fallback by the post-run validator's V16 report — a
    delisting is an expected market event, not a defect. Pure. *)

val tick :
  adapter:Trading_simulation_data.Market_data_adapter.t ->
  active_through_for:(string -> Date.t option) ->
  commission:Trading_engine.Types.commission_config ->
  date:Date.t ->
  today_bars:Trading_engine.Types.price_bar list ->
  portfolio:Trading_portfolio.Portfolio.t ->
  positions:Trading_strategy.Position.t String.Map.t ->
  unit ->
  Trading_portfolio.Portfolio.t
  * Trading_strategy.Position.t String.Map.t
  * Trading_base.Types.trade list
  * Trading_strategy.Position.transition list
(** Exit every held position whose symbol's delisting marker has passed. A
    position is selected when all of:

    - [active_through_for symbol = Some d] — the symbol carries a marker;
    - [Core.Date.(date > d)] — the marker is strictly in the past, so the
      symbol's last real bar is behind us. A marker in the future, or one dated
      today, selects nothing: the series is still live;
    - a price can be resolved (below), and the held quantity is non-zero.

    The exit price is the symbol's last {b real} close, resolved in order:
    [get_price ~date:d] (the marker day's own bar — the precise answer), then
    [get_previous_bar ~date] (the last bar before today). If neither resolves,
    the position is {b left alone} rather than exited at an invented price: it
    then falls through to {!Stale_exit_runner}, which is the correct outcome,
    because a marked symbol whose bars cannot be read at all is a warehouse
    defect and should be flagged as one.

    Returns [(portfolio, positions, trades, transitions)] in selection order,
    with the same contract as {!Stale_exit_runner.tick} — see {!Forced_exit} for
    the shared mechanics. Returns the inputs unchanged (both lists empty) when
    [today_bars] is empty (no exit on a weekend / holiday, matching
    {!Stale_exit_runner}) or when no held position has a passed marker — which
    is every run on every warehouse built to date, since none populates
    [active_through]. *)
