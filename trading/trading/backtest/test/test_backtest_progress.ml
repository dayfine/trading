(** Periodic-progress emission contract for the backtest runner — see
    [dev/plans/data-pipeline-automation-2026-05-03.md] §"PR 2 — backtest
    checkpointing".

    Pin two behaviors:

    1. {b Friday cadence}: when a [Backtest_progress.emitter] is threaded
    through [Runner.run_backtest] with [every_n_fridays = 1], the runner fires
    the [on_progress] callback at least once during a multi-week simulation, and
    a final write always happens (regardless of whether the last completed step
    landed on an N-th Friday). The [progress.sexp] fields parse round-trip via
    [t_of_sexp].

    2. {b Atomic write}: [write_atomic] writes a well-formed sexp that can be
    parsed back into [Backtest_progress.t] with the same field values.

    These tests do NOT pin an exact [cycles_done] count — that depends on the
    scenario calendar / holidays / warmup window — but they do pin that the
    progress sexp records monotonically advance and that the structure is stable
    across runs. *)

open OUnit2
open Core
open Matchers
module Backtest_progress = Backtest.Backtest_progress
module Scenario = Scenario_lib.Scenario
module Universe_file = Scenario_lib.Universe_file

let _fixtures_root () =
  let data_dir = Data_path.default_data_dir () |> Fpath.to_string in
  Filename.concat data_dir "backtest_scenarios"

let _scenario_path rel = Filename.concat (_fixtures_root ()) rel
let _load_scenario rel = Scenario.load (_scenario_path rel)

let _sector_map_override (s : Scenario.t) =
  let resolved = Filename.concat (_fixtures_root ()) s.universe_path in
  Universe_file.to_sector_map_override (Universe_file.load resolved)

(* Smallest, fastest scenario in the catalog (perf-tier-1, 7 symbols, ~6
   months) so the test stays well inside any per-PR budget. Same scenario as
   [test_panel_runner_gc_trace] for cross-test consistency. *)
let _scenario_rel = "smoke/tiered-loader-parity.sexp"

let test_count_fridays_in_range _ =
  (* 2024-01-01 (Monday) .. 2024-01-31 (Wednesday) contains the Fridays
     2024-01-05, 2024-01-12, 2024-01-19, 2024-01-26 → 4. *)
  let start_date = Date.create_exn ~y:2024 ~m:Month.Jan ~d:1 in
  let end_date = Date.create_exn ~y:2024 ~m:Month.Jan ~d:31 in
  assert_that
    (Backtest_progress.count_fridays_in_range ~start_date ~end_date)
    (equal_to 4)

let test_count_fridays_zero_range _ =
  (* Single non-Friday day → 0; single Friday → 1. *)
  let mon = Date.create_exn ~y:2024 ~m:Month.Jan ~d:1 in
  let fri = Date.create_exn ~y:2024 ~m:Month.Jan ~d:5 in
  assert_that
    ( Backtest_progress.count_fridays_in_range ~start_date:mon ~end_date:mon,
      Backtest_progress.count_fridays_in_range ~start_date:fri ~end_date:fri )
    (all_of
       [
         field (fun (a, _) -> a) (equal_to 0);
         field (fun (_, b) -> b) (equal_to 1);
       ])

