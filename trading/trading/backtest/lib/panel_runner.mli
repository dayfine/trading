(** Panel-loader execution path — runner-side seam for the simulator + Weinstein
    strategy.

    The runner uses a hybrid setup (partial revert of #828, closes #843):

    - The strategy's [Bar_reader] is panel-backed: an [Ohlcv_panels.t] is loaded
      from CSV via [Ohlcv_panels.load_from_csv_calendar] at runner start,
      wrapped in a [Bar_panels.t], and exposed via [Bar_reader.of_panels]. The
      F.3.a-3 attempt to migrate the strategy's reads to [Snapshot_callbacks]
      produced a path-dependent regression on sp500-2019-2023 (#843).
    - The simulator's per-tick price reads flow through a snapshot-backed
      [Market_data_adapter]. CSV mode builds the snapshot directory in-process
      from CSV bars at runner start (via [Csv_snapshot_builder]); Snapshot mode
      reuses a pre-built directory.
    - Final close-price lookups read from the [Snapshot_runtime.Daily_panels]
      via [Daily_panels.read_today].

    The [Panel_strategy_wrapper] (panel-backed [get_indicator_fn] injector) is
    gone — the Weinstein strategy ignores [get_indicator], so the wrapper was
    pure overhead. The [Indicator_panels.t] allocation is also gone. *)

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
  ?progress_emitter:Backtest_progress.emitter ->
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
    collected at the strategy's entry / exit decision sites, the
    force-liquidation event log, and an alist of [(symbol, close_price)] read
    from the snapshot's [Close] column for [end_date] for every universe symbol
    with a non-NaN close on that date. The consumer ([Runner]) filters
    [final_close_prices] to symbols still held at end of run when populating
    [Runner.result.final_prices].

    [gc_trace], when passed, snapshots [Gc.stat] before and after every
    simulator step (one step = one calendar day = one [Engine.update_market]
    call). Phase labels are shaped [step_<YYYY-MM-DD>_before] and
    [step_<YYYY-MM-DD>_after] so the per-day delta is recoverable from the CSV
    by pairing labels. Used by PR-1 of the engine-pooling plan
    ([dev/plans/engine-layer-pooling-2026-04-27.md]) to confirm on real data
    that [Engine.update_market] dominates the per-tick allocator profile before
    the buffer-reuse refactors land. When [gc_trace] is omitted, the runner
    takes no per-step snapshots and the cost is one [None] match per step.

    [progress_emitter], when passed, threads a periodic-checkpoint hook into the
    per-step loop. On every [emitter.every_n_fridays]-th Friday the runner
    builds a {!Backtest_progress.t} reflecting cycles done / total / last
    completed date / cumulative trade count / current equity, and invokes
    [emitter.on_progress] with it. The final completed step also fires an
    emission unconditionally so a [progress.sexp] always reflects the run's end
    state. When [None], the runner takes no extra work — same zero-overhead
    contract as the other optional plumbing.

    [bar_data_source], when passed, selects how the simulator's snapshot
    directory is sourced. (The strategy's panel-backed bar reader is unaffected
    — it always loads from CSV at runner start.)

    - Default ({!Bar_data_source.Csv}) builds a snapshot directory in-process
      from the universe's CSV bars at runner start, then routes the simulator
      through it.

    - {!Bar_data_source.Snapshot} reuses a caller-provided pre-built snapshot
      directory + manifest (typically written by [build_snapshots.exe]).

    Both branches use the same hybrid wiring (panel-backed strategy reader +
    snapshot-backed simulator adapter); the only difference is whether the
    snapshot directory was materialised in-process or supplied externally. See
    `dev/notes/parity-bisect-...md` for the partial-revert bisect. *)
