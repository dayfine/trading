(** Resolve a [--snapshot-dir] CLI value into a [Backtest.Bar_data_source.t].

    This is the [scenario_runner.exe] counterpart of [backtest_runner.ml]'s
    [_resolve_bar_data_source] (PR #788 snapshot-mode wiring). It is factored
    into [scenario_lib] (rather than living inline in the executable) so the
    manifest-read + error path is unit-testable without forking a full backtest.

    Snapshot (streaming) mode lets a large-N golden cell read OHLCV from a
    pre-built snapshot warehouse instead of building the whole universe's bars
    in-process from CSVs — the latter is ~14 GB resident at N=3000 and will not
    fit a local dev container. With no [--snapshot-dir], the resolver returns
    [None] and the run stays bit-identical to the pre-existing CSV mode. *)

val resolve : string option -> Backtest.Bar_data_source.t option
(** [resolve snapshot_dir] maps the parsed [--snapshot-dir] flag to an optional
    [Bar_data_source.t]:

    - [None] -> [None]. The caller omits [?bar_data_source], so
      [Backtest.Runner.run_backtest] defaults to [Bar_data_source.Csv] — the
      pre-snapshot CSV behaviour, unchanged.
    - [Some dir] -> [Some (Snapshot { snapshot_dir = dir; manifest })] where
      [manifest] is read from [<dir>/manifest.sexp] via
      [Snapshot_pipeline.Snapshot_manifest.read].

    Exits the process with status 1 (writing a diagnostic to [stderr]) on a
    missing or corrupt manifest, so the "snapshot dir not yet built" failure
    mode surfaces immediately at parse time rather than as a runner-internal
    error mid-run. Mirrors [backtest_runner._resolve_bar_data_source] exactly:
    the manifest is read once here and the resulting selector is reused across
    every cell in a [--dir] run. *)
