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
