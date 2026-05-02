(** Backtest runner CLI — thin wrapper around the {!Backtest} library.

    Usage modes:

    {1 Single-run mode (legacy)}

    [backtest_runner <start_date> [end_date] [--override <arg>] [--trace <path>]
     [--memtrace <path>] [--gc-trace <path>] [--experiment-name <name>]]

    Writes [params.sexp], [summary.sexp], [trades.csv], etc. to either
    [dev/experiments/<name>/] (when [--experiment-name] is set) or a timestamped
    directory under [dev/backtest/] (default).

    {1 Baseline-comparison mode}

    [backtest_runner <start_date> [end_date] --baseline --experiment-name <name>
     --override <arg> ...]

    Runs twice — once with the overrides ([variant/] subdir) and once without
    ([baseline/] subdir) — then writes [comparison.sexp] + [comparison.md] at
    the experiment root with per-metric deltas.

    {1 Smoke mode}

    [backtest_runner --smoke --experiment-name <name> [--override <arg>] ...
     [--baseline]]

    Runs each window in {!Scenario_lib.Smoke_catalog.all} (Bull / Crash /
    Recovery), writing results under [dev/experiments/<name>/<window-name>/].
    Composes with [--baseline] for per-window comparisons.

    {1 --override syntax}

    Two forms accepted, freely composable:
    - {b Key-path}: [stops_config.initial_stop_buffer=1.05] — ergonomic,
      dispatched via {!Backtest.Config_override}.
    - {b Raw sexp}: [((stops_config ((initial_stop_buffer 1.05))))] — legacy,
      kept for backward compat with existing scripts.

    The runner converts both forms to the [Sexp.t list] that
    [Backtest.Runner._apply_overrides] already deep-merges into the default
    {!Weinstein_strategy.config}. Overrides apply to exactly the named field;
    every other config value comes from the default. *)

open Core

let _usage_msg =
  "Usage: backtest_runner <start_date> [end_date] [--override <arg>] [--trace \
   <path>] [--memtrace <path>] [--gc-trace <path>] [--baseline] [--smoke] \
   [--experiment-name <name>]"

(** Convert each raw [--override <arg>] string into the partial-config sexp the
    runner deep-merges. Routes key-path strings through
    {!Backtest.Config_override}; falls back to raw [Sexp.of_string] for legacy
    sexp blobs. Surfaces parse errors via [Stdlib.exit 1]. *)
let _resolve_overrides raw_overrides =
  List.map raw_overrides ~f:(fun s ->
      if Backtest.Config_override.is_key_path_form s then (
        match Backtest.Config_override.parse_to_sexp s with
        | Ok sexp -> sexp
        | Error err ->
            eprintf "Error: invalid --override %S: %s\n" s err.message;
            Stdlib.exit 1)
      else
        match Or_error.try_with (fun () -> Sexp.of_string s) with
        | Ok sexp -> sexp
        | Error err ->
            eprintf "Error: --override value is not a valid sexp: %s\n"
              (Error.to_string_hum err);
            Stdlib.exit 1)

let _parse_args () =
  let argv = Sys.get_argv () in
  if Array.length argv < 2 then (
    eprintf "%s\n" _usage_msg;
    Stdlib.exit 1);
  let args = Array.to_list argv |> List.tl_exn in
  match Backtest_runner_args.parse args with
  | Error status ->
      eprintf "Error: %s\n" status.message;
      Stdlib.exit 1
  | Ok parsed -> parsed

(** Resolve [--experiment-name] into an output root directory. When set, returns
    [dev/experiments/<name>]; otherwise a fresh timestamped
    [dev/backtest/<YYYY-MM-DD-HHMMSS>] directory.

    Pulled out of [main] so the same path-construction logic is shared between
    single-run, baseline, and smoke modes. *)
let _make_output_root ?experiment_name () =
  let data_dir_fpath = Data_path.default_data_dir () in
  let repo_root = Fpath.parent data_dir_fpath |> Fpath.to_string in
  match experiment_name with
  | Some name ->
      let path = repo_root ^ "dev/experiments/" ^ name in
      Core_unix.mkdir_p path;
      path
  | None ->
      let now = Core_unix.gettimeofday () in
      let tm = Core_unix.localtime now in
      let dirname =
        sprintf "%04d-%02d-%02d-%02d%02d%02d" (tm.tm_year + 1900)
          (tm.tm_mon + 1) tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec
      in
      let path = repo_root ^ "dev/backtest/" ^ dirname in
      Core_unix.mkdir_p path;
      path

(** Write the captured trace sexp at [path] and report on stderr. *)
let _write_trace ~path ~trace =
  let metrics = Backtest.Trace.snapshot trace in
  Backtest.Trace.write ~out_path:path metrics;
  eprintf "Trace written to: %s\n%!" path

(** Sampling rate for [Memtrace.start_tracing]. The Memtrace docs warn that
    rates above ~1e-4 carry measurable performance impact; 1e-4 yields ~10K
    samples for a typical backtest. *)
let _memtrace_sampling_rate = 1e-4

let _write_gc_trace ~path ~gc_trace =
  let snapshots = Backtest.Gc_trace.snapshot_list gc_trace in
  Backtest.Gc_trace.write ~out_path:path snapshots;
  eprintf "Gc-trace written to: %s\n%!" path

let _start_memtrace ~path =
  let _tracer : Memtrace.tracer =
    Memtrace.start_tracing ~context:None ~sampling_rate:_memtrace_sampling_rate
      ~filename:path
  in
  eprintf "Memtrace started, writing to: %s\n%!" path

(** Run a single backtest and write its full result set to [output_dir]. The
    side-effecting work (trace + memtrace + gc-trace plumbing) is folded in here
    so single-run / baseline / smoke modes all share the same per-run pipeline.

    Returns the [Backtest.Runner.result] so callers (e.g. baseline mode) can
    feed both runs into [Backtest.Comparison.compute] without re-reading the
    summary from disk. *)
