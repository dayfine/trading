(** Unit tests for {!Backtest_runner_args.parse}. The full executable
    ([backtest_runner.exe]) reads real data files and is not exercised here;
    these tests pin only the CLI flag-parsing logic — including the
    [--trace <path>] flag (workstream B4 of
    [dev/plans/backtest-perf-2026-04-24.md]) and the [--memtrace <path>] flag
    (workstream B7 of the same plan). *)

open OUnit2
open Core
open Matchers

let test_minimal_start_date_only _ =
  let result = Backtest_runner_args.parse [ "2018-01-02" ] in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (a : Backtest_runner_args.t) -> a.start_date)
              (equal_to "2018-01-02");
            field
              (fun (a : Backtest_runner_args.t) -> a.end_date)
              (equal_to None);
            field (fun (a : Backtest_runner_args.t) -> a.overrides) (size_is 0);
            field
              (fun (a : Backtest_runner_args.t) -> a.loader_strategy)
              (equal_to None);
            field
              (fun (a : Backtest_runner_args.t) -> a.trace_path)
              (equal_to None);
            field
              (fun (a : Backtest_runner_args.t) -> a.memtrace_path)
              (equal_to None);
          ]))

let test_start_and_end_date _ =
  let result = Backtest_runner_args.parse [ "2018-01-02"; "2019-12-31" ] in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (a : Backtest_runner_args.t) -> a.start_date)
              (equal_to "2018-01-02");
            field
              (fun (a : Backtest_runner_args.t) -> a.end_date)
              (equal_to (Some "2019-12-31"));
          ]))

let test_loader_strategy_legacy _ =
  let result =
    Backtest_runner_args.parse [ "2018-01-02"; "--loader-strategy"; "legacy" ]
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (a : Backtest_runner_args.t) -> a.loader_strategy)
          (equal_to (Some Loader_strategy.Legacy))))

let test_loader_strategy_panel _ =
  let result =
    Backtest_runner_args.parse [ "2018-01-02"; "--loader-strategy"; "panel" ]
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (a : Backtest_runner_args.t) -> a.loader_strategy)
          (equal_to (Some Loader_strategy.Panel))))

let test_trace_flag _ =
  let result =
    Backtest_runner_args.parse [ "2018-01-02"; "--trace"; "/tmp/run.sexp" ]
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (a : Backtest_runner_args.t) -> a.trace_path)
          (equal_to (Some "/tmp/run.sexp"))))

let test_trace_default_is_none _ =
  let result = Backtest_runner_args.parse [ "2018-01-02" ] in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (a : Backtest_runner_args.t) -> a.trace_path)
          (equal_to None)))

let test_trace_with_other_flags _ =
  (* Verify that --trace composes with --loader-strategy, --override, and
     end_date in a single command. Order should not matter. *)
  let result =
    Backtest_runner_args.parse
      [
        "2018-01-02";
        "2019-12-31";
        "--loader-strategy";
        "panel";
        "--override";
        "((initial_stop_buffer 1.08))";
        "--trace";
        "/tmp/sample.sexp";
      ]
  in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (a : Backtest_runner_args.t) -> a.start_date)
              (equal_to "2018-01-02");
            field
              (fun (a : Backtest_runner_args.t) -> a.end_date)
              (equal_to (Some "2019-12-31"));
            field
              (fun (a : Backtest_runner_args.t) -> a.loader_strategy)
              (equal_to (Some Loader_strategy.Panel));
            field (fun (a : Backtest_runner_args.t) -> a.overrides) (size_is 1);
            field
              (fun (a : Backtest_runner_args.t) -> a.trace_path)
              (equal_to (Some "/tmp/sample.sexp"));
          ]))

let test_trace_missing_value _ =
  let result = Backtest_runner_args.parse [ "2018-01-02"; "--trace" ] in
  assert_that result is_error

let test_memtrace_flag _ =
  let result =
    Backtest_runner_args.parse
      [ "2018-01-02"; "--memtrace"; "/tmp/run.memtrace.ctf" ]
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (a : Backtest_runner_args.t) -> a.memtrace_path)
          (equal_to (Some "/tmp/run.memtrace.ctf"))))

let test_memtrace_default_is_none _ =
  let result = Backtest_runner_args.parse [ "2018-01-02" ] in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (a : Backtest_runner_args.t) -> a.memtrace_path)
          (equal_to None)))

