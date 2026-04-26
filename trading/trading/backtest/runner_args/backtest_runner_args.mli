(** Argument parsing for [backtest_runner.exe]. Lives in its own library so the
    parsing logic is unit-testable independently of the executable's
    side-effecting [main]. *)

open Core

type t = {
  start_date : string;
  end_date : string option;
      (** Raw end-date string as passed on the command line, or [None] when
          omitted. Resolution to a {!Date.t} (defaulting to today) is the
          caller's responsibility — the parser stays free of clock reads so it
          remains a pure function. *)
  overrides : Sexp.t list;
      (** Override sexps in the order they were passed on the command line. Each
          is the parsed sexp of one [--override <sexp>] argument. *)
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
          [memtrace_viewer]. The tracer auto-stops at process exit via an
          [at_exit] hook registered by [Memtrace] itself. Workstream B7 of
          [dev/plans/backtest-perf-2026-04-24.md] — per-callsite allocation
          attribution. *)
}
(** Result of parsing the [backtest_runner.exe] command line. *)

val parse : string list -> t Status.status_or
(** [parse args] parses [args] (excluding the program name, e.g.
    [Array.to_list (Sys.get_argv ()) |> List.tl_exn]) into a {!t}.

    Returns [Error status] (with [Status.code = Invalid_argument]) on any
    parsing problem (missing flag value, missing required positional, too many
    positionals). The executable's [main] turns [Error _] into an [eprintf] +
    [Stdlib.exit 1]; tests assert via the [Matchers] library's [is_ok_and_holds]
    / [is_error]. *)
