(** Selector for which OHLCV backend the simulator's per-tick price reads use.

    Phase D of the daily-snapshot streaming pipeline (see
    [dev/plans/snapshot-engine-phase-d-2026-05-02.md] and
    [dev/plans/daily-snapshot-streaming-2026-04-27.md] §Phasing Phase D).

    Two modes:

    - {!Csv} — default; the simulator reads OHLCV from per-symbol CSV files via
      [Trading_simulation_data.Market_data_adapter.create]. Identical to
      pre-Phase-D behaviour.
    - {!Snapshot} — the simulator reads OHLCV from a directory of per-symbol
      [.snap] files written by Phase B (see
      [analysis/weinstein/snapshot_pipeline]). Backed by
      [Snapshot_runtime.Daily_panels].

    The selector is inert until handed to {!build_adapter}, which constructs a
    [Market_data_adapter.t] tied to the chosen backend. The simulator never sees
    the selector — it consumes the resulting adapter via the same per-tick
    interface in either mode, so parity follows by construction. *)

type t =
  | Csv
  | Snapshot of {
      snapshot_dir : string;
          (** Directory containing per-symbol [.snap] files. Manifest entries'
              relative [path] fields resolve against this directory. *)
      manifest : Snapshot_pipeline.Snapshot_manifest.t;
          (** Pre-loaded manifest — typically read from
              [snapshot_dir/manifest.sexp] via [Snapshot_manifest.read]. *)
    }  (** Selector value. *)

val build_adapter :
  t ->
  data_dir:Fpath.t ->
  max_cache_mb:int ->
  Trading_simulation_data.Market_data_adapter.t Status.status_or
(** [build_adapter t ~data_dir ~max_cache_mb] constructs the
    [Market_data_adapter.t] the simulator will read through.

    For {!Csv}: returns [Ok (Market_data_adapter.create ~data_dir)] — pure
    dispatch, never errors.

    For {!Snapshot _}: builds a [Daily_panels.t] over the snapshot directory
    + manifest with the given [max_cache_mb] cap, wires it through
      {!Snapshot_bar_source.make_callbacks}, and returns the resulting
      callback-mode adapter. Returns [Error] when [Daily_panels.create] fails
      (e.g. invalid cap; corrupt manifest).

    Callers that already hold a [Daily_panels.t] (e.g. {!Backtest.Panel_runner},
    which builds one for the strategy bar reader) should prefer
    {!build_adapter_from_panels} to avoid constructing a second LRU cache over
    the same snapshot directory — see Cliff #2 in
    [dev/notes/15y-memory-cliff-2026-05-08.md]. *)

val build_shared_panels :
  t -> Snapshot_runtime.Daily_panels.t option Status.status_or
(** [build_shared_panels t] builds a caller-owned [Daily_panels.t] when [t] is a
    {!Snapshot} (returns [Ok (Some panels)]), or [Ok None] for {!Csv} (CSV mode
    builds a per-run in-process snapshot, so there is nothing reusable to
    share). The cache cap is resolved via
    {!Snapshot_cache_config.resolve_cache_mb} — the same cap {!Panel_runner.run}
    would use for its per-run cache, so RSS behaviour is unchanged. The returned
    cache is lazy: it decodes a symbol on first access, not eagerly here.

    The intended use is the broad-universe walk-forward parallel=1 loop: build
    the cache once in the parent, run each fold in a forked child (via
    {!Fork_pool.run_each_forked}) that reads through it as [~shared_panels] and
    does NOT close it, then {!close_shared_panels} once after all folds. The
    parent owns the lifecycle so the child's [run_backtest] leaves it open.

    RSS / [VMAllocationTracker] safety on that path comes from running each fold
    in its own child ({!Fork_pool.run_each_forked}) — whose exit reclaims the
    fold's decode + transient heap and resets the slab — NOT from cross-fold
    cache reuse: each child decodes its own working set into its copy-on-write
    view and that decode dies with the child. In-process callers that issue
    several backtests against the same handle DO get true decode reuse (pinned
    by [test_shared_panels_reused_across_backtests]). Returns [Error] only when
    [Daily_panels.create] fails (corrupt manifest / invalid cap). *)

val close_shared_panels : Snapshot_runtime.Daily_panels.t -> unit
(** [close_shared_panels p] drops every cached symbol in [p]
    ({!Snapshot_runtime.Daily_panels.close}). The owning caller calls this once
    after the last backtest that read through [p]. *)

val build_adapter_from_panels :
  Snapshot_runtime.Daily_panels.t ->
  Trading_simulation_data.Market_data_adapter.t
(** [build_adapter_from_panels panels] wraps an existing [Daily_panels.t] in a
    callback-mode [Market_data_adapter.t] without allocating a second cache.

    Used by {!Backtest.Panel_runner} so the simulator's per-tick price reads and
    the strategy's snapshot-backed bar reader share one resident
    [Daily_panels.t]. The investigation note
    [dev/notes/15y-memory-cliff-2026-05-08.md] §"Cliff #2" measured ~330 MB
    saved at the 15y SP500 window by deduplicating the cache.

    Pure wrapper — {!Snapshot_callbacks.of_daily_panels} +
    {!Snapshot_bar_source.make_callbacks} +
    {!Market_data_adapter.create_with_callbacks}. Never errors; the input panel
    is already validated. *)
