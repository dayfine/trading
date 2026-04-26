(** Backtest runner CLI — thin wrapper around the {!Backtest} library.

    Usage: backtest_runner <start_date> \[end_date\] \[--override '<sexp>'\]
    \[--trace <path>\] \[--memtrace <path>\]

    - start_date: required (e.g. 2018-01-02)
    - end_date: optional, defaults to today
    - --override: partial config sexp, deep-merged into the default. Can repeat.
    - --trace: when given, instruments the run with per-phase timing + memory
      measurements via {!Backtest.Trace} and writes the trace sexp at [<path>]
      after the result is written. Without this flag, no trace is captured (the
      default code path is unchanged). The output sexp is a list of
      [Backtest.Trace.phase_metrics] records, parseable via
      [Backtest.Trace.phase_metrics_of_sexp]. Workstream B4 of
      [dev/plans/backtest-perf-2026-04-24.md] — closes the gap that previously
      forced trace capture through [scenario_runner.exe] only.
    - --memtrace: when given, starts {!Memtrace} statistical allocation
      profiling (sampling rate ~1e-4 = ~10K samples per backtest) before any
      backtest work, writing a [.ctf] file at [<path>] with per-callsite
      allocation traces. Inspect via [memtrace_viewer <path>]. The tracer
      auto-stops at process exit via Memtrace's [at_exit] hook. Default off (no
      flag = no memtrace overhead, no .ctf written). Workstream B7 of
      [dev/plans/backtest-perf-2026-04-24.md] — per-callsite attribution for the
      +95% Tiered RSS investigation. Composes with [--trace]: phase-level
      timing/RSS + per-callsite allocation traces are independent measurement
      planes and can be captured in the same run.

    Example:
    {[
      backtest_runner 2019-01-02 2020-06-30 \
        --override '((initial_stop_buffer 1.08))' \
        --override '((stage_config ((ma_period 40))))'
    ]}

    Manual repro for the [--trace] flag:
    {[
      backtest_runner 2015-01-02 2015-12-31 \
        --trace /tmp/sample-trace.sexp
      head /tmp/sample-trace.sexp
    ]}

    Manual repro for the [--memtrace] flag:
    {[
      backtest_runner 2015-01-02 2015-12-31 \
        --memtrace /tmp/sample.memtrace.ctf
      ls -la /tmp/sample.memtrace.ctf  # non-zero size on success
      # opam install memtrace_viewer && memtrace_viewer /tmp/sample.memtrace.ctf
    ]}

    Writes params.sexp, summary.sexp, trades.csv, equity_curve.csv to a
    timestamped directory under dev/backtest/ and prints the summary sexp to
    stdout.

    After Stage 3 PR 3.4 of the columnar data-shape redesign, the runner has a
    single execution path (panel-backed). The pre-existing [--loader-strategy]
    flag was deleted along with the [Loader_strategy] enum and the Legacy/Tiered
    code paths. *)

open Core

let _parse_args () =
  let argv = Sys.get_argv () in
  if Array.length argv < 2 then (
    eprintf
      "Usage: backtest_runner <start_date> [end_date] [--override '<sexp>'] \
       [--trace <path>] [--memtrace <path>]\n";
    Stdlib.exit 1);
  let args = Array.to_list argv |> List.tl_exn in
  match Backtest_runner_args.parse args with
  | Error status ->
      eprintf "Error: %s\n" status.message;
      Stdlib.exit 1
  | Ok parsed ->
      let start_date = Date.of_string parsed.start_date in
      let end_date =
        match parsed.end_date with
        | Some s -> Date.of_string s
        | None -> Date.today ~zone:Time_float.Zone.utc
      in
      ( start_date,
        end_date,
        parsed.overrides,
        parsed.trace_path,
        parsed.memtrace_path )

let _make_output_dir () =
  let data_dir_fpath = Data_path.default_data_dir () in
  let repo_root = Fpath.parent data_dir_fpath |> Fpath.to_string in
  let now = Core_unix.gettimeofday () in
  let tm = Core_unix.localtime now in
  let dirname =
    sprintf "%04d-%02d-%02d-%02d%02d%02d" (tm.tm_year + 1900) (tm.tm_mon + 1)
      tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec
  in
  let path = repo_root ^ "dev/backtest/" ^ dirname in
  Core_unix.mkdir_p path;
  path

(** Write the captured trace sexp at [path] and report the location on stderr.
    Pulled out of [main] to keep the side-effect explicit at the call site. *)
let _write_trace ~path ~trace =
  let metrics = Backtest.Trace.snapshot trace in
  Backtest.Trace.write ~out_path:path metrics;
  eprintf "Trace written to: %s\n%!" path

(** Sampling rate for [Memtrace.start_tracing]. The Memtrace docs warn that
    rates above ~1e-4 carry measurable performance impact; 1e-4 yields ~10K
    samples for a typical backtest (sized to give a usable allocation flamegraph
    without distorting wall-clock numbers in the same run). *)
let _memtrace_sampling_rate = 1e-4

(** Start [Memtrace] tracing to [path], discarding the returned tracer handle.
    [Memtrace] registers an [at_exit] hook to stop tracing + flush the [.ctf]
    file at process exit, so we don't need to retain the tracer ourselves. Logs
    to stderr so the user sees the file path before any backtest output. *)
let _start_memtrace ~path =
  let _tracer : Memtrace.tracer =
    Memtrace.start_tracing ~context:None ~sampling_rate:_memtrace_sampling_rate
      ~filename:path
  in
  eprintf "Memtrace started, writing to: %s\n%!" path

let () =
  let start_date, end_date, overrides, trace_path, memtrace_path =
    _parse_args ()
  in
  (* Start Memtrace BEFORE any backtest work so allocations from [run_backtest]
     are sampled. The tracer auto-stops at process exit; if [--memtrace] is
     absent, this is a no-op. *)
  Option.iter memtrace_path ~f:(fun path -> _start_memtrace ~path);
  (* When [--trace <path>] is passed, pre-allocate a [Trace.t] so the runner
     records into it; otherwise [trace = None] and tracing is a no-op (the
     default code path is unchanged). *)
  let trace = Option.map trace_path ~f:(fun _ -> Backtest.Trace.create ()) in
  let result =
    Backtest.Runner.run_backtest ~start_date ~end_date ~overrides ?trace ()
  in
  let output_dir = _make_output_dir () in
  eprintf "Writing output to %s/\n%!" output_dir;
  Backtest.Result_writer.write ~output_dir result;
  eprintf "Output written to: %s/\n%!" output_dir;
  Option.iter (Option.both trace_path trace) ~f:(fun (path, trace) ->
      _write_trace ~path ~trace);
  Out_channel.output_string stdout
    (Sexp.to_string_hum (Backtest.Summary.sexp_of_t result.summary));
  Out_channel.newline stdout
