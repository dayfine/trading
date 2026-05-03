(** Unit tests for {!Backtest_runner_args.parse}. The full executable
    ([backtest_runner.exe]) reads real data files and is not exercised here;
    these tests pin only the CLI flag-parsing logic — including the
    [--trace <path>] flag (workstream B4 of
    [dev/plans/backtest-perf-2026-04-24.md]) and the [--memtrace <path>] flag
    (workstream B7 of the same plan).

    After Stage 3 PR 3.4 of the columnar data-shape redesign deleted the
    [Loader_strategy] enum + the [--loader-strategy] CLI flag, only the flags
    surviving on the panel-only path are pinned here.

    Since F.2 PR 3 (snapshot mode is the default; see
    [dev/plans/snapshot-engine-phase-f-2026-05-03.md]), every successful parse
    must specify a mode: either [--snapshot-dir <path>] (snapshot, the default)
    or [--csv-mode] (the explicit opt-out). Tests that pin orthogonal flags
    (overrides, fuzz, baseline, smoke, trace, memtrace, gc-trace, etc.) prepend
    [--csv-mode] via the [_parse_csv] helper so the flag-parsing assertions
    aren't entangled with snapshot validation. *)

open OUnit2
open Core
open Matchers

(** Parse with [--csv-mode] prepended. Use in tests that pin flag-parsing
    behaviour orthogonal to snapshot mode — the explicit opt-out keeps the parse
    Ok without forcing every test to fabricate a [--snapshot-dir] path. *)
let _parse_csv args = Backtest_runner_args.parse ("--csv-mode" :: args)

let test_minimal_start_date_only _ =
  let result = _parse_csv [ "2018-01-02" ] in
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
              (fun (a : Backtest_runner_args.t) -> a.shared_overrides)
              (size_is 0);
            field
              (fun (a : Backtest_runner_args.t) -> a.trace_path)
              (equal_to None);
            field
              (fun (a : Backtest_runner_args.t) -> a.memtrace_path)
              (equal_to None);
            field
              (fun (a : Backtest_runner_args.t) -> a.gc_trace_path)
              (equal_to None);
            field
              (fun (a : Backtest_runner_args.t) -> a.baseline)
              (equal_to false);
            field (fun (a : Backtest_runner_args.t) -> a.smoke) (equal_to false);
            field
              (fun (a : Backtest_runner_args.t) -> a.experiment_name)
              (equal_to None);
            field
              (fun (a : Backtest_runner_args.t) -> a.fuzz_spec)
              (equal_to None);
            field
              (fun (a : Backtest_runner_args.t) -> a.fuzz_window)
              (equal_to None);
            field
              (fun (a : Backtest_runner_args.t) -> a.snapshot_dir)
              (equal_to None);
            field
              (fun (a : Backtest_runner_args.t) -> a.progress_every)
              (equal_to None);
          ]))

let test_override_key_path_form _ =
  (* The new key.path=value form is stored verbatim — interpretation is the
     executable's job. *)
  let result =
    _parse_csv
      [ "2018-01-02"; "--override"; "stops_config.initial_stop_buffer=1.05" ]
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (a : Backtest_runner_args.t) -> a.overrides)
          (elements_are [ equal_to "stops_config.initial_stop_buffer=1.05" ])))

let test_override_legacy_sexp_form _ =
  (* Backward compatibility: pre-existing scripts pass full sexp blobs. *)
  let result =
    _parse_csv [ "2018-01-02"; "--override"; "((initial_stop_buffer 1.08))" ]
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (a : Backtest_runner_args.t) -> a.overrides)
          (elements_are [ equal_to "((initial_stop_buffer 1.08))" ])))

let test_override_can_repeat _ =
  let result =
    _parse_csv
      [
        "2018-01-02";
        "--override";
        "initial_stop_buffer=1.05";
        "--override";
        "stage_config.ma_period=40";
      ]
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (a : Backtest_runner_args.t) -> a.overrides)
          (elements_are
             [
               equal_to "initial_stop_buffer=1.05";
               equal_to "stage_config.ma_period=40";
             ])))

let test_baseline_flag _ =
  let result =
    _parse_csv
      [ "2018-01-02"; "--baseline"; "--experiment-name"; "stop_buffer_test" ]
  in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (a : Backtest_runner_args.t) -> a.baseline)
              (equal_to true);
            field
              (fun (a : Backtest_runner_args.t) -> a.experiment_name)
              (equal_to (Some "stop_buffer_test"));
          ]))

