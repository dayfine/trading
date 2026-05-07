(** Unit tests for the [bayesian_runner.exe] CLI's spec parser + runner glue.

    The full backtest path ({!Tuner_bin.Bayesian_runner_evaluator.build}) is
    intentionally not unit-tested here — it requires loading scenario fixtures
    + spinning up a real backtest, which the lib's tests already pin
      algorithmically. These tests pin the parts the binary owns:

    - {!Tuner_bin.Bayesian_runner_spec.load} parses a spec file with both simple
      and [Composite] objectives + both [Expected_improvement] and
      [Upper_confidence_bound] acquisition variants.
    - {!Tuner_bin.Bayesian_runner_spec.to_grid_objective}, [to_acquisition], and
      [to_bo_config] round-trip every variant.
    - {!Tuner_bin.Bayesian_runner_runner.run_and_write} drives the BO loop
      against a stub evaluator (1D parabola), writes [bo_log.csv], [best.sexp],
      and [convergence.md] under the requested directory, and converges on the
      parabola peak.
    - {!Tuner_bin.Bayesian_runner_evaluator.build} raises [Failure] on unknown
      scenario paths (CP4 — pin the documented guard). *)

open OUnit2
open Core
open Matchers
module Spec = Tuner_bin.Bayesian_runner_spec
module Runner = Tuner_bin.Bayesian_runner_runner
module Evaluator = Tuner_bin.Bayesian_runner_evaluator
module GS = Tuner.Grid_search
module Metric_types = Trading_simulation_types.Metric_types

(* ---------- temp-dir helper ---------- *)

let _with_temp_dir f =
  let dir =
    Filename_unix.temp_dir ~in_dir:Filename.temp_dir_name
      "bayesian_runner_bin_test_" ""
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
      "((bounds";
      "  ((screening.weights.rs (0.1 0.5))";
      "   (screening.weights.volume (0.1 0.5))))";
      " (acquisition Expected_improvement)";
      " (initial_random 5)";
      " (total_budget 30)";
      " (seed (17))";
      " (n_acquisition_candidates ())";
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

let test_load_simple_spec_parses _ =
  _with_temp_dir (fun dir ->
      let path = _write_spec_file dir _spec_text in
      let spec = Spec.load path in
      assert_that spec.bounds
        (elements_are
           [
             equal_to ("screening.weights.rs", (0.1, 0.5));
             equal_to ("screening.weights.volume", (0.1, 0.5));
           ]);
      assert_that spec.scenarios (size_is 2);
      assert_that spec.initial_random (equal_to 5);
      assert_that spec.total_budget (equal_to 30);
      assert_that spec.seed (is_some_and (equal_to 17));
      assert_that spec.n_acquisition_candidates is_none)

let _ucb_spec_text =
  String.concat
    [
      "((bounds (";
      "  (initial_stop_buffer (1.05 1.20))))";
      " (acquisition (Upper_confidence_bound 2.5))";
      " (initial_random 3)";
      " (total_budget 20)";
      " (seed ())";
      " (n_acquisition_candidates (500))";
      " (objective (Composite ((SharpeRatio 1.0) (CalmarRatio 0.5))))";
      " (scenarios (\"path/to/scenario.sexp\")))";
    ]
    ~sep:"\n"

