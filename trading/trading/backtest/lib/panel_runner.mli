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
  ?gc_trace:Gc_trace.t ->
  ?bar_data_source:Bar_data_source.t ->
  unit ->
  Trading_simulation_types.Simulator_types.run_result
  * Stop_log.t
  * Trade_audit.t
  * Force_liquidation_log.t
  * (string * float) list
(** Same shape as the Legacy path's per-strategy entry point. The Panel branch
    in [Runner] uses this; callers should not call this directly outside of
    tests.

    Returns a 5-tuple
    [(run_result, stop_log, trade_audit, force_liquidation_log,
     final_close_prices)]: the simulator output, the per-position stop log
    accumulated by the strategy wrapper, the per-trade decision-trail audit
    collected at the strategy's entry / exit decision sites (PR-2 of the
    trade-audit plan), the force-liquidation event log, and an alist of
    [(symbol, close_price)] read from the [Bar_panels.t] last calendar column
    for every symbol in the universe with a non-NaN close at run end. The
    consumer ([Runner]) filters [final_close_prices] to symbols still held at
    end of run when populating [Runner.result.final_prices].

    [gc_trace], when passed, snapshots [Gc.stat] before and after every
    simulator step (one step = one calendar day = one [Engine.update_market]
    call). Phase labels are shaped [step_<YYYY-MM-DD>_before] and
    [step_<YYYY-MM-DD>_after] so the per-day delta is recoverable from the CSV
    by pairing labels. Used by PR-1 of the engine-pooling plan
    ([dev/plans/engine-layer-pooling-2026-04-27.md]) to confirm on real data
    that [Engine.update_market] dominates the per-tick allocator profile before
    the buffer-reuse refactors land. When [gc_trace] is omitted, the runner
    takes no per-step snapshots and the cost is one [None] match per step.

    [bar_data_source], when passed, selects the OHLCV backend used by both the
    simulator's per-tick price reads AND the strategy's bar reads.

    - Default ({!Bar_data_source.Csv}) is the pre-Phase-D behaviour: build OHLCV
      / Indicator / Bar panels up front from CSV; the strategy reads via
      [Bar_panels.t] through [Bar_reader.of_panels]; the simulator's
      [Market_data_adapter] reads from CSV.

    - {!Bar_data_source.Snapshot} switches both surfaces to the snapshot
      backing. Phase F.2 PR 2 (snapshot-engine plan) made this branch skip the
      [Bar_panels.t] / [Ohlcv_panels.t] / [Indicator_panels.t] allocation
      entirely — these were the dominant resident-set cost at tier-4 universe
      sizes (~27 GB at N=5000 × 10y). The strategy reads via
      [Bar_reader.of_snapshot_views] over [Snapshot_runtime.Daily_panels]
      (LRU-bounded, [_snapshot_cache_mb] cap); the simulator's adapter is the
      same callback-mode adapter Phase D introduced. The snapshot path keeps no
      calendar-wide bigarray panel resident.

    Phase D wired the simulator surface; Phase F.2 PR 2 wires the strategy
    surface. See [dev/plans/snapshot-engine-phase-d-2026-05-02.md] and the Phase
    F notes in [dev/plans/daily-snapshot-streaming-2026-04-27.md]. *)
