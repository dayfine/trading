(** Panel-loader execution path — runner-side seam for the simulator + Weinstein
    strategy.

    Post-#848 forward fix (PR2 of two; PR1 #861 added the [~calendar] plumbing
    on [Snapshot_bar_views] / [Bar_reader.of_snapshot_views]). All three reader
    surfaces fan out from one snapshot directory:

    - The strategy's [Bar_reader] is snapshot-backed:
      [Bar_reader.of_snapshot_views ~calendar] is built over a
      [Snapshot_callbacks.of_daily_panels] shim around the same [Daily_panels.t]
      the simulator and final-close lookup use. The [~calendar] argument is the
      trading-day calendar (Mon–Fri, holidays included) the runner builds for
      the warmup..end_date span; threading it through makes
      [Snapshot_bar_views.daily_view_for] walk calendar columns NaN-passthrough
      deterministically. This is the closing half of #848 — see
      `dev/notes/path-dependent-regression-848-investigation-2026-05-05.md` for
      the cell-by-cell parity surface.
    - The simulator's per-tick price reads flow through a snapshot-backed
      [Market_data_adapter]. CSV mode builds the snapshot directory in-process
      from CSV bars at runner start (via [Csv_snapshot_builder]); Snapshot mode
      reuses a pre-built directory.
    - Final close-price lookups read from the [Snapshot_runtime.Daily_panels]
      via [Daily_panels.read_today].

    The runner holds no parallel panel-backed bar storage — every read fans out
    from the snapshot directory. *)

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

    [bar_data_source], when passed, selects how the snapshot directory is
    sourced. The strategy's bar reader, the simulator adapter, and the
    final-close lookup all read through this same snapshot.

    - Default ({!Bar_data_source.Csv}) builds a snapshot directory in-process
      from the universe's CSV bars at runner start, then routes the simulator
      through it.

    - {!Bar_data_source.Snapshot} reuses a caller-provided pre-built snapshot
      directory + manifest (typically written by [build_snapshots.exe]).

    Both branches use the same wiring (snapshot-backed strategy reader +
    snapshot-backed simulator adapter, fanning out from one [Daily_panels.t]);
    the only difference is whether the snapshot directory was materialised
    in-process or supplied externally. See
    `dev/notes/path-dependent-regression-848-investigation-2026-05-05.md` for
    the path-dependence surface this rewiring closes. *)
