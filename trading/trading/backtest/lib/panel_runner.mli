(** Panel-loader execution path — Stage 1 of the columnar data-shape redesign
    (see [dev/plans/columnar-data-shape-2026-04-25.md]).

    Builds:

    1. An [Ohlcv_panels.t] over the universe + a calendar of trading days in the
    backtest range. 2. A [Bar_panels.t] view over those panels — the canonical
    OHLCV source the inner Weinstein strategy reads from. 3. An
    [Indicator_panels.t] registry with the Stage 1 default specs (EMA-50 /
    SMA-50 / ATR-14 / RSI-14, all daily cadence). Spec list is compiled in
    (config-routed deferred to Stage 4 once the strategy actually consumes from
    the registry).

    Wraps the inner strategy with [Panel_strategy_wrapper] so each
    [on_market_close] tick advances the panels and substitutes a panel-backed
    [get_indicator_fn].

    Stage 3 PR 3.3 deleted the Tiered tier system + the parallel [Bar_history]
    cache. There is no in-memory tier bookkeeping anymore — the panels are fully
    populated up-front from CSV and the strategy reads from them directly via
    [Bar_panels.t]. *)

open Core

type input = {
  data_dir_fpath : Fpath.t;
  ticker_sectors : (string, string) Hashtbl.t;
  ad_bars : Macro.ad_bar list;
  config : Weinstein_strategy.config;
  all_symbols : string list;
}
(** Minimal subset of {!Runner._deps} that [Panel_runner] needs. Kept as a plain
    record so [Runner] can build it without exporting its private [_deps] type.
*)

val run :
  input:input ->
  start_date:Date.t ->
  end_date:Date.t ->
  warmup_days:int ->
  initial_cash:float ->
  commission:Trading_engine.Types.commission_config ->
  ?trace:Trace.t ->
  unit ->
  Trading_simulation_types.Simulator_types.run_result * Stop_log.t
(** Same shape as the Legacy path's per-strategy entry point. The Panel branch
    in [Runner] uses this; callers should not call this directly outside of
    tests. *)
