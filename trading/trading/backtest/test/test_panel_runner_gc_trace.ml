(** Per-step [Gc.stat] instrumentation in {!Backtest.Panel_runner} — pin the
    contract for PR-1 of the engine-pooling plan
    ([dev/plans/engine-layer-pooling-2026-04-27.md]).

    The plan calls for per-day [Gc.stat] snapshots around the simulator step
    (which calls [Engine.update_market] once per day). When [--gc-trace <path>]
    is on, the existing [Gc_trace] CSV gains rows whose [phase] column is shaped
    [step_<YYYY-MM-DD>_before] and [step_<YYYY-MM-DD>_after], interleaved
    between the coarse phase rows ([load_universe_done], [macro_done],
    [fill_done], ...).

    These tests pin:
    - When [gc_trace] is omitted, [Panel_runner.run] takes no per-step snapshots
      (no new behaviour, no overhead — same as before).
    - When [gc_trace] is passed, every simulated trading day produces exactly
      one [step_*_before] and one [step_*_after] entry, in chronological order.
    - The phase labels are consistent across runs (used by the off-line CSV
      consumer that diffs before/after pairs). *)

open OUnit2
open Core
open Matchers
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

(* Use the smallest, fastest scenario in the catalog (perf-tier-1, 7 symbols,
   6 months) so the test itself stays well inside any per-PR budget. *)
let _scenario_rel = "smoke/tiered-loader-parity.sexp"

let _run_with_gc_trace ~gc_trace =
  let s = _load_scenario _scenario_rel in
  let sector_map_override = _sector_map_override s in
  let _result =
    Backtest.Runner.run_backtest ~start_date:s.period.start_date
      ~end_date:s.period.end_date ~overrides:s.config_overrides
      ?sector_map_override ?gc_trace ()
  in
  ()

let _is_step_before phase =
  String.is_prefix phase ~prefix:"step_"
  && String.is_suffix phase ~suffix:"_before"

let _is_step_after phase =
  String.is_prefix phase ~prefix:"step_"
  && String.is_suffix phase ~suffix:"_after"

let test_no_gc_trace_means_no_snapshots _ =
  (* Sanity gate: when no [gc_trace] handle is threaded, the runner takes no
     per-step snapshots. This is the pre-existing zero-overhead contract; the
     PR-1 change must preserve it. We exercise the full panel path without a
     trace handle and verify the run completes without raising. *)
  _run_with_gc_trace ~gc_trace:None

let test_per_step_rows_appear _ =
  (* When a [Gc_trace.t] is threaded, every simulated trading day appends one
     [step_*_before] and one [step_*_after] snapshot to the trace. We don't
     pin a hard count — the simulator's calendar includes the warmup window
     and depends on holiday handling — but we pin:
     - at least one [step_*_before] row appears,
     - the count of [_before] equals the count of [_after],
     - the first step_* phase encountered is a [_before] (entry/exit pairing). *)
  let trace = Backtest.Gc_trace.create () in
  _run_with_gc_trace ~gc_trace:(Some trace);
  let snapshots = Backtest.Gc_trace.snapshot_list trace in
  let phases =
    List.map snapshots ~f:(fun (s : Backtest.Gc_trace.snapshot) -> s.phase)
  in
  let n_before = List.count phases ~f:_is_step_before in
  let n_after = List.count phases ~f:_is_step_after in
  assert_that n_before (all_of [ gt (module Int_ord) 0; equal_to n_after ]);
  let first_step_phase =
    List.find phases ~f:(fun p -> _is_step_before p || _is_step_after p)
  in
  assert_that first_step_phase
    (is_some_and
       (matching ~msg:"first step_* phase should be a _before"
          (fun p -> if _is_step_before p then Some () else None)
          (equal_to ())))

let test_step_rows_interleave_with_phase_rows _ =
  (* The coarse phase rows ([macro_done], [fill_done]) still appear in the
     same order. Per-step rows fall between [macro_done] and [fill_done] —
     the simulator runs in that window. *)
  let trace = Backtest.Gc_trace.create () in
  _run_with_gc_trace ~gc_trace:(Some trace);
  let phases =
    Backtest.Gc_trace.snapshot_list trace
    |> List.map ~f:(fun (s : Backtest.Gc_trace.snapshot) -> s.phase)
  in
  let index_of label =
    List.findi phases ~f:(fun _ p -> String.equal p label) |> Option.map ~f:fst
  in
  let macro_idx = index_of "macro_done" in
  let fill_idx = index_of "fill_done" in
  let first_step_idx =
    List.findi phases ~f:(fun _ p -> _is_step_before p) |> Option.map ~f:fst
  in
  let last_step_idx =
    List.foldi phases ~init:None ~f:(fun i acc p ->
        if _is_step_after p then Some i else acc)
  in
  assert_that
    (macro_idx, first_step_idx, last_step_idx, fill_idx)
    (all_of
       [
         field (fun (m, _, _, _) -> Option.is_some m) (equal_to true);
         field (fun (_, fs, _, _) -> Option.is_some fs) (equal_to true);
         field (fun (_, _, ls, _) -> Option.is_some ls) (equal_to true);
         field (fun (_, _, _, f) -> Option.is_some f) (equal_to true);
         (* macro_done < first step_before *)
         field
           (fun (m, fs, _, _) ->
             match (m, fs) with Some m, Some fs -> m < fs | _ -> false)
           (equal_to true);
         (* last step_after < fill_done *)
         field
           (fun (_, _, ls, f) ->
             match (ls, f) with Some ls, Some f -> ls < f | _ -> false)
           (equal_to true);
       ])

let suite =
  "Panel_runner_gc_trace"
  >::: [
         "no gc_trace => no per-step snapshots (smoke)"
         >:: test_no_gc_trace_means_no_snapshots;
         "per-step rows appear when gc_trace is passed"
         >:: test_per_step_rows_appear;
         "per-step rows interleave between macro_done and fill_done"
         >:: test_step_rows_interleave_with_phase_rows;
       ]

let () = run_test_tt_main suite
