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
  loader_strategy : Loader_strategy.t option;
      (** [None] when [--loader-strategy] was not passed; the runner then uses
          its default. [Some _] when the flag was passed with a recognised
          value. *)
  trace_path : string option;
      (** [None] when [--trace] was not passed (no trace file written).
          [Some path] when [--trace <path>] was passed; the runner constructs a
          {!Backtest.Trace.t}, threads it through
          [Backtest.Runner.run_backtest ~trace], and writes the trace sexp at
          [path] after the result is written. *)
}
(** Result of parsing the [backtest_runner.exe] command line. *)

val parse : string list -> t Status.status_or
(** [parse args] parses [args] (excluding the program name, e.g.
    [Array.to_list (Sys.get_argv ()) |> List.tl_exn]) into a {!t}.

    Returns [Error status] (with [Status.code = Invalid_argument]) on any
    parsing problem (missing flag value, unknown loader strategy, missing
    required positional, too many positionals). The executable's [main] turns
    [Error _] into an [eprintf] + [Stdlib.exit 1]; tests assert via the
    [Matchers] library's [is_ok_and_holds] / [is_error]. *)
