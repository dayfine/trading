(** Build an in-process snapshot directory from per-symbol CSVs.

    F.3.a-3 collapsed the legacy CSV path's [Ohlcv_panels] / [Bar_panels] /
    [Indicator_panels] build into an in-process snapshot directory. The CSV
    runner mode reads each universe symbol's CSV via [Csv_storage.get], filters
    to the simulator's active window, feeds the bars to the same
    {!Snapshot_pipeline.Pipeline.build_for_symbol} the offline writer uses, and
    serialises them to per-symbol [.snap] files under a tmp directory. The
    downstream setup is then identical to a pre-built snapshot mode run.

    No [benchmark_bars] is supplied to the pipeline, so [RS_line] /
    [Macro_composite] columns are NaN — the bar-shaped views
    ([Snapshot_runtime.Snapshot_bar_views]) only read OHLCV columns, so the
    strategy's bar reads are unaffected.

    The tmp directory is left in place after the call returns; the OS reaps it
    on reboot. Long-running rigs that build many snapshots in one process should
    plumb a teardown hook (out of scope for F.3.a-3). *)

open Core

val build :
  data_dir:Fpath.t ->
  universe:string list ->
  start_date:Date.t ->
  end_date:Date.t ->
  string * Snapshot_pipeline.Snapshot_manifest.t
(** [build ~data_dir ~universe ~start_date ~end_date] reads CSVs for every
    symbol in [universe] from [data_dir] (using the standard
    [Csv_storage.symbol_data_dir] layout), filters bars to
    [start_date..end_date] inclusive, runs each symbol's bars through
    {!Snapshot_pipeline.Pipeline.build_for_symbol}, and writes the resulting
    rows to per-symbol [.snap] files under a fresh tmp directory.

    Returns [(snapshot_dir, manifest)]: the path to the tmp directory and the
    in-memory directory manifest (also serialised to [<dir>/manifest.sexp]).

    Missing-CSV / [NotFound] errors are tolerated: the symbol contributes an
    empty bar list, mirroring the legacy CSV loader's "row stays NaN" semantics.
    Any other [Csv_storage] / pipeline / serialisation error fails via
    [failwith] with a descriptive message — these all indicate programming or
    environment errors that the runner cannot recover from. *)