let test_baseline_without_experiment_name_is_error _ =
  let result = Backtest_runner_args.parse [ "2018-01-02"; "--baseline" ] in
  assert_that result is_error

let test_smoke_flag _ =
  let result =
    _parse_csv [ "--smoke"; "--experiment-name"; "stop_buffer_smoke" ]
  in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field (fun (a : Backtest_runner_args.t) -> a.smoke) (equal_to true);
            field
              (fun (a : Backtest_runner_args.t) -> a.experiment_name)
              (equal_to (Some "stop_buffer_smoke"));
            field
              (fun (a : Backtest_runner_args.t) -> a.start_date)
              (equal_to "smoke");
          ]))

let test_smoke_without_experiment_name_is_error _ =
  let result = Backtest_runner_args.parse [ "--smoke" ] in
  assert_that result is_error

let test_experiment_name_alone_is_allowed _ =
  (* --experiment-name without --baseline / --smoke just renames the output
     dir; both can be combined freely. *)
  let result = _parse_csv [ "2018-01-02"; "--experiment-name"; "manual_run" ] in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (a : Backtest_runner_args.t) -> a.experiment_name)
          (equal_to (Some "manual_run"))))

let test_experiment_name_missing_value_is_error _ =
  let result =
    Backtest_runner_args.parse [ "2018-01-02"; "--experiment-name" ]
  in
  assert_that result is_error

(** [--shared-override] is a sibling flag to [--override] that, in baseline
    mode, applies to BOTH the baseline and variant runs (not just variant). The
    parser stores raw strings the same way as [--override]; the executable's
    main is responsible for the per-mode merge. Repeatable. *)
let test_shared_override_can_repeat _ =
  let result =
    _parse_csv
      [
        "2018-01-02";
        "--shared-override";
        "universe_cap=500";
        "--shared-override";
        "skip_ad_breadth=true";
      ]
  in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (a : Backtest_runner_args.t) -> a.shared_overrides)
              (elements_are
                 [
                   equal_to "universe_cap=500"; equal_to "skip_ad_breadth=true";
                 ]);
            field (fun (a : Backtest_runner_args.t) -> a.overrides) (size_is 0);
          ]))

let test_shared_override_missing_value _ =
  let result =
    Backtest_runner_args.parse [ "2018-01-02"; "--shared-override" ]
  in
  assert_that result is_error

(** Both flag families compose freely on the same command line. The executable
    decides how to dispatch them per mode (single, baseline, smoke). *)
let test_shared_override_composes_with_override _ =
  let result =
    _parse_csv
      [
        "2018-01-02";
        "--shared-override";
        "universe_cap=500";
        "--override";
        "shorts_enabled=false";
      ]
  in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (a : Backtest_runner_args.t) -> a.shared_overrides)
              (elements_are [ equal_to "universe_cap=500" ]);
            field
              (fun (a : Backtest_runner_args.t) -> a.overrides)
              (elements_are [ equal_to "shorts_enabled=false" ]);
          ]))

let test_fuzz_flag _ =
  let result =
    _parse_csv
      [
        "2019-05-01";
        "--fuzz";
        "start_date=2019-05-01\xC2\xB15w:11";
        "--experiment-name";
        "fuzz_run";
      ]
  in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (a : Backtest_runner_args.t) -> a.fuzz_spec)
              (equal_to (Some "start_date=2019-05-01\xC2\xB15w:11"));
            field
              (fun (a : Backtest_runner_args.t) -> a.experiment_name)
              (equal_to (Some "fuzz_run"));
          ]))

let test_fuzz_without_experiment_name_is_error _ =
  let result =
    Backtest_runner_args.parse [ "2019-05-01"; "--fuzz"; "x=1.0\xC2\xB10.1:3" ]
  in
  assert_that result is_error

let test_fuzz_without_value_is_error _ =
  let result =
    Backtest_runner_args.parse
      [ "2019-05-01"; "--fuzz"; "--experiment-name"; "x" ]
  in
  (* "--experiment-name" gets consumed as the fuzz spec value here, then
     "x" becomes the positional. The parser then notices --experiment-name
     was never set (its value got eaten), so it errors. *)
  assert_that result is_error

