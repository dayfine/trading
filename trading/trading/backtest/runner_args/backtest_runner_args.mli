(** Argument parsing for [backtest_runner.exe]. Lives in its own library so the
    parsing logic is unit-testable independently of the executable's
    side-effecting [main]. *)

type t = {
  start_date : string;
  end_date : string option;
      (** Raw end-date string as passed on the command line, or [None] when
          omitted. Resolution to a {!Date.t} (defaulting to today) is the
          caller's responsibility — the parser stays free of clock reads so it
          remains a pure function. *)
  overrides : string list;
      (** Raw [--override <arg>] arguments in the order passed. The executable
          interprets each entry: when the string matches the key-path form
          ([key.path=value]) it routes to {!Backtest.Config_override.parse};
          otherwise it parses the entry as a raw sexp blob (legacy form).
          Storing raw strings here keeps [runner_args] independent of the
          private [backtest] library.

          In [--baseline] mode, [overrides] are applied to the {b variant} run
          only — the baseline run uses default config (modulo any
          {!shared_overrides}). For non-baseline modes (single, smoke without
          [--baseline]), [overrides] and [shared_overrides] both apply
          identically to the single run. *)
  shared_overrides : string list;
      (** Raw [--shared-override <arg>] arguments in the order passed. Same
          syntax as [overrides] (key-path form or legacy sexp blob).

          Unlike [overrides], shared overrides apply to BOTH runs in
          [--baseline] mode. The intended use is to constrain the comparison
          environment in a way that's shared between baseline and variant — e.g.
          capping the universe to a smaller size for memory while still
          A/B-testing a different parameter via [--override]. Outside
          [--baseline], shared overrides simply append to [overrides] before
          handing them to the runner. *)
  trace_path : string option;
      (** [None] when [--trace] was not passed (no trace file written).
          [Some path] when [--trace <path>] was passed; the runner constructs a
          {!Backtest.Trace.t}, threads it through
          [Backtest.Runner.run_backtest ~trace], and writes the trace sexp at
          [path] after the result is written. *)
  memtrace_path : string option;
      (** [None] when [--memtrace] was not passed (no memtrace .ctf file
          written, zero memprof overhead). [Some path] when [--memtrace <path>]
          was passed; the runner calls [Memtrace.start_tracing] before invoking
          the backtest, producing a [.ctf] file at [path] consumable by
          [memtrace_viewer]. *)
  gc_trace_path : string option;
      (** [None] when [--gc-trace] was not passed (no GC snapshots taken, zero
          overhead). [Some path] when [--gc-trace <path>] was passed; the runner
          builds a {!Backtest.Gc_trace.t} and records [Gc.stat] snapshots at
          coarse phase boundaries. *)
  baseline : bool;
      (** [true] when [--baseline] was passed: the runner runs twice (once with
          overrides, once without) and writes [comparison.sexp] +
          [comparison.md] alongside the per-run subdirs. Default [false]. *)
  smoke : bool;
      (** [true] when [--smoke] was passed: the runner ignores [start_date] /
          [end_date] and instead runs each window in
          {!Scenario_lib.Smoke_catalog.all}, with each variant going to a
          per-window subdir. Default [false]. *)
  experiment_name : string option;
      (** [Some name] when [--experiment-name <name>] was passed. When set (and
          only then), the runner writes outputs under [dev/experiments/<name>/]
          instead of the legacy timestamped [dev/backtest/<...>/]. Required by
          [--baseline], [--smoke], and [--fuzz] so comparison/distribution
          artefacts have a stable home. *)
  fuzz_spec : string option;
      (** [Some spec] when [--fuzz <param>=<center>±<delta>:<n>] was passed. The
          runner parses [spec] via {!Backtest.Fuzz_spec.parse}, runs N variants
          (one per generated value), and writes a per-metric distribution sexp +
          markdown alongside the per-variant subdirs. The string is stored
          verbatim — interpretation is the executable's job. Mutually exclusive
          with [--baseline] and [--smoke] (validated at parse time). *)
  fuzz_window : string option;
      (** [Some name] when [--fuzz-window <bull|crash|recovery>] was passed.
          Only meaningful in fuzz mode: the runner resolves the named window in
          {!Scenario_lib.Smoke_catalog} and uses its [universe_path] to build a
          [sector_map_override] for every variant — the same trick smoke mode
          uses to keep the run inside the 8 GB dev-container memory budget
          (avoids loading the full ~10K-symbol [sectors.csv]).

          The window's start/end dates are {b not} substituted into fuzz
          variants — only the universe is constrained. Fuzz date variants and
          the positional [start_date] still drive the per-variant time range.

          Validated at parse time: [--fuzz-window] requires [--fuzz]. *)
  snapshot_dir : string option;
      (** [Some path] when [--snapshot-mode --snapshot-dir <path>] was passed
          (both flags are required together): the simulator's per-tick OHLCV
          reads come from the snapshot directory at [path] instead of the CSV
          [data_dir]. The runner reads [<path>/manifest.sexp] and constructs a
          [Backtest.Bar_data_source.Snapshot {snapshot_dir; manifest}] which is
          forwarded into [Backtest.Runner.run_backtest ~bar_data_source:_].
          Default [None] (CSV mode — pre-Phase-D behaviour). Phase D wiring; see
          [dev/plans/snapshot-engine-phase-d-2026-05-02.md].

          The snapshot directory must be pre-built via the Phase B writer
          ([analysis/scripts/build_snapshots/build_snapshots.exe]); the backtest
          runner will fail loudly if the manifest is missing or schema-skewed.
      *)
}
(** Result of parsing the [backtest_runner.exe] command line. *)

val parse : string list -> t Status.status_or
(** [parse args] parses [args] (excluding the program name, e.g.
    [Array.to_list (Sys.get_argv ()) |> List.tl_exn]) into a {!t}.

    Returns [Error status] (with [Status.code = Invalid_argument]) on any
    parsing problem (missing flag value, missing required positional, too many
    positionals, [--baseline]/[--smoke]/[--fuzz] without [--experiment-name],
    [--fuzz] combined with [--baseline] or [--smoke], or [--fuzz-window] without
    [--fuzz]).

    Override strings are NOT validated here — the executable runs them through
    [Backtest.Config_override.parse] / [Sexp.of_string] downstream and surfaces
    parse errors at that layer. Keeping arg-extraction simple lets the parser
    stay independent of the [backtest] library.

    For [--smoke], the [start_date] / [end_date] positionals are not required
    and are ignored if supplied — the runner picks the dates from
    {!Scenario_lib.Smoke_catalog}. For non-[--smoke] runs, [start_date] is still
    required as before. *)
