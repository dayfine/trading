(** Regression for issue #2606: [wall_seconds.txt] must measure the FULL
    per-scenario child span -- {!Backtest.Runner.run_backtest} PLUS every
    post-step that follows it (result-writer flush, candidate log, fold-health
    guard, and the all-eligible diagnostic when enabled) -- not stop the clock
    immediately after [run_backtest].

    Before the fix, the clock stopped right after [run_backtest] returned, so
    the all-eligible diagnostic's cost (48+ minutes on a broad universe when
    enabled -- qc-behavioral review 5064470899 on PR #2601) ran entirely outside
    the measured window. A golden whose wall exploded because of that diagnostic
    could still sail through its pinned [wall_seconds] band.

    Two layers, because [scenario_runner.ml] is an executable, not a library --
    its [_run_scenario_in_child] wall-clock logic isn't importable by test code
    (same constraint as {!test_scenario_runner_actual_sexp}):

    - {b structural}: read the [scenario_runner.ml] source and pin that the
      wall-clock computation appears strictly AFTER the all-eligible post-step's
      call site. Exact and deterministic; the layer that would catch a
      regression that re-introduces the early clock-stop verbatim.
    - {b integration}: run the real [scenario_runner.exe] binary (sibling-exe
      subprocess pattern from [test_csv_snapshot_builder_cleanup.ml]) on the
      fastest scenario in the catalog (perf-tier 1, 7 symbols / 6 months --
      [smoke/tiered-loader-parity.sexp]), with the all-eligible diagnostic at
      its default (enabled), and pins the write ORDER via mtime rather than
      duration magnitude: [wall_seconds.txt] must not be written before the
      diagnostic's own output. A tiny scenario's diagnostic cost is too small to
      distinguish reliably by elapsed-time comparison alone, but the write order
      is deterministic (sequential code, no concurrency) regardless of scenario
      size. *)

open OUnit2
open Core
open Matchers

(* -------------- structural layer -------------- *)

(* [scenario_runner.ml] lives one directory up from this test file --
   test/dune declares it a dep (source, not the built .exe) so it is present
   in the sandbox at that relative path; see the (deps ...) comment there. *)
let _scenario_runner_source_path = "../scenario_runner.ml"

(* Exact substrings from the two call sites under test. Both must remain
   unique in the file for the position comparison to be meaningful; a
   duplicate would make "first occurrence" ambiguous rather than wrong, so
   this is checked explicitly rather than assumed. *)
let _all_eligible_call_marker =
  "Backtest_all_eligible.Scenario_post_step.emit ~enabled:emit_all_eligible"

let _wall_seconds_compute_marker =
  "Time_ns.Span.to_sec (Time_ns.diff (Time_ns_unix.now ()) t_start)"

let _count_occurrences ~substring haystack =
  String.substr_index_all haystack ~may_overlap:false ~pattern:substring
  |> List.length

let test_wall_seconds_computed_after_all_eligible_call_site _ =
  let source = In_channel.read_all _scenario_runner_source_path in
  let all_eligible_occurrences =
    _count_occurrences ~substring:_all_eligible_call_marker source
  in
  let wall_seconds_occurrences =
    _count_occurrences ~substring:_wall_seconds_compute_marker source
  in
  let all_eligible_idx =
    String.substr_index source ~pattern:_all_eligible_call_marker
  in
  let wall_seconds_idx =
    String.substr_index source ~pattern:_wall_seconds_compute_marker
  in
  let computed_after =
    match (all_eligible_idx, wall_seconds_idx) with
    | Some a, Some w -> w > a
    | _ -> false
  in
  assert_that
    (all_eligible_occurrences, wall_seconds_occurrences, computed_after)
    (all_of
       [
         field (fun (n, _, _) -> n) (equal_to 1);
         field (fun (_, n, _) -> n) (equal_to 1);
         field (fun (_, _, ok) -> ok) (equal_to true);
       ])

(* -------------- integration layer -------------- *)

let _exit_code_not_executable = 126
let _exit_code_not_found = 127