let _run_and_write ~start_date ~end_date ~overrides ~output_dir ?trace_path
    ?memtrace_path ?gc_trace_path () =
  Option.iter memtrace_path ~f:(fun path -> _start_memtrace ~path);
  let trace = Option.map trace_path ~f:(fun _ -> Backtest.Trace.create ()) in
  let gc_trace =
    Option.map gc_trace_path ~f:(fun _ -> Backtest.Gc_trace.create ())
  in
  Backtest.Gc_trace.record ?trace:gc_trace ~phase:"start" ();
  let result =
    Backtest.Runner.run_backtest ~start_date ~end_date ~overrides ?trace
      ?gc_trace ()
  in
  eprintf "Writing output to %s/\n%!" output_dir;
  Backtest.Result_writer.write ~output_dir result;
  eprintf "Output written to: %s/\n%!" output_dir;
  Option.iter (Option.both trace_path trace) ~f:(fun (path, trace) ->
      _write_trace ~path ~trace);
  Backtest.Gc_trace.record ?trace:gc_trace ~phase:"end" ();
  Option.iter (Option.both gc_trace_path gc_trace) ~f:(fun (path, gc_trace) ->
      _write_gc_trace ~path ~gc_trace);
  result

(** Single-run mode: one backtest, write to [output_dir], echo summary to
    stdout. This is the legacy code path (also reused by smoke mode for the
    no-baseline case). *)
let _single_run ~start_date ~end_date ~overrides ~output_dir ?trace_path
    ?memtrace_path ?gc_trace_path () =
  let result =
    _run_and_write ~start_date ~end_date ~overrides ~output_dir ?trace_path
      ?memtrace_path ?gc_trace_path ()
  in
  Out_channel.output_string stdout
    (Sexp.to_string_hum (Backtest.Summary.sexp_of_t result.summary));
  Out_channel.newline stdout

(** Baseline-comparison mode: run with [overrides] (variant) and again without
    (baseline), then write [comparison.{sexp,md}] at [output_root]. *)
let _baseline_run ~start_date ~end_date ~overrides ~output_root () =
  let baseline_dir = Filename.concat output_root "baseline" in
  let variant_dir = Filename.concat output_root "variant" in
  Core_unix.mkdir_p baseline_dir;
  Core_unix.mkdir_p variant_dir;
  eprintf "[baseline] running with default config...\n%!";
  let baseline_result =
    _run_and_write ~start_date ~end_date ~overrides:[] ~output_dir:baseline_dir
      ()
  in
  eprintf "[variant] running with %d override(s)...\n%!" (List.length overrides);
  let variant_result =
    _run_and_write ~start_date ~end_date ~overrides ~output_dir:variant_dir ()
  in
  let comparison =
    Backtest.Comparison.compute ~baseline:baseline_result.summary
      ~variant:variant_result.summary
  in
  let sexp_path = Filename.concat output_root "comparison.sexp" in
  let md_path = Filename.concat output_root "comparison.md" in
  Backtest.Comparison.write_sexp ~output_path:sexp_path comparison;
  Backtest.Comparison.write_markdown ~output_path:md_path comparison;
  eprintf "Comparison written to: %s and %s\n%!" sexp_path md_path

(** Smoke mode: loop over every window in {!Scenario_lib.Smoke_catalog.all},
    delegating to either [_single_run] or [_baseline_run] per window depending
    on the [baseline] flag. Per-window subdirs sit under the experiment root. *)
let _smoke_run ~overrides ~output_root ~baseline () =
  List.iter Scenario_lib.Smoke_catalog.all ~f:(fun window ->
      let window_dir = Filename.concat output_root window.name in
      Core_unix.mkdir_p window_dir;
      eprintf "\n=== smoke window: %s (%s .. %s) — %s ===\n%!" window.name
        (Date.to_string window.start_date)
        (Date.to_string window.end_date)
        window.description;
      if baseline then
        _baseline_run ~start_date:window.start_date ~end_date:window.end_date
          ~overrides ~output_root:window_dir ()
      else
        _single_run ~start_date:window.start_date ~end_date:window.end_date
          ~overrides ~output_dir:window_dir ())

(** Resolve the raw start/end positionals into [Date.t]. Smoke mode supplies its
    own dates per window so the positionals are unused there; the caller only
    invokes this for non-smoke runs. *)
let _resolve_dates ~start_date_raw ~end_date_raw =
  let start_date = Date.of_string start_date_raw in
  let end_date =
    match end_date_raw with
    | Some s -> Date.of_string s
    | None -> Date.today ~zone:Time_float.Zone.utc
  in
  (start_date, end_date)

let () =
  let parsed = _parse_args () in
  let overrides = _resolve_overrides parsed.overrides in
  let output_root =
    _make_output_root ?experiment_name:parsed.experiment_name ()
  in
  match (parsed.smoke, parsed.baseline) with
  | true, _ -> _smoke_run ~overrides ~output_root ~baseline:parsed.baseline ()
  | false, true ->
      let start_date, end_date =
        _resolve_dates ~start_date_raw:parsed.start_date
          ~end_date_raw:parsed.end_date
      in
      _baseline_run ~start_date ~end_date ~overrides ~output_root ()
  | false, false ->
      let start_date, end_date =
        _resolve_dates ~start_date_raw:parsed.start_date
          ~end_date_raw:parsed.end_date
      in
      _single_run ~start_date ~end_date ~overrides ~output_dir:output_root
        ?trace_path:parsed.trace_path ?memtrace_path:parsed.memtrace_path
        ?gc_trace_path:parsed.gc_trace_path ()