let test_memtrace_with_other_flags _ =
  (* Verify --memtrace composes with --trace, --loader-strategy, --override,
     and end_date in a single command. The runner is meant to capture both
     phase-level traces (--trace) and per-callsite allocation traces
     (--memtrace) in one run for cross-correlation. *)
  let result =
    Backtest_runner_args.parse
      [
        "2018-01-02";
        "2019-12-31";
        "--loader-strategy";
        "panel";
        "--override";
        "((initial_stop_buffer 1.08))";
        "--trace";
        "/tmp/sample.trace.sexp";
        "--memtrace";
        "/tmp/sample.memtrace.ctf";
      ]
  in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (a : Backtest_runner_args.t) -> a.start_date)
              (equal_to "2018-01-02");
            field
              (fun (a : Backtest_runner_args.t) -> a.end_date)
              (equal_to (Some "2019-12-31"));
            field
              (fun (a : Backtest_runner_args.t) -> a.loader_strategy)
              (equal_to (Some Loader_strategy.Panel));
            field (fun (a : Backtest_runner_args.t) -> a.overrides) (size_is 1);
            field
              (fun (a : Backtest_runner_args.t) -> a.trace_path)
              (equal_to (Some "/tmp/sample.trace.sexp"));
            field
              (fun (a : Backtest_runner_args.t) -> a.memtrace_path)
              (equal_to (Some "/tmp/sample.memtrace.ctf"));
          ]))

let test_memtrace_missing_value _ =
  let result = Backtest_runner_args.parse [ "2018-01-02"; "--memtrace" ] in
  assert_that result is_error

let test_missing_start_date _ =
  let result = Backtest_runner_args.parse [] in
  assert_that result is_error

let test_too_many_positionals _ =
  let result =
    Backtest_runner_args.parse [ "2018-01-02"; "2019-12-31"; "extra" ]
  in
  assert_that result is_error

let test_loader_strategy_invalid _ =
  let result =
    Backtest_runner_args.parse [ "2018-01-02"; "--loader-strategy"; "bogus" ]
  in
  assert_that result is_error

(** End-to-end style test: simulate the executable's trace pipeline. Build a
    [Trace.t], record the same coarse phases the runner wraps, write to a temp
    path, then verify the file parses + contains the expected phases. Mirrors
    the manual-repro contract documented on the [--trace] flag without needing
    real data dirs to run a backtest. *)
let test_trace_write_and_parse _ =
  let trace = Backtest.Trace.create () in
  let runner_phases : Backtest.Trace.Phase.t list =
    [ Load_universe; Macro; Load_bars; Fill; Teardown ]
  in
  List.iter runner_phases ~f:(fun phase ->
      let _ = Backtest.Trace.record ~trace phase (fun () -> ()) in
      ());
  let dir = Core_unix.mkdtemp "/tmp/backtest_runner_trace_" in
  let out_path = Filename.concat dir "trace.sexp" in
  Backtest.Trace.write ~out_path (Backtest.Trace.snapshot trace);
  let sexp = Sexp.load_sexp out_path in
  let parsed = List.t_of_sexp Backtest.Trace.phase_metrics_of_sexp sexp in
  assert_that parsed
    (elements_are
       [
         field
           (fun (m : Backtest.Trace.phase_metrics) -> m.phase)
           (equal_to Backtest.Trace.Phase.Load_universe);
         field
           (fun (m : Backtest.Trace.phase_metrics) -> m.phase)
           (equal_to Backtest.Trace.Phase.Macro);
         field
           (fun (m : Backtest.Trace.phase_metrics) -> m.phase)
           (equal_to Backtest.Trace.Phase.Load_bars);
         field
           (fun (m : Backtest.Trace.phase_metrics) -> m.phase)
           (equal_to Backtest.Trace.Phase.Fill);
         field
           (fun (m : Backtest.Trace.phase_metrics) -> m.phase)
           (equal_to Backtest.Trace.Phase.Teardown);
       ])

let suite =
  "Backtest_runner_args"
  >::: [
         "minimal start_date only" >:: test_minimal_start_date_only;
         "start and end date" >:: test_start_and_end_date;
         "--loader-strategy legacy" >:: test_loader_strategy_legacy;
         "--loader-strategy panel" >:: test_loader_strategy_panel;
         "--trace flag captures path" >:: test_trace_flag;
         "no --trace yields trace_path = None" >:: test_trace_default_is_none;
         "--trace composes with other flags" >:: test_trace_with_other_flags;
         "--trace without value is an error" >:: test_trace_missing_value;
         "--memtrace flag captures path" >:: test_memtrace_flag;
         "no --memtrace yields memtrace_path = None"
         >:: test_memtrace_default_is_none;
         "--memtrace composes with --trace and other flags"
         >:: test_memtrace_with_other_flags;
         "--memtrace without value is an error" >:: test_memtrace_missing_value;
         "missing start_date is an error" >:: test_missing_start_date;
         "too many positionals is an error" >:: test_too_many_positionals;
         "invalid --loader-strategy value is an error"
         >:: test_loader_strategy_invalid;
         "trace pipeline write+parse round-trip" >:: test_trace_write_and_parse;
       ]

let () = run_test_tt_main suite
