(** Unit tests for the [grid_search.exe] CLI's spec parser + runner glue.

    The full backtest path ([Grid_search_evaluator.build]) is intentionally not
    unit-tested here — it requires loading scenario fixtures + spinning up a
    real backtest, which the lib's tests already pin algorithmically. These
    tests pin the parts the binary owns:

    - {!Grid_search_spec.load} parses a spec file with both simple and
      [Composite] objectives.
    - {!Grid_search_runner.run_and_write} writes [grid.csv], [best.sexp], and
      [sensitivity.md] under the requested directory when given a stub evaluator
      (no real backtest required).
    - {!Grid_search_spec.to_grid_objective} round-trips every variant. *)

open OUnit2
open Core
open Matchers
module Spec = Tuner_bin.Grid_search_spec
module Runner = Tuner_bin.Grid_search_runner
module GS = Tuner.Grid_search
module Metric_types = Trading_simulation_types.Metric_types

(* ---------- temp-dir helper ---------- *)

let _with_temp_dir f =
  let dir =
    Filename_unix.temp_dir ~in_dir:Filename.temp_dir_name
      "grid_search_bin_test_" ""
  in
  Exn.protect
    ~f:(fun () -> f dir)
    ~finally:(fun () ->
      let rec rm_tree p =
        if Sys_unix.is_directory_exn p then begin
          Sys_unix.readdir p
          |> Array.iter ~f:(fun child -> rm_tree (Filename.concat p child));
          Core_unix.rmdir p
        end
        else Core_unix.unlink p
      in
      try rm_tree dir with _ -> ())

(* ---------- spec parsing ---------- *)

let _spec_text =
  String.concat
    [
      "((params";
      "  ((screening.weights.rs (0.2 0.3 0.4))";
      "   (screening.weights.volume (0.2 0.3))))";
      " (objective Sharpe)";
      " (scenarios (";
      "   \"path/to/bull.sexp\"";
      "   \"path/to/crash.sexp\"";
      " )))";
    ]
    ~sep:"\n"

let _write_spec_file dir contents =
  let path = Filename.concat dir "spec.sexp" in
  Out_channel.write_all path ~data:contents;
  path

let test_load_simple_objective_parses _ =
  _with_temp_dir (fun dir ->
      let path = _write_spec_file dir _spec_text in
      let spec = Spec.load path in
      assert_that spec.params (size_is 2);
      assert_that spec.scenarios (size_is 2);
      let obj = Spec.to_grid_objective spec.objective in
      assert_that obj (equal_to GS.Sharpe))

let _composite_spec_text =
  String.concat
    [
      "((params (";
      "   (initial_stop_buffer (1.05 1.08))))";
      " (objective (Composite ((SharpeRatio 1.0) (CalmarRatio 0.5))))";
      " (scenarios (\"path/to/scenario.sexp\")))";
    ]
    ~sep:"\n"

let test_load_composite_objective_parses _ =
  _with_temp_dir (fun dir ->
      let path = _write_spec_file dir _composite_spec_text in
      let spec = Spec.load path in
      let obj = Spec.to_grid_objective spec.objective in
      assert_that obj
        (matching ~msg:"expected Composite"
           (function GS.Composite ws -> Some ws | _ -> None)
           (elements_are
              [
                equal_to (Metric_types.SharpeRatio, 1.0);
                equal_to (Metric_types.CalmarRatio, 0.5);
              ])))

let test_load_malformed_raises _ =
  _with_temp_dir (fun dir ->
      let path = _write_spec_file dir "((params not-a-list))" in
      let raised =
        try
          let _ = Spec.load path in
          false
        with Failure msg ->
          String.is_substring msg ~substring:"failed to parse"
      in
      assert_that raised (equal_to true))

(* ---------- to_grid_objective coverage ---------- *)

let test_to_grid_objective_simple_variants _ =
  assert_that (Spec.to_grid_objective Spec.Sharpe) (equal_to GS.Sharpe);
  assert_that (Spec.to_grid_objective Spec.Calmar) (equal_to GS.Calmar);
  assert_that
    (Spec.to_grid_objective Spec.TotalReturn)
    (equal_to GS.TotalReturn);
  assert_that
    (Spec.to_grid_objective Spec.Concavity_coef)
    (equal_to GS.Concavity_coef)

(* ---------- run_and_write integration with stub evaluator ---------- *)

let _stub_evaluator : GS.evaluator =
 fun cell ~scenario:_ ->
  let s = List.fold cell ~init:0.0 ~f:(fun acc (_, v) -> acc +. v) in
  Metric_types.of_alist_exn [ (Metric_types.SharpeRatio, s) ]

let test_run_and_write_emits_three_artefacts _ =
  let spec : Spec.t =
    {
      params = [ ("a", [ 1.0; 2.0 ]); ("b", [ 10.0; 20.0 ]) ];
      objective = Spec.Sharpe;
      scenarios = [ "s1"; "s2" ];
    }
  in
  _with_temp_dir (fun dir ->
      let out_dir = Filename.concat dir "out" in
      let result =
        Runner.run_and_write ~spec ~out_dir ~evaluator:_stub_evaluator
      in
      (* Argmax: (a=2, b=20) wins with score = 22. *)
      assert_that result.best_score (float_equal 22.0);
      assert_that result.best_cell
        (elements_are [ equal_to ("a", 2.0); equal_to ("b", 20.0) ]);
      let exists rel = Sys_unix.file_exists_exn (Filename.concat out_dir rel) in
      assert_that (exists "grid.csv") (equal_to true);
      assert_that (exists "best.sexp") (equal_to true);
      assert_that (exists "sensitivity.md") (equal_to true);
      (* CSV: 1 header + 4 rows (2 cells × 2 scenarios = 4 rows).
         (a, b) cells = 4; cells × scenarios = 8 rows + header = 9. *)
      let csv_lines =
        In_channel.read_lines (Filename.concat out_dir "grid.csv")
      in
      assert_that csv_lines (size_is 9))

let test_run_and_write_creates_missing_out_dir _ =
  let spec : Spec.t =
    {
      params = [ ("a", [ 1.0 ]) ];
      objective = Spec.Sharpe;
      scenarios = [ "s" ];
    }
  in
  _with_temp_dir (fun dir ->
      (* Nest two levels — confirm mkdir -p semantics. *)
      let out_dir = Filename.concat dir "deep/nested/out" in
      let _result =
        Runner.run_and_write ~spec ~out_dir ~evaluator:_stub_evaluator
      in
      assert_that (Sys_unix.is_directory_exn out_dir) (equal_to true))

let suite =
  "Tuner_bin.Grid_search"
  >::: [
         "Spec.load: simple objective parses"
         >:: test_load_simple_objective_parses;
         "Spec.load: Composite objective parses"
         >:: test_load_composite_objective_parses;
         "Spec.load: malformed file raises Failure"
         >:: test_load_malformed_raises;
         "Spec.to_grid_objective: simple variants round-trip"
         >:: test_to_grid_objective_simple_variants;
         "Runner.run_and_write: emits three artefacts"
         >:: test_run_and_write_emits_three_artefacts;
         "Runner.run_and_write: creates missing out-dir tree"
         >:: test_run_and_write_creates_missing_out_dir;
       ]

let () = run_test_tt_main suite
