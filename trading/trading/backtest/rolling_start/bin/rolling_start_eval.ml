(** [rolling_start_eval] — run a rolling-start dispersion evaluation.

    Given one scenario sexp, enumerate start dates at a fixed cadence
    ([--start-stride-days], default 91 = quarterly) from the scenario's natural
    start up to (but excluding) a fixed end date, run
    {!Backtest.Runner.run_backtest} once per start, collect each run's terminal
    CAGR / capital-relative drawdown / peak-relative drawdown, and emit the
    {!Rolling_start.Rolling_start_types.report} — both the human-readable
    markdown table and the machine-readable sexp.

    Plan: [dev/plans/evaluation-objective-and-metrics-2026-06-07.md] §2 P1. This
    is a thin CLI wrapper over {!Rolling_start.Rolling_start_runner.run}; the
    enumeration + per-start metric extraction live in that lib (unit-tested
    without a backtest).

    Usage:
    {[
      rolling_start_eval --scenario <path.sexp>
        [--end-date YYYY-MM-DD] [--start-stride-days N]
        [--fixtures-root <path>] [--snapshot-dir <path>] [--out <path>]
    ]}

    [--end-date] overrides the scenario's own end date (defaults to the
    scenario's [period.end_date] when omitted). [--out], when given, writes the
    markdown to that path; otherwise the markdown goes to stdout. The derived
    sexp always goes to stderr so it can be redirected independently. *)

open Core
module Runner = Rolling_start.Rolling_start_runner
module RT = Rolling_start.Rolling_start_types
module Scenario = Scenario_lib.Scenario
module Fixtures_root = Scenario_lib.Fixtures_root
module Bar_source_resolver = Scenario_lib.Bar_source_resolver

let _default_stride_days = 91

let _usage () =
  eprintf
    "Usage: rolling_start_eval --scenario <path.sexp> [--end-date YYYY-MM-DD] \
     [--start-stride-days N] [--fixtures-root <path>] [--snapshot-dir <path>] \
     [--out <path>]\n";
  Stdlib.exit 1

type _parse_acc = {
  mutable scenario_path : string option;
  mutable end_date : Date.t option;
  mutable stride_days : int option;
  mutable fixtures_root : string option;
  mutable snapshot_dir : string option;
  mutable out_path : string option;
}

let _parse_date label s =
  match Or_error.try_with (fun () -> Date.of_string s) with
  | Ok d -> d
  | Error _ ->
      eprintf "%s requires a YYYY-MM-DD date, got %S\n" label s;
      Stdlib.exit 1

let _parse_stride s =
  match Int.of_string_opt s with
  | Some n when n > 0 -> n
  | _ ->
      eprintf "--start-stride-days requires a positive integer, got %S\n" s;
      Stdlib.exit 1

let _parse_flag args =
  let acc =
    {
      scenario_path = None;
      end_date = None;
      stride_days = None;
      fixtures_root = None;
      snapshot_dir = None;
      out_path = None;
    }
  in
  let rec loop args =
    match args with
    | [] -> acc
    | "--scenario" :: path :: rest ->
        acc.scenario_path <- Some path;
        loop rest
    | "--end-date" :: s :: rest ->
        acc.end_date <- Some (_parse_date "--end-date" s);
        loop rest
    | "--start-stride-days" :: s :: rest ->
        acc.stride_days <- Some (_parse_stride s);
        loop rest
    | "--fixtures-root" :: path :: rest ->
        acc.fixtures_root <- Some path;
        loop rest
    | "--snapshot-dir" :: path :: rest ->
        acc.snapshot_dir <- Some path;
        loop rest
    | "--out" :: path :: rest ->
        acc.out_path <- Some path;
        loop rest
    | _ -> _usage ()
  in
  loop args

(** Build the runner config from the parsed flags + loaded scenario, resolving
    the fixtures root and snapshot source the same way [scenario_runner] does.
*)
let _config_of (acc : _parse_acc) (scenario : Scenario.t) : Runner.config =
  let fixtures_root =
    Fixtures_root.resolve ?fixtures_root:acc.fixtures_root ()
  in
  let bar_data_source = Bar_source_resolver.resolve acc.snapshot_dir in
  let end_date = Option.value acc.end_date ~default:scenario.period.end_date in
  let stride_days =
    Option.value acc.stride_days ~default:_default_stride_days
  in
  { Runner.scenario; end_date; stride_days; fixtures_root; bar_data_source }

let _emit ~(out_path : string option) (report : RT.report) =
  let markdown = RT.to_markdown report in
  (match out_path with
  | Some path -> Out_channel.write_all path ~data:markdown
  | None -> print_string markdown);
  (* The derived sexp goes to stderr so a caller can capture the markdown on
     stdout and the machine-readable report independently. *)
  eprintf "%s\n%!" (Sexp.to_string_hum (RT.sexp_of_report report))

let () =
  let acc = _parse_flag (List.tl_exn (Array.to_list (Sys.get_argv ()))) in
  let scenario_path =
    match acc.scenario_path with
    | Some p -> p
    | None ->
        eprintf "--scenario <path.sexp> is required\n";
        _usage ()
  in
  let scenario = Scenario.load scenario_path in
  let config = _config_of acc scenario in
  eprintf "Rolling-start eval: %s\n%!" scenario.name;
  eprintf "  start=%s end=%s stride=%d days\n%!"
    (Date.to_string config.scenario.period.start_date)
    (Date.to_string config.end_date)
    config.stride_days;
  let report = Runner.run config in
  _emit ~out_path:acc.out_path report