let test_fuzz_no_positional_uses_sentinel _ =
  let result =
    _parse_csv
      [
        "--fuzz";
        "start_date=2019-05-01\xC2\xB15w:3";
        "--experiment-name";
        "fuzz_run";
      ]
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (a : Backtest_runner_args.t) -> a.start_date)
          (equal_to "fuzz")))

let test_fuzz_with_baseline_is_error _ =
  let result =
    Backtest_runner_args.parse
      [
        "2019-05-01";
        "--fuzz";
        "x=1.0\xC2\xB10.1:3";
        "--baseline";
        "--experiment-name";
        "x";
      ]
  in
  assert_that result is_error

let test_fuzz_with_smoke_is_error _ =
  let result =
    Backtest_runner_args.parse
      [ "--fuzz"; "x=1.0\xC2\xB10.1:3"; "--smoke"; "--experiment-name"; "x" ]
  in
  assert_that result is_error

let test_fuzz_window_with_fuzz _ =
  (* --fuzz-window composes with --fuzz to constrain the per-variant universe
     to a smoke-catalog window's universe_path (sp500 by default). *)
  let result =
    _parse_csv
      [
        "2020-04-30";
        "--fuzz";
        "start_date=2020-01-02\xC2\xB12w:3";
        "--fuzz-window";
        "crash";
        "--experiment-name";
        "fuzz_window_test";
      ]
  in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (a : Backtest_runner_args.t) -> a.fuzz_spec)
              (equal_to (Some "start_date=2020-01-02\xC2\xB12w:3"));
            field
              (fun (a : Backtest_runner_args.t) -> a.fuzz_window)
              (equal_to (Some "crash"));
          ]))

let test_fuzz_window_without_fuzz_is_error _ =
  (* --fuzz-window outside fuzz mode is meaningless — the override would
     have nowhere to apply. Surface it at parse time rather than silently
     ignoring. *)
  let result =
    Backtest_runner_args.parse
      [ "2020-01-02"; "--fuzz-window"; "crash"; "--experiment-name"; "x" ]
  in
  assert_that result is_error

let test_fuzz_window_missing_value _ =
  let result = Backtest_runner_args.parse [ "2020-01-02"; "--fuzz-window" ] in
  assert_that result is_error

let test_fuzz_with_overrides_composes _ =
  (* --fuzz composes with --override (overrides apply to every variant). *)
  let result =
    _parse_csv
      [
        "2019-05-01";
        "--fuzz";
        "stops_config.initial_stop_buffer=1.05\xC2\xB10.02:11";
        "--override";
        "universe_cap=300";
        "--experiment-name";
        "fuzz_with_shared";
      ]
  in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (a : Backtest_runner_args.t) -> a.fuzz_spec)
              (equal_to
                 (Some "stops_config.initial_stop_buffer=1.05\xC2\xB10.02:11"));
            field
              (fun (a : Backtest_runner_args.t) -> a.overrides)
              (elements_are [ equal_to "universe_cap=300" ]);
          ]))

let test_baseline_and_smoke_compose _ =
  let result =
    _parse_csv
      [
        "--smoke";
        "--baseline";
        "--override";
        "initial_stop_buffer=1.05";
        "--experiment-name";
        "stop_buffer_smoke_baseline";
      ]
  in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (a : Backtest_runner_args.t) -> a.baseline)
              (equal_to true);
            field (fun (a : Backtest_runner_args.t) -> a.smoke) (equal_to true);
            field
              (fun (a : Backtest_runner_args.t) -> a.overrides)
              (elements_are [ equal_to "initial_stop_buffer=1.05" ]);
          ]))

let test_start_and_end_date _ =
  let result = _parse_csv [ "2018-01-02"; "2019-12-31" ] in
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

let test_trace_flag _ =
  let result = _parse_csv [ "2018-01-02"; "--trace"; "/tmp/run.sexp" ] in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (a : Backtest_runner_args.t) -> a.trace_path)
          (equal_to (Some "/tmp/run.sexp"))))

let test_trace_default_is_none _ =
  let result = _parse_csv [ "2018-01-02" ] in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (a : Backtest_runner_args.t) -> a.trace_path)
          (equal_to None)))