(* The exe lives next to scenario_lib's build output one directory up -- kept
   there by test/dune's (deps ...), without which dune is free to skip
   building it and this test would silently read the shell's "not found"
   text (same hazard as issue #2565, csv_snapshot_builder_cleanup_subject). *)
let _scenario_runner_exe =
  Filename.concat
    (Filename.dirname (Filename.dirname Stdlib.Sys.executable_name))
    "scenario_runner.exe"

let _rm_rf path =
  if Stdlib.Sys.file_exists path then
    ignore
      (Stdlib.Sys.command (Printf.sprintf "rm -rf %s" (Filename.quote path))
        : int)

(* Fastest scenario in the catalog (perf-tier 1, 7 symbols, ~6 months) --
   same fixture [test_scenario_progress.ml] uses -- so a real run through the
   all-eligible diagnostic stays well inside a per-test budget. *)
let _fixtures_root () =
  let data_dir = Data_path.default_data_dir () |> Fpath.to_string in
  Filename.concat data_dir "backtest_scenarios"

let _stage_single_scenario_dir () =
  let src =
    Filename.concat (_fixtures_root ()) "smoke/tiered-loader-parity.sexp"
  in
  let tmp = Stdlib.Filename.temp_dir "wall_span_scenario_" "" in
  let exit_code =
    Stdlib.Sys.command
      (Printf.sprintf "cp %s %s/" (Filename.quote src) (Filename.quote tmp))
  in
  assert_bool
    (Printf.sprintf "failed to stage scenario fixture into %s (cp exit %d)" tmp
       exit_code)
    (exit_code = 0);
  tmp

(* Parses the "Output root: <path>" line [scenario_runner.exe] prints to
   stderr (see [scenario_runner.ml]'s [main]) -- the same convention
   [dev/scripts/golden_sp500_postsubmit.sh]-style chain scripts use to
   locate a run's artefacts without hardcoding the timestamped path. *)
let _parse_output_root log_text =
  String.split_lines log_text
  |> List.find_map ~f:(fun line ->
      match String.substr_index line ~pattern:"Output root: " with
      | None -> None
      | Some _ -> (
          match String.lsplit2 line ~on:':' with
          | Some (_, rest) -> Some (String.strip rest)
          | None -> None))

let _any_file_under dir =
  let out_path = Stdlib.Filename.temp_file "wall_span_find_" "" in
  let cmd =
    Printf.sprintf "find %s -type f > %s 2>/dev/null" (Filename.quote dir)
      (Filename.quote out_path)
  in
  ignore (Stdlib.Sys.command cmd : int);
  let lines = In_channel.read_lines out_path in
  _rm_rf out_path;
  List.hd lines

let test_wall_seconds_written_no_earlier_than_all_eligible_diagnostic _ =
  let scenario_dir = _stage_single_scenario_dir () in
  let log_path = Stdlib.Filename.temp_file "wall_span_run_" ".log" in
  let cmd =
    Printf.sprintf "%s --dir %s --fixtures-root %s --parallel 1 > %s 2>&1"
      _scenario_runner_exe
      (Filename.quote scenario_dir)
      (Filename.quote (_fixtures_root ()))
      (Filename.quote log_path)
  in
  let exit_code = Stdlib.Sys.command cmd in
  let log_text = In_channel.read_all log_path in
  _rm_rf log_path;
  _rm_rf scenario_dir;
  if exit_code = _exit_code_not_executable || exit_code = _exit_code_not_found
  then
    assert_failure
      (Printf.sprintf
         "could not execute %s (shell exit %d): it was not built. The [tests] \
          stanza in test/dune must keep it in its (deps ...). Shell output: %s"
         _scenario_runner_exe exit_code (String.strip log_text));
  let output_root =
    match _parse_output_root log_text with
    | Some root -> root
    | None ->
        assert_failure
          (Printf.sprintf
             "scenario_runner.exe produced no \"Output root: \" line (shell \
              exit %d); full output: %s"
             exit_code log_text)
  in
  let run_scenario_dir = Filename.concat output_root "tiered-loader-parity" in
  let wall_seconds_path = Filename.concat run_scenario_dir "wall_seconds.txt" in
  let all_eligible_dir = Filename.concat run_scenario_dir "all_eligible" in
  let wall_seconds_exists = Stdlib.Sys.file_exists wall_seconds_path in
  let all_eligible_file = _any_file_under all_eligible_dir in
  let all_eligible_present = Option.is_some all_eligible_file in
  let mtime path = (Core_unix.stat path).st_mtime in
  let ordering_ok =
    match all_eligible_file with
    | None -> false
    | Some f -> Float.(mtime wall_seconds_path >= mtime f)
  in
  _rm_rf output_root;
  assert_that
    (wall_seconds_exists, all_eligible_present, ordering_ok)
    (all_of
       [
         field (fun (w, _, _) -> w) (equal_to true);
         field (fun (_, f, _) -> f) (equal_to true);
         field (fun (_, _, ok) -> ok) (equal_to true);
       ])

let suite =
  "Scenario_runner_wall_span"
  >::: [
         "wall_seconds computed after the all-eligible call site (structural)"
         >:: test_wall_seconds_computed_after_all_eligible_call_site;
         "wall_seconds.txt written no earlier than the all-eligible \
          diagnostic's own output (integration)"
         >:: test_wall_seconds_written_no_earlier_than_all_eligible_diagnostic;
       ]

(* CI sets [TRADING_DATA_DIR] explicitly. Local dev container does not, so
   [Data_path.default_data_dir ()] would fall back to [/workspaces/trading-1/data]
   where [backtest_scenarios/] does not exist. Fall back to the canonical
   local path before the suite runs, same as [test_scenario_progress.ml] and
   [test_scenario_runner_isolation.ml]. *)
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
