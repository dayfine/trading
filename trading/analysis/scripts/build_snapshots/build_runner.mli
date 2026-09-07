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

val default_survivor_tolerance_days : int
(** Default slack, in calendar days, between the universe's last bar and a
    symbol's own last bar before that symbol is treated as delisted: 7. The
    vendor lags a few names by a day or two (measured 2026-09-06: 778 of 782
    survivors sit exactly on the store's last bar), so a symbol whose series
    stops mid-way through the store's final week is still trading. CLIs surface
    this as the [--survivor-tolerance-days] default. A series that stops further
    back than the tolerance — the 2026-09-06 rebuild had clusters 47 and 52 days
    behind the store end (90 and 61 names), i.e. store copies not refreshed — is
    marked as ended, which is the correct read for admission and exits until the
    store is refetched: an entry on a bar that old is exactly the V17 defect. *)

val survivor_tolerance_param : int Core.Command.Param.t
(** Shared CLI flag [-survivor-tolerance-days], so both builders expose the same
    surface and default. Yields {!build}'s [?survivor_tolerance_days]. *)

val default_exceptions_path : string
(** Repo path of the committed series-tail veto list,
    [trading/test_data/warehouse_exceptions.sexp]. Documentation only: the
    [-tail-exceptions] flag has no default, so a build never silently depends on
    the caller's working directory. Operators point the flag at this file. *)

val tail_report_name : string
(** Filename of the series-tail review sidecar written into the output
    directory: [terminal_runs.csv]. *)

val tail_params :
  (Snapshot_pipeline.Series_tail.Config.t * string option) Core.Command.Param.t
(** Shared CLI flags for the series-tail pass, so both builders expose the same
    surface: [-stub-ratio], [-stub-max-bars], [-stub-max-price],
    [-no-stub-truncation], [-no-stray-drop], [-tail-exceptions PATH]. Yields
    {!build}'s [~tail_config] plus the raw [-tail-exceptions] path, which the
    CLI shell resolves through {!tail_exceptions_or_exit}.

    Only the three gate knobs are flags. The mis-scale threshold
    ([misscale_close]) and the stray-gap parameters are measured constants of
    the defect classes rather than per-build choices — see
    {!Snapshot_pipeline.Series_tail} for the measurement they come from. *)

val load_tail_exceptions :
  string option -> Snapshot_pipeline.Series_tail.Exceptions.t Status.status_or
(** [load_tail_exceptions path] reads the series-tail veto list. [None] is
    [Ok Exceptions.empty] (no exceptions). [Some p] parses [p] as
    {!Snapshot_pipeline.Series_tail.Exceptions.file}; a missing or malformed
    file is an [Error], never a silent fallback to "no exceptions" — that
    fallback would truncate exactly the symbols a reviewer vetoed. Returning the
    failure as a value (rather than exiting here) is what makes both halves
    testable; the exit lives in {!tail_exceptions_or_exit}. *)

val tail_exceptions_or_exit :
  string option -> Snapshot_pipeline.Series_tail.Exceptions.t
(** CLI shell around {!load_tail_exceptions}: prints the error to stderr and
    exits 1. An unreadable exceptions file is fatal for a build, so both
    builders call this before {!build} rather than passing a path in. *)

val build :
  ?survivor_tolerance_days:int ->
  symbols:string list ->
  csv_data_dir:string ->
  output_dir:string ->
  benchmark_symbol:string option ->
  start_date:Core.Date.t option ->
  end_date:Core.Date.t option ->
  sketch_deep_days:int ->
  incremental:bool ->
  progress_every:int ->
  tail_config:Snapshot_pipeline.Series_tail.Config.t ->
  tail_exceptions:Snapshot_pipeline.Series_tail.Exceptions.t ->
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
    - [tail_config] / [tail_exceptions] — series-tail hygiene (#2672), applied
      to each symbol's windowed bars {e before} the pipeline sees them (see
      {!Snapshot_pipeline.Series_tail}). Terminal administrative stub runs and
      stray late bars are dropped, so no [.snap] carries a phantom print; every
      terminal run below the ratio is reported in
      [<output_dir>/terminal_runs.csv] whatever the gates decided, and a summary
      line is logged. [tail_exceptions] names symbols never edited — their
      findings come back [Kept_by_exception] and their series (and therefore
      their [active_through] marker) are left whole. Build it with
      {!tail_exceptions_or_exit}, which makes an unreadable file fatal;
      {!Snapshot_pipeline.Series_tail.Exceptions.empty} means no exceptions.
      [deep_bars] are strictly before the window and feed only the side-table's
      depth, so they are not edited.

    {2 [active_through] is derived from the series end}

    A symbol whose last stored bar falls more than [survivor_tolerance_days]
    behind the {e universe's} last bar is marked delisted in the manifest
    ([file_metadata.active_through = Some last_bar]); one still printing at the
    end keeps [None] ("still trading / unknown"). An [active_through] already
    carried on the input bars always wins — but no vendor path populates it
    today, which is why this derivation exists.

    - [survivor_tolerance_days] — the slack that separates "still trading" from
      "delisted". The vendor lags a few names by a day or two, so an exact match
      against the universe's last bar would mark them all delisted. Defaults to
      {!default_survivor_tolerance_days}.

    {b The reference is the universe's own last bar — the latest bar ANY symbol
       in this build printed — never [end_date]} (#2693). An [end_date] past the
    CSV store's own end marks every survivor delisted: the 2026-09-06 rebuild
    passed [-end-date 2026-09-06] against a store whose last bar was 2026-08-17
    and stamped a marker on all 2,999 symbols, 778 of them still trading.

    The universe's end can only be resolved after every symbol is read, so the
    derivation is stamped on the {e final} manifest rather than on the
    per-symbol checkpoints — those carry only an explicit bar-borne marker. An
    interrupted build resumed with [incremental] therefore reuses entries whose
    derived marker is not filled in; a full (non-incremental) rebuild is the
    supported shape (#2669).

    The final manifest's marker split ("N marked, M survivors") is logged.

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