let test_load_ucb_acquisition_and_composite_objective_parses _ =
  _with_temp_dir (fun dir ->
      let path = _write_spec_file dir _ucb_spec_text in
      let spec = Spec.load path in
      let acq = Spec.to_acquisition spec.acquisition in
      assert_that acq (equal_to (`Upper_confidence_bound 2.5));
      let obj = Spec.to_grid_objective spec.objective in
      assert_that obj
        (matching ~msg:"expected Composite"
           (function GS.Composite ws -> Some ws | _ -> None)
           (elements_are
              [
                equal_to (Metric_types.SharpeRatio, 1.0);
                equal_to (Metric_types.CalmarRatio, 0.5);
              ]));
      assert_that spec.n_acquisition_candidates (is_some_and (equal_to 500));
      assert_that spec.seed is_none)

let test_load_malformed_raises _ =
  _with_temp_dir (fun dir ->
      let path = _write_spec_file dir "((bounds not-a-list))" in
      let raised =
        try
          let _ = Spec.load path in
          false
        with Failure msg ->
          String.is_substring msg ~substring:"failed to parse"
      in
      assert_that raised (equal_to true))

(* ---------- to_grid_objective + to_acquisition coverage ---------- *)

let test_to_grid_objective_simple_variants _ =
  assert_that (Spec.to_grid_objective Spec.Sharpe) (equal_to GS.Sharpe);
  assert_that (Spec.to_grid_objective Spec.Calmar) (equal_to GS.Calmar);
  assert_that
    (Spec.to_grid_objective Spec.TotalReturn)
    (equal_to GS.TotalReturn);
  assert_that
    (Spec.to_grid_objective Spec.Concavity_coef)
    (equal_to GS.Concavity_coef)

let test_to_acquisition_round_trips _ =
  assert_that
    (Spec.to_acquisition Spec.Expected_improvement)
    (equal_to `Expected_improvement);
  assert_that
    (Spec.to_acquisition (Spec.Upper_confidence_bound 1.5))
    (equal_to (`Upper_confidence_bound 1.5))

(* ---------- to_bo_config ---------- *)

let test_to_bo_config_propagates_fields _ =
  let spec : Spec.t =
    {
      bounds = [ ("x", (0.0, 6.0)) ];
      acquisition = Spec.Upper_confidence_bound 1.5;
      initial_random = 7;
      total_budget = 25;
      seed = Some 99;
      n_acquisition_candidates = None;
      objective = Spec.Sharpe;
      scenarios = [ "s" ];
    }
  in
  let config = Spec.to_bo_config spec in
  assert_that config.bounds (elements_are [ equal_to ("x", (0.0, 6.0)) ]);
  assert_that config.acquisition (equal_to (`Upper_confidence_bound 1.5));
  assert_that config.initial_random (equal_to 7);
  assert_that config.total_budget (equal_to 25)

(* ---------- run_and_write integration with stub evaluator ---------- *)

(** A 1D parabolic stub: [f(x) = -(x - 3)²]. Maximum 0.0 at x = 3.0. The BO loop
    should drive the running best toward 0.0. We return an empty per- scenario
    metric-set list (the runner threads it into [bo_log.csv] but the test
    asserts on the scalar argmax, not the metric columns). *)
let _parabola_evaluator : Runner.evaluator =
 fun ~parameters ->
  let x = List.Assoc.find_exn parameters ~equal:String.equal "x" in
  let metric = -.((x -. 3.0) *. (x -. 3.0)) in
  (* One scenario in the spec → one (empty) metric_set per call. *)
  let empty = Map.empty (module Metric_types.Metric_type) in
  (metric, [ empty ])

let _parabola_spec ~total_budget ~seed : Spec.t =
  {
    bounds = [ ("x", (0.0, 10.0)) ];
    acquisition = Spec.Expected_improvement;
    initial_random = 5;
    total_budget;
    seed = Some seed;
    n_acquisition_candidates = None;
    objective = Spec.Sharpe;
    scenarios = [ "stub-scenario" ];
  }

let test_run_and_write_emits_three_artefacts _ =
  let spec = _parabola_spec ~total_budget:20 ~seed:23 in
  _with_temp_dir (fun dir ->
      let out_dir = Filename.concat dir "out" in
      let result =
        Runner.run_and_write ~spec ~out_dir ~evaluator:_parabola_evaluator
      in
      assert_that result.observations (size_is 20);
      let exists rel = Sys_unix.file_exists_exn (Filename.concat out_dir rel) in
      assert_that (exists "bo_log.csv") (equal_to true);
      assert_that (exists "best.sexp") (equal_to true);
      assert_that (exists "convergence.md") (equal_to true);
      (* CSV: 1 header + 20 data rows (1 scenario × 20 iters). *)
      let csv_lines =
        In_channel.read_lines (Filename.concat out_dir "bo_log.csv")
      in
      assert_that csv_lines (size_is 21))

let test_run_and_write_converges_on_parabola _ =
  (* Parabola peak at x=3.0; tolerance 0.5 — pins that the BO loop is making
     progress without over-pinning the noisy GP-driven phase. *)
  let spec = _parabola_spec ~total_budget:20 ~seed:23 in
  _with_temp_dir (fun dir ->
      let out_dir = Filename.concat dir "out" in
      let result =
        Runner.run_and_write ~spec ~out_dir ~evaluator:_parabola_evaluator
      in
      let best_x =
        List.Assoc.find_exn result.best_params ~equal:String.equal "x"
      in
      assert_that (Float.abs (best_x -. 3.0)) (lt (module Float_ord) 0.5))

let test_run_and_write_creates_missing_out_dir _ =
  let spec = _parabola_spec ~total_budget:6 ~seed:5 in
  _with_temp_dir (fun dir ->
      (* Nest two levels — confirm mkdir -p semantics. *)
      let out_dir = Filename.concat dir "deep/nested/out" in
      let _result =
        Runner.run_and_write ~spec ~out_dir ~evaluator:_parabola_evaluator
      in
      assert_that (Sys_unix.is_directory_exn out_dir) (equal_to true))

let test_determinism_same_seed_byte_identical_log _ =
  (* CP4: pin the documented determinism property. Two runs with the same
     seed produce byte-identical bo_log.csv. *)
  let spec = _parabola_spec ~total_budget:15 ~seed:7 in
  let read_log dir =
    let out_dir = Filename.concat dir "out" in
    let _result =
      Runner.run_and_write ~spec ~out_dir ~evaluator:_parabola_evaluator
    in
    In_channel.read_all (Filename.concat out_dir "bo_log.csv")
  in
  _with_temp_dir (fun dir1 ->
      _with_temp_dir (fun dir2 ->
          let log1 = read_log dir1 in
          let log2 = read_log dir2 in
          assert_that log1 (equal_to log2)))

(* ---------- evaluator cache-miss guard ---------- *)

let test_evaluator_unknown_scenario_raises _ =
  (* CP4 — pins the documented guard at bayesian_runner_evaluator.mli:39
     ("looks up each scenario path in [scenarios_by_path] (raises [Failure]
     on miss)"). The miss path returns before any backtest is invoked, so an
     empty cache + a known-unknown key suffices. *)
  let scenarios_by_path = Hashtbl.create (module String) in
  let evaluator =
    Evaluator.build ~fixtures_root:"/unused"
      ~scenarios:[ "path/to/missing.sexp" ] ~scenarios_by_path
      ~objective:GS.Sharpe
  in
  let raised =
    try
      let _ = evaluator ~parameters:[ ("x", 1.0) ] in
      false
    with Failure msg ->
      String.is_substring msg ~substring:"unknown scenario path"
  in
  assert_that raised (equal_to true)

let suite =
  "Tuner_bin.Bayesian_runner"
  >::: [
         "Spec.load: simple spec parses" >:: test_load_simple_spec_parses;
         "Spec.load: UCB + Composite parses"
         >:: test_load_ucb_acquisition_and_composite_objective_parses;
         "Spec.load: malformed file raises Failure"
         >:: test_load_malformed_raises;
         "Spec.to_grid_objective: simple variants round-trip"
         >:: test_to_grid_objective_simple_variants;
         "Spec.to_acquisition: round-trips" >:: test_to_acquisition_round_trips;
         "Spec.to_bo_config: propagates fields"
         >:: test_to_bo_config_propagates_fields;
         "Runner.run_and_write: emits three artefacts"
         >:: test_run_and_write_emits_three_artefacts;
         "Runner.run_and_write: converges on 1D parabola"
         >:: test_run_and_write_converges_on_parabola;
         "Runner.run_and_write: creates missing out-dir tree"
         >:: test_run_and_write_creates_missing_out_dir;
         "Runner.run_and_write: determinism (same seed -> identical log)"
         >:: test_determinism_same_seed_byte_identical_log;
         "Evaluator.build: unknown scenario path raises Failure"
         >:: test_evaluator_unknown_scenario_raises;
       ]

let () = run_test_tt_main suite
