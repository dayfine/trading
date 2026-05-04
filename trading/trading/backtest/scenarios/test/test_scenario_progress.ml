(** Pin the [Scenario_progress] emitter wiring used by [scenario_runner.exe].

    Two contracts are exercised here:

    1. {b Path convention}: [make_emitter ~scenario_dir ~every_n_fridays] builds
    an emitter whose [on_progress] callback writes [progress.sexp] under
    [scenario_dir] (NOT under a global output root). Recorded by asserting the
    file lands at the expected path after invoking the callback.

    2. {b End-to-end emission cadence via [Runner.run_backtest]}: a recording
    emitter substitute (NOT the [write_atomic] sink) is installed via the same
    [?progress_emitter] argument [scenario_runner.exe] uses, on a real smoke
    scenario. With [every_n_fridays = 1] the recorder must capture more than one
    snapshot, mirroring the test pattern from [test_backtest_progress.ml]. This
    pins the integration: the scenario's config + the runner's
    [progress_emitter] threading + the [Backtest_progress.accumulator] all line
    up.

    The recording-emitter substitute is the same shape as the one in
    [test_backtest_progress.ml]: a [ref] [list] that the [on_progress] callback
    appends to. We do NOT exercise the fork-per-cell scenario-runner path here —
    that's tested implicitly by the scenario-runner CLI smoke runs. *)

open OUnit2
open Core
open Matchers
module Backtest_progress = Backtest.Backtest_progress
module Scenario = Scenario_lib.Scenario
module Scenario_progress = Scenario_lib.Scenario_progress
module Universe_file = Scenario_lib.Universe_file

let _fixtures_root () =
  let data_dir = Data_path.default_data_dir () |> Fpath.to_string in
  Filename.concat data_dir "backtest_scenarios"

(* Smallest, fastest scenario in the catalog (perf-tier-1, 7 symbols, ~6
   months) so the test stays well inside any per-PR budget. Same scenario as
   [test_backtest_progress.ml] and [test_panel_runner_gc_trace] for cross-test
   consistency. *)
let _scenario_rel = "smoke/tiered-loader-parity.sexp"
let _load_scenario rel = Scenario.load (Filename.concat (_fixtures_root ()) rel)

let _sector_map_override (s : Scenario.t) =
  let resolved = Filename.concat (_fixtures_root ()) s.universe_path in
  Universe_file.to_sector_map_override (Universe_file.load resolved)

(* Pin the documented default of 4 Friday cycles (≈ monthly) so any change to
   the cadence default is a deliberate, code-reviewed action — not silent. *)
let test_default_every_n_fridays_is_four _ =
  assert_that Scenario_progress.default_every_n_fridays (equal_to 4)

(* Pin the path convention: [make_emitter ~scenario_dir]'s [on_progress]
   writes to [<scenario_dir>/progress.sexp] (NOT a global path). *)
let test_make_emitter_writes_under_scenario_dir _ =
  let tmp_dir = Filename_unix.temp_dir "scenario_progress_test_" "" in
  let emitter =
    Scenario_progress.make_emitter ~scenario_dir:tmp_dir ~every_n_fridays:4
  in
  let progress : Backtest_progress.t =
    {
      started_at = 1714780000.0;
      updated_at = 1714780123.5;
      cycles_done = 4;
      cycles_total = 838;
      last_completed_date = Date.create_exn ~y:2014 ~m:Month.Dec ~d:26;
      trades_so_far = 7;
      current_equity = 152384.21;
    }
  in
  emitter.on_progress progress;
  let expected_path = Filename.concat tmp_dir "progress.sexp" in
  let exists = Stdlib.Sys.file_exists expected_path in
  let loaded =
    if exists then
      Some (Sexp.load_sexp expected_path |> Backtest_progress.t_of_sexp)
    else None
  in
  (* Cleanup. *)
  if exists then Stdlib.Sys.remove expected_path;
  Stdlib.Sys.rmdir tmp_dir;
  assert_that
    (exists, emitter.every_n_fridays, loaded)
    (all_of
       [
         field (fun (e, _, _) -> e) (equal_to true);
         field (fun (_, n, _) -> n) (equal_to 4);
         field
           (fun (_, _, l) -> l)
           (is_some_and
              (field (fun p -> p.Backtest_progress.cycles_done) (equal_to 4)));
       ])

(* End-to-end pin: a recording emitter threaded through [Runner.run_backtest]
   with [every_n_fridays = 1] fires more than once on the smoke scenario, plus
   the unconditional final write. Mirrors [test_emitter_fires_during_run] in
   [test_backtest_progress.ml]. *)
let test_recorded_emitter_fires_during_scenario_run _ =
  let s = _load_scenario _scenario_rel in
  let sector_map_override = _sector_map_override s in
  let recorder = ref [] in
  let progress_emitter : Backtest_progress.emitter =
    {
      every_n_fridays = 1;
      on_progress = (fun p -> recorder := !recorder @ [ p ]);
    }
  in
  let _result =
    Backtest.Runner.run_backtest ~start_date:s.period.start_date
      ~end_date:s.period.end_date ~overrides:s.config_overrides
      ?sector_map_override ~progress_emitter ()
  in
  assert_that (List.length !recorder) (gt (module Int_ord) 4)

let suite =
  "Scenario_progress"
  >::: [
         "default_every_n_fridays is 4 (monthly)"
         >:: test_default_every_n_fridays_is_four;
         "make_emitter writes progress.sexp under scenario_dir"
         >:: test_make_emitter_writes_under_scenario_dir;
         "recorded emitter fires during scenario run via Runner.run_backtest"
         >:: test_recorded_emitter_fires_during_scenario_run;
       ]

(* CI sets [TRADING_DATA_DIR] explicitly. Local dev container does not, so
   [Data_path.default_data_dir ()] would fall back to [/workspaces/trading-1/data]
   where [backtest_scenarios/] does not exist. Fall back to the canonical local
   path before the suite runs so the test works in both environments. Same
   logic as [test_scenario_runner_isolation.ml]. *)
let _ensure_trading_data_dir () =
  match Sys.getenv "TRADING_DATA_DIR" with
  | Some _ -> ()
  | None ->
      let local_default = "/workspaces/trading-1/trading/test_data" in
      if Sys_unix.is_directory_exn local_default then
        Core_unix.putenv ~key:"TRADING_DATA_DIR" ~data:local_default

let () =
  _ensure_trading_data_dir ();
  run_test_tt_main suite