let test_trace_with_other_flags _ =
  (* Verify that --trace composes with --override and end_date in a single
     command. Order should not matter. *)
  let result =
    _parse_csv
      [
        "2018-01-02";
        "2019-12-31";
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
    _parse_csv [ "2018-01-02"; "--memtrace"; "/tmp/run.memtrace.ctf" ]
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (a : Backtest_runner_args.t) -> a.memtrace_path)
          (equal_to (Some "/tmp/run.memtrace.ctf"))))

let test_memtrace_default_is_none _ =
  let result = _parse_csv [ "2018-01-02" ] in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (a : Backtest_runner_args.t) -> a.memtrace_path)
          (equal_to None)))

let test_memtrace_with_other_flags _ =
  (* Verify --memtrace composes with --trace, --override, and end_date in a
     single command. The runner is meant to capture both phase-level traces
     (--trace) and per-callsite allocation traces (--memtrace) in one run for
     cross-correlation. *)
  let result =
    _parse_csv
      [
        "2018-01-02";
        "2019-12-31";
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

let test_gc_trace_flag _ =
  let result = _parse_csv [ "2018-01-02"; "--gc-trace"; "/tmp/gc.csv" ] in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (a : Backtest_runner_args.t) -> a.gc_trace_path)
          (equal_to (Some "/tmp/gc.csv"))))

let test_gc_trace_default_is_none _ =
  let result = _parse_csv [ "2018-01-02" ] in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (a : Backtest_runner_args.t) -> a.gc_trace_path)
          (equal_to None)))

let test_gc_trace_with_other_flags _ =
  (* Verify --gc-trace composes with --trace, --memtrace, --override, and
     end_date in a single command. The runner is meant to capture phase-level
     traces (--trace), per-callsite allocation traces (--memtrace), and GC
     phase-boundary snapshots (--gc-trace) in one run for cross-correlation. *)
  let result =
    _parse_csv
      [
        "2018-01-02";
        "2019-12-31";
        "--override";
        "((initial_stop_buffer 1.08))";
        "--trace";
        "/tmp/sample.trace.sexp";
        "--memtrace";
        "/tmp/sample.memtrace.ctf";
        "--gc-trace";
        "/tmp/sample.gc.csv";
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
            field (fun (a : Backtest_runner_args.t) -> a.overrides) (size_is 1);
            field
              (fun (a : Backtest_runner_args.t) -> a.trace_path)
              (equal_to (Some "/tmp/sample.trace.sexp"));
            field
              (fun (a : Backtest_runner_args.t) -> a.memtrace_path)
              (equal_to (Some "/tmp/sample.memtrace.ctf"));
            field
              (fun (a : Backtest_runner_args.t) -> a.gc_trace_path)
              (equal_to (Some "/tmp/sample.gc.csv"));
          ]))

let test_gc_trace_missing_value _ =
  let result = Backtest_runner_args.parse [ "2018-01-02"; "--gc-trace" ] in
  assert_that result is_error

let test_missing_start_date _ =
  let result = Backtest_runner_args.parse [] in
  assert_that result is_error

let test_too_many_positionals _ =
  let result =
    Backtest_runner_args.parse [ "2018-01-02"; "2019-12-31"; "extra" ]
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
    [ Load_universe; Macro; Fill; Teardown ]
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
           (equal_to Backtest.Trace.Phase.Fill);
         field
           (fun (m : Backtest.Trace.phase_metrics) -> m.phase)
           (equal_to Backtest.Trace.Phase.Teardown);
       ])

(** Since F.2 PR 3, snapshot mode is the runner's default — passing
    [--snapshot-dir <path>] alone (no mode flag) is the canonical invocation and
    parses to a [Snapshot] selector. *)
let test_default_is_snapshot_mode_with_dir _ =
  let result =
    Backtest_runner_args.parse
      [ "2018-01-02"; "--snapshot-dir"; "/tmp/snapshots/v1" ]
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (a : Backtest_runner_args.t) -> a.snapshot_dir)
          (equal_to (Some "/tmp/snapshots/v1"))))

(** Default mode (snapshot) requires [--snapshot-dir] — the runner has no way to
    find a manifest otherwise. Surface the missing flag at parse time rather
    than letting the runner fail later. *)
let test_default_requires_snapshot_dir _ =
  let result = Backtest_runner_args.parse [ "2018-01-02" ] in
  assert_that result is_error

