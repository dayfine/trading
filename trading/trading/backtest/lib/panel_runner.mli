(** Panel-loader execution path — Stage 1 of the columnar data-shape redesign
    (see [dev/plans/columnar-data-shape-2026-04-25.md]).

    Reuses the [Tiered_runner] execution path verbatim and additionally:

    1. Builds an [Ohlcv_panels.t] over the universe + a calendar of trading days
    in the backtest range. 2. Builds an [Indicator_panels.t] registry with the
    Stage 1 default specs (EMA-50 / SMA-50 / ATR-14 / RSI-14, all daily
    cadence). Spec list is compiled in (config-routed deferred to Stage 4 once
    the strategy actually consumes from the registry). 3. Wraps the inner
    strategy with [Panel_strategy_wrapper] so each [on_market_close] tick
    advances the panels and substitutes a panel- backed [get_indicator_fn].

    The [Bar_history] inside the inner Weinstein strategy stays alive — Stage 1
    does not delete it. The Weinstein strategy does not yet consume
    [get_indicator], so behaviour is identical to Tiered. The integration parity
    gate ([test_panel_loader_parity]) verifies this.

    The Panel state is held by the wrapper and lives for the duration of the
    simulator run. RSS impact: ~5 OHLCV panels + 4 indicator panels (+ 2 RSI
    scratch) at [Symbol_index.n] × [n_days] × 8 bytes each. For the parity
    scenario (7 symbols × ~150 days) this is ~85 KiB total, negligible. *)

val run :
  input:Tiered_runner.input ->
  start_date:Core.Date.t ->
  end_date:Core.Date.t ->
  warmup_days:int ->
  initial_cash:float ->
  commission:Trading_engine.Types.commission_config ->
  ?trace:Trace.t ->
  unit ->
  Trading_simulation_types.Simulator_types.run_result * Stop_log.t
(** Same signature as {!Tiered_runner.run}. The Panel branch in [Runner] uses
    this; callers should not call this directly outside of tests. *)