let test_write_atomic_round_trip _ =
  (* [write_atomic] produces a parsable sexp round-trip. Use a tmp directory so
     the test doesn't pollute the working tree. *)
  let tmp_dir = Filename_unix.temp_dir "backtest_progress_test_" "" in
  let path = Filename.concat tmp_dir "progress.sexp" in
  let progress : Backtest_progress.t =
    {
      started_at = 1714780000.0;
      updated_at = 1714780123.5;
      cycles_done = 42;
      cycles_total = 838;
      last_completed_date = Date.create_exn ~y:2014 ~m:Month.Dec ~d:26;
      trades_so_far = 7;
      current_equity = 152384.21;
    }
  in
  Backtest_progress.write_atomic ~path progress;
  let loaded = Sexp.load_sexp path |> Backtest_progress.t_of_sexp in
  (* Cleanup. *)
  Stdlib.Sys.remove path;
  Stdlib.Sys.rmdir tmp_dir;
  assert_that loaded
    (all_of
       [
         field (fun p -> p.Backtest_progress.cycles_done) (equal_to 42);
         field (fun p -> p.Backtest_progress.cycles_total) (equal_to 838);
         field (fun p -> p.Backtest_progress.trades_so_far) (equal_to 7);
         field
           (fun p -> p.Backtest_progress.last_completed_date)
           (equal_to (Date.create_exn ~y:2014 ~m:Month.Dec ~d:26));
         field
           (fun p -> p.Backtest_progress.current_equity)
           (float_equal 152384.21);
       ])

(* CP4 pin: [write_atomic]'s docstring guarantees "must never crash" on
   filesystem errors. Exercise the guarded scenario by writing to a path
   under a non-existent parent directory and asserting no exception
   escapes. *)
let test_write_atomic_does_not_crash_on_missing_parent _ =
  let progress : Backtest_progress.t =
    {
      started_at = 1714780000.0;
      updated_at = 1714780000.0;
      cycles_done = 1;
      cycles_total = 100;
      last_completed_date = Date.create_exn ~y:2010 ~m:Month.Jan ~d:1;
      trades_so_far = 0;
      current_equity = 100000.0;
    }
  in
  let bogus_path =
    "/tmp/nonexistent_parent_dir_for_backtest_progress_test/progress.sexp"
  in
  (* The contract: write_atomic must NOT raise even when the destination
     can't be written. Implementation should swallow Sys_error / Failure. *)
  Backtest_progress.write_atomic ~path:bogus_path progress;
  (* If we got here, the contract held. *)
  assert_that () (equal_to ())

let _run_with_emitter ~every_n_fridays ~recorder =
  let s = _load_scenario _scenario_rel in
  let sector_map_override = _sector_map_override s in
  let progress_emitter : Backtest_progress.emitter =
    { every_n_fridays; on_progress = (fun p -> recorder := !recorder @ [ p ]) }
  in
  let _result =
    Backtest.Runner.run_backtest ~start_date:s.period.start_date
      ~end_date:s.period.end_date ~overrides:s.config_overrides
      ?sector_map_override ~progress_emitter ()
  in
  ()

let test_emitter_fires_during_run _ =
  (* With [every_n_fridays = 1], every Friday triggers an emission, and a
     final emission always lands. The smoke scenario covers ~6 months of
     calendar days including warmup, so we expect [>= 4] emissions
     (very conservative). *)
  let recorder = ref [] in
  _run_with_emitter ~every_n_fridays:1 ~recorder;
  let snapshots = !recorder in
  assert_that (List.length snapshots) (gt (module Int_ord) 4)

let test_emitter_records_monotonic_progress _ =
  (* Across the recorded checkpoints, [cycles_done] is non-decreasing,
     [updated_at] is non-decreasing, and the FINAL emission's
     [last_completed_date] >= the first emission's [last_completed_date]. *)
  let recorder = ref [] in
  _run_with_emitter ~every_n_fridays:2 ~recorder;
  let snapshots = !recorder in
  let dates =
    List.map snapshots ~f:(fun p -> p.Backtest_progress.last_completed_date)
  in
  let cycles =
    List.map snapshots ~f:(fun p -> p.Backtest_progress.cycles_done)
  in
  let updated_ats =
    List.map snapshots ~f:(fun p -> p.Backtest_progress.updated_at)
  in
  let is_sorted ~compare xs =
    List.is_sorted xs ~compare:(fun a b ->
        if compare a b < 0 then -1 else if compare a b > 0 then 1 else 0)
  in
  assert_that
    ( is_sorted ~compare:Date.compare dates,
      is_sorted ~compare:Int.compare cycles,
      is_sorted ~compare:Float.compare updated_ats,
      List.length snapshots > 0 )
    (all_of
       [
         field (fun (a, _, _, _) -> a) (equal_to true);
         field (fun (_, b, _, _) -> b) (equal_to true);
         field (fun (_, _, c, _) -> c) (equal_to true);
         field (fun (_, _, _, d) -> d) (equal_to true);
       ])

let test_emitter_final_write_always_fires _ =
  (* With [every_n_fridays] much larger than the scenario's Friday count,
     the per-N gate never fires — but the unconditional final-emission contract
     still produces exactly one write. *)
  let recorder = ref [] in
  _run_with_emitter ~every_n_fridays:10_000 ~recorder;
  let snapshots = !recorder in
  assert_that snapshots (size_is 1)

let suite =
  "Backtest_progress"
  >::: [
         "count_fridays_in_range counts inclusive"
         >:: test_count_fridays_in_range;
         "count_fridays handles single-day ranges"
         >:: test_count_fridays_zero_range;
         "write_atomic produces parsable sexp" >:: test_write_atomic_round_trip;
         "write_atomic does not crash on missing parent dir"
         >:: test_write_atomic_does_not_crash_on_missing_parent;
         "emitter fires during a real run with every_n_fridays = 1"
         >:: test_emitter_fires_during_run;
         "emitter records monotonic progress"
         >:: test_emitter_records_monotonic_progress;
         "final write always fires regardless of cadence"
         >:: test_emitter_final_write_always_fires;
       ]

let () = run_test_tt_main suite