(** [--csv-mode] is the explicit opt-out onto the legacy CSV [data_dir] code
    path. CSV mode parses to [snapshot_dir = None] regardless of whether the
    user passed [--snapshot-dir] (combining the two is rejected — see below). *)
let test_csv_mode_opt_out _ =
  let result = Backtest_runner_args.parse [ "2018-01-02"; "--csv-mode" ] in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (a : Backtest_runner_args.t) -> a.snapshot_dir)
          (equal_to None)))

(** [--csv-mode] + [--snapshot-dir <path>] is rejected — the path would be
    silently dropped, which is a likely user error worth surfacing at parse
    time. *)
let test_csv_mode_with_snapshot_dir_errors _ =
  let result =
    Backtest_runner_args.parse
      [ "2018-01-02"; "--csv-mode"; "--snapshot-dir"; "/tmp/snapshots/v1" ]
  in
  assert_that result is_error

(** [--snapshot-mode] (legacy, no-op since F.2 PR 3) and [--csv-mode] are
    mutually exclusive: passing both means the user has contradicted themselves.
*)
let test_snapshot_mode_and_csv_mode_mutually_exclusive _ =
  let result =
    Backtest_runner_args.parse [ "2018-01-02"; "--snapshot-mode"; "--csv-mode" ]
  in
  assert_that result is_error

(** Backward compatibility: existing callers with
    [--snapshot-mode --snapshot-dir <path>] continue to parse to a [Snapshot]
    selector exactly as before. The legacy [--snapshot-mode] flag is now a
    documented no-op (snapshot mode is the default), but the runner does not
    reject the flag — that would break in-tree scenario / fuzz scripts and CI
    invocations landed before F.2 PR 3. *)
let test_legacy_snapshot_mode_flag_still_accepted _ =
  let result =
    Backtest_runner_args.parse
      [ "2018-01-02"; "--snapshot-mode"; "--snapshot-dir"; "/tmp/snapshots/v1" ]
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (a : Backtest_runner_args.t) -> a.snapshot_dir)
          (equal_to (Some "/tmp/snapshots/v1"))))

let test_snapshot_mode_without_dir_is_error _ =
  (* --snapshot-mode without --snapshot-dir has no way to find the manifest;
     we surface this at parse time rather than failing later inside the
     runner. (Same rule applies under the default since F.2 PR 3.) *)
  let result = Backtest_runner_args.parse [ "2018-01-02"; "--snapshot-mode" ] in
  assert_that result is_error

let test_snapshot_dir_missing_value _ =
  let result = Backtest_runner_args.parse [ "2018-01-02"; "--snapshot-dir" ] in
  assert_that result is_error

(** [--snapshot-mode] composes freely with [--fuzz]. The fuzz harness loops over
    N variants and threads the snapshot [Bar_data_source] into every per-variant
    [Runner.run_backtest] — pinning this composition here guards against a
    future parser change accidentally introducing a [--fuzz] vs.
    [--snapshot-mode] exclusivity rule. *)
let test_snapshot_mode_with_fuzz _ =
  let result =
    Backtest_runner_args.parse
      [
        "2019-05-01";
        "--fuzz";
        "start_date=2019-05-01\xC2\xB12w:3";
        "--fuzz-window";
        "bull";
        "--snapshot-mode";
        "--snapshot-dir";
        "/tmp/snapshots/v1";
        "--experiment-name";
        "fuzz_snapshot_test";
      ]
  in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (a : Backtest_runner_args.t) -> a.fuzz_spec)
              (equal_to (Some "start_date=2019-05-01\xC2\xB12w:3"));
            field
              (fun (a : Backtest_runner_args.t) -> a.fuzz_window)
              (equal_to (Some "bull"));
            field
              (fun (a : Backtest_runner_args.t) -> a.snapshot_dir)
              (equal_to (Some "/tmp/snapshots/v1"));
          ]))

let test_progress_every_flag _ =
  let result = _parse_csv [ "2018-01-02"; "--progress-every"; "25" ] in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (a : Backtest_runner_args.t) -> a.progress_every)
          (equal_to (Some 25))))

let test_progress_every_zero_is_error _ =
  let result = _parse_csv [ "2018-01-02"; "--progress-every"; "0" ] in
  assert_that result is_error

let test_progress_every_non_numeric_is_error _ =
  let result = _parse_csv [ "2018-01-02"; "--progress-every"; "fast" ] in
  assert_that result is_error

