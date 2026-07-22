(** Per-symbol snapshot-warehouse build loop, factored out of
    [build_snapshots.exe] so multiple entry points share one build path.

    Given an explicit symbol list, this runs {!Snapshot_pipeline.Pipeline} once
    per symbol, writes one [<symbol>.snap] file per symbol under [output_dir],
    and produces an atomically-checkpointed [<output_dir>/manifest.sexp]. The
    contract (windowing, incremental skip, progress emission, final verify) is
    identical to the historical [build_snapshots] [main]; the only difference is
    the symbol set is supplied by the caller rather than read from a universe
    file — so {!Build_scenario_snapshots} can stage the runner's derived
    [all_symbols] set, and [build_snapshots.exe] can stage a universe file's
    symbols, via the same code. *)

val default_progress_every : int
(** Default [progress.sexp] emission cadence: write a progress checkpoint after
    every 50 symbols. CLIs surface this as the [--progress-every] default. *)

val default_sketch_deep_days : int
(** Default calendar-day span of extra pre-window history loaded to feed the
    resistance sketch (resistance-v2 §D4): 3650 (~520 trading weeks, the deepest
    sketch horizon). CLIs surface this as the [--sketch-deep-days] default. *)

val build :
  symbols:string list ->
  csv_data_dir:string ->
  output_dir:string ->
  benchmark_symbol:string option ->
  start_date:Core.Date.t option ->
  end_date:Core.Date.t option ->
  sketch_deep_days:int ->
  incremental:bool ->
  progress_every:int ->
  unit ->
  unit
(** [build ~symbols ~csv_data_dir ~output_dir ~benchmark_symbol ~start_date
     ~end_date ~incremental ~progress_every ()] builds the snapshot warehouse.

    - [symbols] — the exact set of tickers to build [.snap] files for. Symbols
      with no source CSV under [csv_data_dir] are logged and skipped (the
      warehouse simply omits them).
    - [csv_data_dir] — directory containing per-symbol CSV history (the
      {!Csv.Csv_storage} layout).
    - [output_dir] — created if absent; receives one [<symbol>.snap] per built
      symbol plus [manifest.sexp] and [progress.sexp].
    - [benchmark_symbol] — when [Some sym], its windowed bars are routed into
      the pipeline's [benchmark_bars] so {!Snapshot_schema.RS_line} /
      {!Snapshot_schema.Macro_composite} are populated; [None] leaves those
      columns NaN.
    - [start_date] / [end_date] — inclusive bar window applied to every symbol
      (and the benchmark) before building. Pass the backtest's {e warmup_start}
      (not its [start_date]) as [start_date] — indicators warm up over in-window
      bars only, exactly as {!Csv_snapshot_builder} is invoked with
      [~warmup_start]. [None] on either bound means full history on that side.
    - [sketch_deep_days] — calendar-day span of extra history loaded {e before}
      [start_date] and fed (as [deep_bars]) into the [<symbol>.weekly]
      side-table's weekly aggregation so its trailing max-high / bars-seen depth
      is honest rather than the warmup-windowed slice (resistance-v2 §D4). The
      13 warmup-windowed [.snap] columns and the benchmark stay windowed to
      [start_date], so this never changes them; symbols with no pre-window data
      behave exactly as before. Ignored when [start_date] is [None]
      (full-history build). See {!default_sketch_deep_days}.
    - [incremental] — when [true], symbols whose source CSV mtime is [<=] the
      existing manifest's recorded [csv_mtime] are reused rather than rebuilt.
      Note: incremental-skipped symbols do not (re)write their side-table; a
      full (non-incremental) build emits one per symbol.
    - [progress_every] — emit [progress.sexp] every N symbols processed.

    Sketch-v5 PR 4: the sparse [<symbol>.weekly] side-table
    ({!Data_panel_snapshot.Weekly_sidetable}) is {b always} written next to each
    [<symbol>.snap] (built by {!Snapshot_pipeline.Weekly_sidetable_builder} from
    the same weekly aggregation), and
    {!Data_panel_snapshot.Weekly_sidetable.format_hash} is always stamped on the
    final manifest — it is now the only overhead-supply representation the
    reader has (the dense [Res_*] columns were retired from the canonical
    schema). A side-table write failure is logged, not fatal.

    Exits the process non-zero on manifest-write or verification failure (the
    historical [build_snapshots] semantics). *)
