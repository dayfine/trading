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
    back than the tolerance — the 2026-09-06 rebuild had clusters 52 and 47 days
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

val load_splice_exceptions :
  string option -> Snapshot_pipeline.Series_splice.Exceptions.t Status.status_or
(** [load_splice_exceptions path] reads the {b splice} section of the warehouse
    exceptions file (issue #2672 class ii). [None] is [Ok Exceptions.empty].

    The file is parsed {b once}, by this module, into one strict record
    [{ keep_tail; splice }]; this loader and {!load_tail_exceptions} are two
    views of it. Both sections are {b optional} and independent: a file carrying
    only [keep_tail] loads here as "no splice exceptions", and a file carrying
    only [splice] loads in {!load_tail_exceptions} as "no tail exceptions".

    Optional is not lenient. The record admits {b no other field}, so a mistyped
    section name ([splcie]) is a parse [Error] rather than a silently empty veto
    list — a missing, malformed, or misspelt file is never a silent fallback,
    because that fallback would edit exactly the symbols a reviewer vetoed.
    Consequently a file whose {e other} section is malformed fails here too,
    which is the intended behaviour: one file, one parse, one verdict. *)

val splice_exceptions_or_exit :
  string option -> Snapshot_pipeline.Series_splice.Exceptions.t
(** CLI shell around {!load_splice_exceptions}: prints the error to stderr and
    exits 1, exactly as {!tail_exceptions_or_exit} does. *)

val load_tail_exceptions :
  string option -> Snapshot_pipeline.Series_tail.Exceptions.t Status.status_or
(** [load_tail_exceptions path] reads the {b keep_tail} section of the same
    warehouse exceptions file. [None] is [Ok Exceptions.empty] (no exceptions).
    [Some p] parses [p] as the one strict record described under
    {!load_splice_exceptions} and projects its [keep_tail] list; a missing,
    malformed, or misspelt file is an [Error], never a silent fallback to "no
    exceptions" — that fallback would truncate exactly the symbols a reviewer
    vetoed. Returning the failure as a value (rather than exiting here) is what
    makes both halves testable; the exit lives in {!tail_exceptions_or_exit}. *)

val tail_exceptions_or_exit :
  string option -> Snapshot_pipeline.Series_tail.Exceptions.t
(** CLI shell around {!load_tail_exceptions}: prints the error to stderr and
    exits 1. An unreadable exceptions file is fatal for a build, so both
    builders call this before {!build} rather than passing a path in. *)

val build :
  ?survivor_tolerance_days:int ->
  ?splice_cuts:Core.Date.t Core.Map.M(Core.String).t ->
  ?twin_config:Twin_detector.Config.t ->
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

    {b An incremental build never shrinks the warehouse's index} (#2669).
    [symbols] may be a strict {e subset} of the warehouse — a top-up adding one
    benchmark ticker, or a cron window resuming a partial rebuild — so the final
    manifest {b merges} this run's entries into the pre-run manifest rather than
    replacing it: an entry for a symbol this run did not produce is carried
    forward, and this run's entry wins on a symbol collision. Without the merge
    a one-symbol top-up rewrote a 2,208-symbol manifest down to a single entry
    while every [.snap] file stayed on disk, and because {!Bar_source_resolver}
    enumerates symbols {e from the manifest} the warehouse then read as empty to
    every runner. The merge makes the final write agree with the per-symbol
    checkpoint, which already upserts
    ({!Snapshot_pipeline.Snapshot_manifest.update_for_symbol}).

    A carried entry is dropped when its [.snap] file no longer exists (a stale
    index row would fail the closing verify), and the pre-run manifest is
    dropped whole when its [schema_hash] differs from this build's (its files
    carry another indicator set's columns); both are logged. A non-empty carry
    set is reported as a warning, not refused — a top-up is a legitimate
    non-superset universe, and refusing one would break the very operation this
    flag exists to serve.

    Merging is confined to the incremental path: with [incremental = false] no
    pre-run manifest is read at all, so a full rebuild still {e replaces} the
    index and remains the way to prune symbols the warehouse should no longer
    carry.
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
      depth, so {e this} rule does not edit them — it trims the series' end, and
      a bar before the window is not part of it. ([splice_cuts] below trims the
      series' start, so it does reach them.)
    - [splice_cuts] — build-time splice hygiene (#2672 class ii,
      {!Snapshot_pipeline.Series_splice}). Each named symbol's bars are cut to
      those dated on or after its date, {e before} the tail rule runs, so the
      stored series describes one issuer. The cut reaches {b both} halves of the
      symbol's history: the windowed bars behind its [.snap], and the
      [deep_bars] prefix behind its [.weekly] side-table. A cut date is inside
      the build window and the deep prefix is strictly before it, so for a cut
      symbol the prefix is entirely the earlier issuer's and drops out whole —
      without that, the side-table (the reader's only overhead-supply source)
      would still describe two companies. Decided by the caller's splice scan
      (which sees every symbol's full history) rather than here; symbols that
      scan {e dropped} are simply absent from [symbols], so they get no [.snap]
      and no manifest entry. Defaults to empty — a build that passes nothing
      behaves exactly as before.
    - [twin_config] — cross-symbol rename-twin hygiene (#2730,
      {!Twin_pass}/{!Twin_detector}), run {e before} the per-symbol loop: each
      symbol's windowed adjusted-close series is compared against every other's,
      and the losing leg of each detected twin group is removed from [symbols]
      so the warehouse indexes one series per instrument. The report lands in
      [<output_dir>/rename_twin_report.txt]. Defaults to
      {!Twin_detector.Config.default}, which is [enabled = false]: no bar is
      read, no file written, and [symbols] passes through untouched, so an
      un-armed build is byte-identical to its pre-#2730 behaviour. Both builders
      surface the flags via {!Twin_pass.params}; the vintage rebuild path
      ([build_snapshots.exe]) had no way to arm the pass at all before #2730,
      which is why the [_v7mark] warehouses still carry NLS/BFX, BB/BBRY,
      AABA/YHOO and friends.

    {2 [twin_config] with [incremental]: a dropped leg leaves the index}

    The two compose without a special case, and the rule is stated here because
    the naive composition is silently wrong. A symbol the twin pass drops is
    absent from this run's entries, so the incremental merge above would
    {e carry its pre-run entry forward} and the warehouse would keep indexing
    the duplicate the pass just removed. It does not: symbols dropped by the
    twin pass are excluded from the carry set, so a deduping rebuild removes
    them from the index whether or not [incremental] is set. Their [.snap] files
    may remain on disk, but the manifest is the warehouse's only index
    ({!Bar_source_resolver} enumerates symbols from it), so an unindexed file is
    not served to any runner. Pinned by [test_build_runner_twins.ml].

    {2 [active_through] is derived from the series end}

    A splice cut keeps the {e later} segment, so it never moves this marker; a
    dropped symbol has no entry and therefore no marker at all.

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
    supported shape for (re)deriving markers across the whole warehouse. That
    caveat is about the {e marker}, not the index — a resumed or partial run's
    manifest still lists every symbol (see [incremental] above, #2669).

    The final manifest's marker split ("N marked, M survivors") is logged, over
    the set actually written — this run's entries {e plus} any carried forward
    (#2669) — so on a top-up the counts describe the whole warehouse index the
    operator is signing off, not just the handful of symbols this run touched.
    ([progress.sexp] and [terminal_runs.csv] stay run-scoped, because they count
    work this run did.) A carried entry keeps the marker its own build derived;
    it is not re-derived here (see above).

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