let test_progress_every_missing_value _ =
  let result = _parse_csv [ "2018-01-02"; "--progress-every" ] in
  assert_that result is_error

let suite =
  "Backtest_runner_args"
  >::: [
         "minimal start_date only" >:: test_minimal_start_date_only;
         "start and end date" >:: test_start_and_end_date;
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
         "--gc-trace flag captures path" >:: test_gc_trace_flag;
         "no --gc-trace yields gc_trace_path = None"
         >:: test_gc_trace_default_is_none;
         "--gc-trace composes with --trace, --memtrace, and other flags"
         >:: test_gc_trace_with_other_flags;
         "--gc-trace without value is an error" >:: test_gc_trace_missing_value;
         "missing start_date is an error" >:: test_missing_start_date;
         "too many positionals is an error" >:: test_too_many_positionals;
         "--override key.path=value form" >:: test_override_key_path_form;
         "--override legacy sexp form" >:: test_override_legacy_sexp_form;
         "--override can repeat" >:: test_override_can_repeat;
         "--baseline flag" >:: test_baseline_flag;
         "--baseline without --experiment-name is error"
         >:: test_baseline_without_experiment_name_is_error;
         "--smoke flag" >:: test_smoke_flag;
         "--smoke without --experiment-name is error"
         >:: test_smoke_without_experiment_name_is_error;
         "--experiment-name alone is allowed"
         >:: test_experiment_name_alone_is_allowed;
         "--experiment-name without value is error"
         >:: test_experiment_name_missing_value_is_error;
         "--shared-override can repeat" >:: test_shared_override_can_repeat;
         "--shared-override without value is an error"
         >:: test_shared_override_missing_value;
         "--shared-override composes with --override"
         >:: test_shared_override_composes_with_override;
         "--baseline + --smoke compose" >:: test_baseline_and_smoke_compose;
         "--fuzz flag captures spec" >:: test_fuzz_flag;
         "--fuzz without --experiment-name is error"
         >:: test_fuzz_without_experiment_name_is_error;
         "--fuzz without value is error" >:: test_fuzz_without_value_is_error;
         "--fuzz no positional uses sentinel"
         >:: test_fuzz_no_positional_uses_sentinel;
         "--fuzz with --baseline is error" >:: test_fuzz_with_baseline_is_error;
         "--fuzz with --smoke is error" >:: test_fuzz_with_smoke_is_error;
         "--fuzz composes with --override" >:: test_fuzz_with_overrides_composes;
         "--fuzz-window composes with --fuzz" >:: test_fuzz_window_with_fuzz;
         "--fuzz-window without --fuzz is error"
         >:: test_fuzz_window_without_fuzz_is_error;
         "--fuzz-window without value is error"
         >:: test_fuzz_window_missing_value;
         "default mode (no flag) + --snapshot-dir parses to Snapshot"
         >:: test_default_is_snapshot_mode_with_dir;
         "default mode (no flag) without --snapshot-dir is error"
         >:: test_default_requires_snapshot_dir;
         "--csv-mode opts out onto the legacy CSV path"
         >:: test_csv_mode_opt_out;
         "--csv-mode + --snapshot-dir is error"
         >:: test_csv_mode_with_snapshot_dir_errors;
         "--snapshot-mode + --csv-mode are mutually exclusive"
         >:: test_snapshot_mode_and_csv_mode_mutually_exclusive;
         "legacy --snapshot-mode + --snapshot-dir still accepted (no-op)"
         >:: test_legacy_snapshot_mode_flag_still_accepted;
         "--snapshot-mode without --snapshot-dir is error"
         >:: test_snapshot_mode_without_dir_is_error;
         "--snapshot-dir without value is error"
         >:: test_snapshot_dir_missing_value;
         "--snapshot-mode composes with --fuzz" >:: test_snapshot_mode_with_fuzz;
         "trace pipeline write+parse round-trip" >:: test_trace_write_and_parse;
         "--progress-every captures positive int" >:: test_progress_every_flag;
         "--progress-every 0 is rejected" >:: test_progress_every_zero_is_error;
         "--progress-every non-numeric is rejected"
         >:: test_progress_every_non_numeric_is_error;
         "--progress-every without value is error"
         >:: test_progress_every_missing_value;
       ]

let () = run_test_tt_main suite
