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
module Out_dir_check = Tuner_bin.Bayesian_runner_out_dir_check
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
      assert_that spec.n_acquisition_candidates is_none;
      (* The simple fixture omits [holdout_folds]; [@sexp.option] parses
         the absence as [None]. *)
      assert_that spec.holdout_folds is_none)

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

(* ---------- int_keys: per-binding (int) marker + round-trip ---------- *)

(* Per `dev/notes/bayesian-11knob-int-knob-crash-2026-05-22.md`: BO samples
   int-typed knobs at continuous floats (e.g. 3.8004) which crash
   `int_of_sexp` downstream. The spec's `(int)` marker flags those knobs so
   the BO runner threads them through `Grid_search.cell_to_overrides`'s
   `?int_keys` parameter for rounding. *)

let _int_marker_spec_text =
  String.concat
    [
      "((bounds";
      "  ((screening.weights.rs (0.1 0.5))";
      "   (stage3_force_exit_config.hysteresis_weeks (1.0 8.0) (int))";
      "   (screening.weights.w_positive_rs (5.0 40.0) (int))))";
      " (acquisition Expected_improvement)";
      " (initial_random 5)";
      " (total_budget 30)";
      " (seed (17))";
      " (n_acquisition_candidates ())";
      " (objective Sharpe)";
      " (scenarios (\"path/to/bull.sexp\")))";
    ]
    ~sep:"\n"

let test_load_int_marker_per_binding _ =
  _with_temp_dir (fun dir ->
      let path = _write_spec_file dir _int_marker_spec_text in
      let spec = Spec.load path in
      assert_that spec
        (all_of
           [
             field
               (fun s -> s.Spec.bounds)
               (elements_are
                  [
                    equal_to ("screening.weights.rs", (0.1, 0.5));
                    equal_to
                      ("stage3_force_exit_config.hysteresis_weeks", (1.0, 8.0));
                    equal_to ("screening.weights.w_positive_rs", (5.0, 40.0));
                  ]);
             field
               (fun s -> s.Spec.int_keys)
               (elements_are
                  [
                    equal_to "stage3_force_exit_config.hysteresis_weeks";
                    equal_to "screening.weights.w_positive_rs";
                  ]);
           ]))

let test_load_no_int_marker_defaults_to_empty_int_keys _ =
  _with_temp_dir (fun dir ->
      let path = _write_spec_file dir _spec_text in
      let spec = Spec.load path in
      assert_that spec.int_keys (equal_to []))

(** Build a [Spec.t] record carrying the given [int_keys]. Used by the
    round-trip + merge-semantics tests below. *)
let _spec_record_with_int_keys int_keys : Spec.t =
  {
    bounds =
      [
        ("screening.weights.rs", (0.1, 0.5));
        ("stage3_force_exit_config.hysteresis_weeks", (1.0, 8.0));
        ("screening.weights.w_positive_rs", (5.0, 40.0));
      ];
    acquisition = Spec.Expected_improvement;
    initial_random = 5;
    total_budget = 30;
    seed = Some 17;
    n_acquisition_candidates = None;
    objective = Spec.Sharpe;
    scenarios = [ "path/to/bull.sexp" ];
    holdout_folds = None;
    sentinel_bounds = None;
    length_scales = None;
    early_stop = None;
    gate_penalty_value = None;
    int_keys;
  }

let test_int_keys_round_trip_non_empty _ =
  (* Round-trip [t -> sexp -> t] preserves a non-empty [int_keys]. The .mli
     pins [t_of_sexp ∘ sexp_of_t = id] for any [t] — checkpoint validation
     in the BO runner depends on this. The emitter writes per-binding
     [(int)] markers and drops the top-level [(int_keys ...)] field; the
     parser re-extracts them into [t.int_keys]. *)
  let original =
    _spec_record_with_int_keys
      [
        "stage3_force_exit_config.hysteresis_weeks";
        "screening.weights.w_positive_rs";
      ]
  in
  let round_tripped = Spec.t_of_sexp (Spec.sexp_of_t original) in
  assert_that round_tripped.int_keys
    (elements_are
       [
         equal_to "stage3_force_exit_config.hysteresis_weeks";
         equal_to "screening.weights.w_positive_rs";
       ])

let _int_marker_with_explicit_field_spec_text =
  (* Carries BOTH a top-level [(int_keys ...)] field AND per-binding [(int)]
     markers. Pins the merge semantics documented at
     bayesian_runner_spec.mli §int_keys and implemented in
     [_preprocess_spec_sexp] (explicit-first, then per-binding markers). *)
  String.concat
    [
      "((bounds";
      "  ((screening.weights.rs (0.1 0.5))";
      "   (stage3_force_exit_config.hysteresis_weeks (1.0 8.0) (int))";
      "   (screening.weights.w_positive_rs (5.0 40.0) (int))))";
      " (acquisition Expected_improvement)";
      " (initial_random 5)";
      " (total_budget 30)";
      " (seed (17))";
      " (n_acquisition_candidates ())";
      " (objective Sharpe)";
      " (scenarios (\"path/to/bull.sexp\"))";
      " (int_keys (laggard_rotation_config.hysteresis_weeks)))";
    ]
    ~sep:"\n"

let test_load_explicit_int_keys_field_merges_with_per_binding_markers _ =
  (* Per .mli: "explicit-first, per-binding markers appended". The merged
     order is the explicit field's contents followed by the per-binding
     marker keys in their bounds-list order. *)
  _with_temp_dir (fun dir ->
      let path =
        _write_spec_file dir _int_marker_with_explicit_field_spec_text
      in
      let spec = Spec.load path in
      assert_that spec.int_keys
        (elements_are
           [
             equal_to "laggard_rotation_config.hysteresis_weeks";
             equal_to "stage3_force_exit_config.hysteresis_weeks";
             equal_to "screening.weights.w_positive_rs";
           ]))

(** Build a spec sexp whose third [bounds] entry's trailing marker is
    [marker_text]. Used to pin that malformed markers (e.g. [(int extra)],
    [(int_alias)], bare atom [int]) are not silently treated as int-flags — they
    fall through [_is_int_marker]'s exact match and cause [Spec.load] to raise
    [Failure]. *)
let _malformed_marker_spec_text ~marker_text =
  String.concat
    [
      "((bounds";
      "  ((screening.weights.rs (0.1 0.5))";
      "   (screening.weights.w_positive_rs (5.0 40.0) " ^ marker_text ^ ")))";
      " (acquisition Expected_improvement)";
      " (initial_random 5)";
      " (total_budget 30)";
      " (seed (17))";
      " (n_acquisition_candidates ())";
      " (objective Sharpe)";
      " (scenarios (\"path/to/bull.sexp\")))";
    ]
    ~sep:"\n"

let _spec_load_raises_failure dir marker_text =
  let path = _write_spec_file dir (_malformed_marker_spec_text ~marker_text) in
  try
    let _ = Spec.load path in
    false
  with Failure msg -> String.is_substring msg ~substring:"failed to parse"

let test_load_malformed_int_marker_with_extra_atom_raises _ =
  (* [(int extra)] is a two-atom list — [_is_int_marker] requires exactly
     one atom, so the marker is not stripped. The 3-element binding then
     fails the derived (string * (float * float)) parser. *)
  _with_temp_dir (fun dir ->
      assert_that (_spec_load_raises_failure dir "(int extra)") (equal_to true))

let test_load_int_alias_marker_raises _ =
  (* [(int_alias)] is rejected because [_is_int_marker] checks
     [String.equal a "int"] exactly — typos do not silently parse. *)
  _with_temp_dir (fun dir ->
      assert_that (_spec_load_raises_failure dir "(int_alias)") (equal_to true))

let test_load_bare_int_atom_marker_raises _ =
  (* Bare atom [int] (not wrapped in parens) is a [Sexp.Atom], not a
     [Sexp.List] — fails [_is_int_marker]'s outer [List ...] pattern.
     Pins that the docstring example MUST use parenthesised [(int)]. *)
  _with_temp_dir (fun dir ->
      assert_that (_spec_load_raises_failure dir "int") (equal_to true))

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
      holdout_folds = None;
      sentinel_bounds = None;
      length_scales = None;
      early_stop = None;
      gate_penalty_value = None;
      int_keys = [];
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
    holdout_folds = None;
    sentinel_bounds = None;
    length_scales = None;
    early_stop = None;
    gate_penalty_value = None;
    int_keys = [];
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

(* ---------- PR-D: early-stop wiring ---------- *)

(** A flat evaluator: always returns the same scalar metric and an empty
    per-scenario metric set. Deterministically triggers the early-stop predicate
    after [initial_random + window] iterations because the running-best curve is
    exactly flat. *)
let _flat_evaluator : Runner.evaluator =
 fun ~parameters:_ ->
  let empty = Map.empty (module Metric_types.Metric_type) in
  (0.0, [ empty ])

let _flat_spec_with_early_stop ~window ~epsilon : Spec.t =
  {
    bounds = [ ("x", (0.0, 10.0)) ];
    acquisition = Spec.Expected_improvement;
    initial_random = 3;
    total_budget = 50;
    seed = Some 11;
    n_acquisition_candidates = None;
    objective = Spec.Sharpe;
    scenarios = [ "stub-scenario" ];
    holdout_folds = None;
    sentinel_bounds = None;
    length_scales = None;
    early_stop = Some (window, epsilon);
    gate_penalty_value = None;
    int_keys = [];
  }

let test_early_stop_fires_on_flat_objective _ =
  (* PR-D acceptance: a flat evaluator triggers early-stop deterministically.
     With initial_random=3 and window=5, the predicate fires once
     observations.length > 3 + 5 = 8 (the first iteration whose pre-suggest
     check sees a flat 5-iter trail past the random phase). The total budget
     is 50; an early-stop run terminates well before that. *)
  let spec = _flat_spec_with_early_stop ~window:5 ~epsilon:0.01 in
  _with_temp_dir (fun dir ->
      let out_dir = Filename.concat dir "out" in
      let result =
        Runner.run_and_write ~spec ~out_dir ~evaluator:_flat_evaluator
      in
      assert_that result
        (all_of
           [
             field
               (fun (r : Runner.result) -> r.stop_reason)
               (matching ~msg:"expected Early_stopped"
                  (function
                    | Runner.Early_stopped { iter } -> Some iter | _ -> None)
                  (gt (module Int_ord) 0));
             (* Length must be strictly less than the total_budget. *)
             field
               (fun (r : Runner.result) -> List.length r.observations)
               (lt (module Int_ord) 50);
           ]))

let test_early_stop_emits_stop_reason_line _ =
  (* The [convergence.md] writer appends the stop-reason as a stable greppable
     sexp tail line. PR-D: [(stop_reason early_stopped (iter <N>))]. *)
  let spec = _flat_spec_with_early_stop ~window:4 ~epsilon:0.001 in
  _with_temp_dir (fun dir ->
      let out_dir = Filename.concat dir "out" in
      let _result =
        Runner.run_and_write ~spec ~out_dir ~evaluator:_flat_evaluator
      in
      let conv_md =
        In_channel.read_all (Filename.concat out_dir "convergence.md")
      in
      assert_that
        (String.is_substring conv_md
           ~substring:"(stop_reason early_stopped (iter ")
        (equal_to true))

let test_no_early_stop_emits_budget_exhausted_line _ =
  (* PR-D: when [early_stop = None], the stop-reason line is
     [(stop_reason budget_exhausted)]. Pinned so downstream tooling can rely
     on the tag's presence regardless of early-stop being enabled. *)
  let spec = _parabola_spec ~total_budget:6 ~seed:5 in
  _with_temp_dir (fun dir ->
      let out_dir = Filename.concat dir "out" in
      let result =
        Runner.run_and_write ~spec ~out_dir ~evaluator:_parabola_evaluator
      in
      let conv_md =
        In_channel.read_all (Filename.concat out_dir "convergence.md")
      in
      assert_that result
        (all_of
           [
             field
               (fun (r : Runner.result) -> r.stop_reason)
               (equal_to Runner.Budget_exhausted);
             field
               (fun _ ->
                 String.is_substring conv_md
                   ~substring:"(stop_reason budget_exhausted)")
               (equal_to true);
           ]))

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

(* ---------- holdout_folds field (PR-B) ---------- *)

(** PR-B: pin the parsed shape of the optional [holdout_folds] field. The field
    uses [\@sexp.option] so absence in the sexp parses as [None]; presence
    parses as [Some [..]] (including the empty-list edge case). PR-C will thread
    the list into the walk-forward executor; PR-B is shape-only. *)

let _spec_with_holdout_text holdout_clause =
  String.concat
    [
      "((bounds (";
      "  (initial_stop_buffer (0.5 2.0))))";
      " (acquisition Expected_improvement)";
      " (initial_random 5)";
      " (total_budget 30)";
      " (seed (7))";
      " (n_acquisition_candidates ())";
      " (objective Sharpe)";
      " (scenarios ())";
      " ";
      holdout_clause;
      ")";
    ]
    ~sep:"\n"

let test_holdout_folds_present_parses_to_some _ =
  _with_temp_dir (fun dir ->
      let path =
        _write_spec_file dir
          (_spec_with_holdout_text "(holdout_folds (27 28 29 30))")
      in
      let spec = Spec.load path in
      assert_that spec.holdout_folds
        (is_some_and
           (elements_are [ equal_to 27; equal_to 28; equal_to 29; equal_to 30 ])))

let test_holdout_folds_empty_list_parses_to_some_empty _ =
  (* Edge case: a present-but-empty list is distinct from an omitted field
     under [\@sexp.option]: [(holdout_folds ())] parses to [Some []], while
     omission parses to [None]. Pinning both keeps PR-C honest when it adds
     a fold filter — an empty list should mean "explicitly no holdouts",
     not "default to all folds in-sample". *)
  _with_temp_dir (fun dir ->
      let path =
        _write_spec_file dir (_spec_with_holdout_text "(holdout_folds ())")
      in
      let spec = Spec.load path in
      assert_that spec.holdout_folds (is_some_and (size_is 0)))

let test_holdout_folds_omitted_parses_to_none _ =
  (* Already covered by [test_load_simple_spec_parses]; re-pin here as the
     primary holdout-folds contract so the file's intent is greppable. *)
  _with_temp_dir (fun dir ->
      let path = _write_spec_file dir _spec_text in
      let spec = Spec.load path in
      assert_that spec.holdout_folds is_none)

let _spec_record_with_holdout holdout : Spec.t =
  {
    bounds = [ ("initial_stop_buffer", (0.5, 2.0)) ];
    acquisition = Spec.Expected_improvement;
    initial_random = 5;
    total_budget = 30;
    seed = Some 7;
    n_acquisition_candidates = None;
    objective = Spec.Sharpe;
    scenarios = [];
    holdout_folds = holdout;
    sentinel_bounds = None;
    length_scales = None;
    early_stop = None;
    gate_penalty_value = None;
    int_keys = [];
  }

let test_holdout_folds_round_trip_none _ =
  (* Round-trip: [t -> sexp -> t] preserves [holdout_folds = None]. With
     [\@sexp.option], the serialised sexp omits the field entirely, and
     re-parsing yields [None] (not e.g. [Some []]). *)
  let original = _spec_record_with_holdout None in
  let round_tripped = Spec.t_of_sexp (Spec.sexp_of_t original) in
  assert_that round_tripped.holdout_folds is_none

let test_holdout_folds_round_trip_some _ =
  let original = _spec_record_with_holdout (Some [ 27; 28; 29; 30 ]) in
  let round_tripped = Spec.t_of_sexp (Spec.sexp_of_t original) in
  assert_that round_tripped.holdout_folds
    (is_some_and
       (elements_are [ equal_to 27; equal_to 28; equal_to 29; equal_to 30 ]))

let test_holdout_folds_round_trip_some_empty _ =
  let original = _spec_record_with_holdout (Some []) in
  let round_tripped = Spec.t_of_sexp (Spec.sexp_of_t original) in
  assert_that round_tripped.holdout_folds (is_some_and (size_is 0))

(* ---------- PR-D: sentinel_bounds encoding ---------- *)

let _spec_with_pr_d_text trailing_clause =
  String.concat
    [
      "((bounds (";
      "  (initial_stop_buffer (0.5 2.0))))";
      " (acquisition Expected_improvement)";
      " (initial_random 5)";
      " (total_budget 30)";
      " (seed (7))";
      " (n_acquisition_candidates ())";
      " (objective Sharpe)";
      " (scenarios ())";
      " ";
      trailing_clause;
      ")";
    ]
    ~sep:"\n"

let test_sentinel_bounds_parses_to_some _ =
  _with_temp_dir (fun dir ->
      let path =
        _write_spec_file dir
          (_spec_with_pr_d_text
             "(sentinel_bounds ((max_sector_exposure_pct (sentinel 0.10 \
              0.35))))")
      in
      let spec = Spec.load path in
      assert_that spec.sentinel_bounds
        (is_some_and
           (elements_are
              [
                equal_to
                  ( "max_sector_exposure_pct",
                    Spec.Sentinel { threshold = 0.10; upper = 0.35 } );
              ])))

let test_sentinel_bounds_omitted_parses_to_none _ =
  _with_temp_dir (fun dir ->
      let path = _write_spec_file dir _spec_text in
      let spec = Spec.load path in
      assert_that spec.sentinel_bounds is_none)

let test_sentinel_bounds_plain_form_also_parses _ =
  (* sentinel_bounds is a list of [(key, bound_spec)] — bound_spec admits both
     [Plain (lo, hi)] (the legacy shape) and [Sentinel { ... }] (PR-D). *)
  _with_temp_dir (fun dir ->
      let path =
        _write_spec_file dir
          (_spec_with_pr_d_text
             "(sentinel_bounds ((min_score_override (30.0 55.0))))")
      in
      let spec = Spec.load path in
      assert_that spec.sentinel_bounds
        (is_some_and
           (elements_are
              [ equal_to ("min_score_override", Spec.Plain (30.0, 55.0)) ])))

let test_sentinel_bound_spec_round_trip _ =
  let original : Spec.bound_spec =
    Spec.Sentinel { threshold = 0.10; upper = 0.35 }
  in
  let round_tripped =
    Spec.bound_spec_of_sexp (Spec.sexp_of_bound_spec original)
  in
  assert_that round_tripped
    (equal_to (Spec.Sentinel { threshold = 0.10; upper = 0.35 }))

let test_plain_bound_spec_round_trip _ =
  let original : Spec.bound_spec = Spec.Plain (0.5, 2.0) in
  let round_tripped =
    Spec.bound_spec_of_sexp (Spec.sexp_of_bound_spec original)
  in
  assert_that round_tripped (equal_to (Spec.Plain (0.5, 2.0)))

(* ---------- PR-D: plain_range + decode_sentinel_sample ---------- *)

let test_plain_range_for_plain_returns_input _ =
  assert_that (Spec.plain_range (Spec.Plain (0.5, 2.0))) (equal_to (0.5, 2.0))

let test_plain_range_for_sentinel_expands_below_threshold _ =
  (* For [Sentinel { threshold = 0.10; upper = 0.35 }], the expanded BO range
     is [(threshold - 0.25 * (upper - threshold), upper)] = (0.10 - 0.0625,
     0.35) = (0.0375, 0.35). *)
  let lo, hi =
    Spec.plain_range (Spec.Sentinel { threshold = 0.10; upper = 0.35 })
  in
  assert_that lo (float_equal 0.0375);
  assert_that hi (float_equal 0.35)

let test_decode_sentinel_sample_plain_always_some _ =
  assert_that
    (Spec.decode_sentinel_sample (Spec.Plain (0.5, 2.0)) 1.25)
    (is_some_and (float_equal 1.25))

let test_decode_sentinel_sample_below_threshold_is_none _ =
  assert_that
    (Spec.decode_sentinel_sample
       (Spec.Sentinel { threshold = 0.10; upper = 0.35 })
       0.05)
    is_none

let test_decode_sentinel_sample_at_or_above_threshold_is_some _ =
  assert_that
    (Spec.decode_sentinel_sample
       (Spec.Sentinel { threshold = 0.10; upper = 0.35 })
       0.20)
    (is_some_and (float_equal 0.20));
  (* Exactly equal to the threshold also decodes as [Some] (predicate is
     [sampled < threshold]). *)
  assert_that
    (Spec.decode_sentinel_sample
       (Spec.Sentinel { threshold = 0.10; upper = 0.35 })
       0.10)
    (is_some_and (float_equal 0.10))

(* ---------- PR-D: length_scales + early_stop spec fields ---------- *)

let test_length_scales_parses_to_some _ =
  _with_temp_dir (fun dir ->
      let path =
        _write_spec_file dir
          (_spec_with_pr_d_text "(length_scales (0.25 0.5 0.75))")
      in
      let spec = Spec.load path in
      assert_that spec.length_scales
        (is_some_and
           (elements_are
              [ float_equal 0.25; float_equal 0.5; float_equal 0.75 ])))

let test_length_scales_omitted_parses_to_none _ =
  _with_temp_dir (fun dir ->
      let path = _write_spec_file dir _spec_text in
      let spec = Spec.load path in
      assert_that spec.length_scales is_none)

let test_early_stop_parses_to_some _ =
  _with_temp_dir (fun dir ->
      let path =
        _write_spec_file dir (_spec_with_pr_d_text "(early_stop (20 0.02))")
      in
      let spec = Spec.load path in
      assert_that spec.early_stop
        (is_some_and (equal_to ((20, 0.02) : int * float))))

let test_early_stop_omitted_parses_to_none _ =
  _with_temp_dir (fun dir ->
      let path = _write_spec_file dir _spec_text in
      let spec = Spec.load path in
      assert_that spec.early_stop is_none)

let test_to_bo_config_propagates_pr_d_fields _ =
  let spec : Spec.t =
    {
      bounds = [ ("x", (0.0, 1.0)); ("y", (0.0, 1.0)) ];
      acquisition = Spec.Expected_improvement;
      initial_random = 5;
      total_budget = 30;
      seed = Some 7;
      n_acquisition_candidates = None;
      objective = Spec.Sharpe;
      scenarios = [];
      holdout_folds = None;
      sentinel_bounds = None;
      length_scales = Some [ 0.3; 0.4 ];
      early_stop = Some (15, 0.025);
      gate_penalty_value = None;
      int_keys = [];
    }
  in
  let config = Spec.to_bo_config spec in
  assert_that config
    (all_of
       [
         field
           (fun (c : Tuner.Bayesian_opt.config) -> c.length_scales)
           (is_some_and
              (matching ~msg:"expected 2-element length_scales array"
                 (fun a -> Some (Array.to_list a))
                 (elements_are [ float_equal 0.3; float_equal 0.4 ])));
         field
           (fun (c : Tuner.Bayesian_opt.config) -> c.early_stop_config)
           (is_some_and
              (all_of
                 [
                   field
                     (fun (e : Tuner.Bayesian_opt.early_stop_config) ->
                       e.window)
                     (equal_to 15);
                   field
                     (fun (e : Tuner.Bayesian_opt.early_stop_config) ->
                       e.epsilon)
                     (float_equal 0.025);
                 ]));
       ])

(* ---------- production fixture: bayesian-multi-param-2026-05-16.sexp ---- *)

(** Walk the cwd up until we hit a directory containing
    [trading/test_data/tuner/]. Mirrors the helper in [Walk_forward.test_spec];
    needed because [dune runtest]'s cwd is
    [_build/default/trading/backtest/tuner/bin/test]. *)
let _tuner_fixtures_root () =
  let target = "trading/test_data/tuner" in
  let rec walk_up dir tries_left =
    if tries_left = 0 then None
    else
      let candidate = Filename.concat dir target in
      if try Stdlib.Sys.is_directory candidate with _ -> false then
        Some candidate
      else
        let parent = Filename.dirname dir in
        if String.equal parent dir then None else walk_up parent (tries_left - 1)
  in
  walk_up (Stdlib.Sys.getcwd ()) 10

let _tuner_fixture_path name =
  match _tuner_fixtures_root () with
  | Some root -> Filename.concat root name
  | None ->
      OUnit2.assert_failure
        (sprintf "tuner fixtures dir not found from cwd %s"
           (Stdlib.Sys.getcwd ()))

let test_phase3_fixture_parses _ =
  (* PR-B acceptance criterion: the production Phase-3 BO spec sexp parses
     without error and pins the 11-knob curated surface + the (27 28 29 30)
     OOS holdout. Asserting on [List.length spec.bounds] guards against
     accidental knob churn. *)
  let spec =
    Spec.load (_tuner_fixture_path "bayesian-multi-param-2026-05-16.sexp")
  in
  assert_that spec
    (all_of
       [
         field (fun (s : Spec.t) -> s.bounds) (size_is 11);
         field
           (fun (s : Spec.t) -> s.acquisition)
           (equal_to Spec.Expected_improvement);
         field (fun (s : Spec.t) -> s.initial_random) (equal_to 25);
         field (fun (s : Spec.t) -> s.total_budget) (equal_to 100);
         field (fun (s : Spec.t) -> s.seed) (is_some_and (equal_to 2026));
         field
           (fun (s : Spec.t) -> s.holdout_folds)
           (is_some_and
              (elements_are
                 [ equal_to 27; equal_to 28; equal_to 29; equal_to 30 ]));
       ])

let test_phase3_fixture_bounds_cover_expected_tracks _ =
  (* The 11-knob curation is structured across four tracks. Asserting the
     full key list (in order) guards against silent drift between the plan
     and the fixture. *)
  let spec =
    Spec.load (_tuner_fixture_path "bayesian-multi-param-2026-05-16.sexp")
  in
  let keys = List.map spec.bounds ~f:fst in
  assert_that keys
    (elements_are
       [
         equal_to "initial_stop_buffer";
         equal_to "screening_config.candidate_params.initial_stop_pct";
         equal_to "screening_config.candidate_params.installed_stop_min_pct";
         equal_to "screening_config.candidate_params.entry_buffer_pct";
         equal_to "portfolio_config.max_position_pct_long";
         equal_to "portfolio_config.max_long_exposure_pct";
         equal_to "portfolio_config.risk_per_trade_pct";
         equal_to "stage3_force_exit_config.hysteresis_weeks";
         equal_to "laggard_rotation_config.hysteresis_weeks";
         equal_to "screening_config.weights.w_positive_rs";
         equal_to "screening_config.weights.w_strong_volume";
       ])

(* ---------- checkpoint / resume (2026-05-21) ---------- *)

(** Read every byte of a regular file as a single string. Used by checkpoint
    tests to assert byte-equality of artefacts between fresh and resumed runs.
*)
let _read_all path = In_channel.read_all path

let _artefact_paths out_dir =
  ( Filename.concat out_dir "bo_log.csv",
    Filename.concat out_dir "best.sexp",
    Filename.concat out_dir "convergence.md" )

(** A counting evaluator wrapper: records every parameter set passed to the
    underlying evaluator. Lets resume tests assert that a checkpoint already
    covering the budget triggers zero further evaluator calls. *)
let _counting_evaluator inner =
  let calls = ref 0 in
  let eval : Runner.evaluator =
   fun ~parameters ->
    incr calls;
    inner ~parameters
  in
  (eval, calls)

let test_resume_equivalent_to_full_run _ =
  (* Splitting a budget-20 run as 10 + 10 (with the second call resuming via
     the checkpoint) must produce byte-identical bo_log.csv, best.sexp, and
     convergence.md as a single budget-20 run from scratch. *)
  let final_spec = _parabola_spec ~total_budget:20 ~seed:31 in
  let partial_spec = _parabola_spec ~total_budget:10 ~seed:31 in
  _with_temp_dir (fun fresh_dir ->
      _with_temp_dir (fun resume_dir ->
          let fresh_out = Filename.concat fresh_dir "out" in
          let resume_out = Filename.concat resume_dir "out" in
          let _ =
            Runner.run_and_write ~spec:final_spec ~out_dir:fresh_out
              ~evaluator:_parabola_evaluator
          in
          let _ =
            Runner.run_and_write ~spec:partial_spec ~out_dir:resume_out
              ~evaluator:_parabola_evaluator
          in
          let _ =
            Runner.run_and_write ~spec:final_spec ~out_dir:resume_out
              ~evaluator:_parabola_evaluator
          in
          let fresh_log, fresh_best, fresh_conv = _artefact_paths fresh_out in
          let resume_log, resume_best, resume_conv =
            _artefact_paths resume_out
          in
          assert_that
            (_read_all fresh_log, _read_all fresh_best, _read_all fresh_conv)
            (equal_to
               ( _read_all resume_log,
                 _read_all resume_best,
                 _read_all resume_conv ))))

let test_checkpoint_file_written_per_iter _ =
  (* After a complete run, bo_checkpoint.sexp exists, parses as a sexp, and
     records every iteration. The internal sexp shape is private but the file
     itself must be parseable as a sexp so external tooling can at least
     introspect its presence + content. *)
  let spec = _parabola_spec ~total_budget:6 ~seed:11 in
  _with_temp_dir (fun dir ->
      let out_dir = Filename.concat dir "out" in
      let first_result =
        Runner.run_and_write ~spec ~out_dir ~evaluator:_parabola_evaluator
      in
      assert_that (List.length first_result.observations) (equal_to 6);
      let ck_path = Filename.concat out_dir "bo_checkpoint.sexp" in
      assert_that (Sys_unix.file_exists_exn ck_path) (equal_to true);
      let raised =
        try
          let _ = Sexp.load_sexp ck_path in
          false
        with _ -> true
      in
      assert_that raised (equal_to false))

let test_resume_at_full_budget_skips_evaluator _ =
  (* When the checkpoint already covers spec.total_budget iterations, a
     second run_and_write with the same spec must perform zero evaluator
     calls and just re-emit the final artefacts. *)
  let spec = _parabola_spec ~total_budget:8 ~seed:19 in
  _with_temp_dir (fun dir ->
      let out_dir = Filename.concat dir "out" in
      let first_eval, first_calls = _counting_evaluator _parabola_evaluator in
      let first_result =
        Runner.run_and_write ~spec ~out_dir ~evaluator:first_eval
      in
      assert_that (List.length first_result.observations) (equal_to 8);
      let calls_after_fresh = !first_calls in
      let second_eval, second_calls = _counting_evaluator _parabola_evaluator in
      let result = Runner.run_and_write ~spec ~out_dir ~evaluator:second_eval in
      assert_that
        (calls_after_fresh, !second_calls, List.length result.observations)
        (equal_to (8, 0, 8)))

let test_resume_with_changed_spec_raises _ =
  (* Tightening the bounds between runs must be refused: the BO state was
     produced under the original spec and any mid-run knob change invalidates
     the saved observations' interpretation. *)
  let original_spec = _parabola_spec ~total_budget:8 ~seed:23 in
  let changed_spec : Spec.t =
    { original_spec with bounds = [ ("x", (0.0, 5.0)) ] }
  in
  _with_temp_dir (fun dir ->
      let out_dir = Filename.concat dir "out" in
      let _ =
        Runner.run_and_write ~spec:original_spec ~out_dir
          ~evaluator:_parabola_evaluator
      in
      let raised =
        try
          let _ =
            Runner.run_and_write ~spec:changed_spec ~out_dir
              ~evaluator:_parabola_evaluator
          in
          false
        with Failure msg ->
          String.is_substring msg ~substring:"checkpoint spec mismatch"
      in
      assert_that raised (equal_to true))

let test_resume_with_wrong_schema_version_raises _ =
  (* A hand-crafted checkpoint sexp with the wrong schema_version must be
     refused with a clear Failure naming the version mismatch. *)
  let spec = _parabola_spec ~total_budget:6 ~seed:5 in
  _with_temp_dir (fun dir ->
      let out_dir = Filename.concat dir "out" in
      Core_unix.mkdir_p out_dir;
      let ck_path = Filename.concat out_dir "bo_checkpoint.sexp" in
      let spec_sexp = Sexp.to_string_hum (Spec.sexp_of_t spec) in
      Out_channel.write_all ck_path
        ~data:
          (sprintf "((schema_version 99) (spec %s) (iterations ()))" spec_sexp);
      let raised =
        try
          let _ =
            Runner.run_and_write ~spec ~out_dir ~evaluator:_parabola_evaluator
          in
          false
        with Failure msg ->
          String.is_substring msg ~substring:"checkpoint schema mismatch"
      in
      assert_that raised (equal_to true))

let test_missing_checkpoint_starts_fresh _ =
  (* Sanity-pin the legacy behaviour: with no bo_checkpoint.sexp in out_dir,
     run_and_write performs total_budget evaluator calls and writes a fresh
     checkpoint covering them. *)
  let spec = _parabola_spec ~total_budget:6 ~seed:5 in
  _with_temp_dir (fun dir ->
      let out_dir = Filename.concat dir "out" in
      let eval, calls = _counting_evaluator _parabola_evaluator in
      let result = Runner.run_and_write ~spec ~out_dir ~evaluator:eval in
      let ck_exists =
        Sys_unix.file_exists_exn (Filename.concat out_dir "bo_checkpoint.sexp")
      in
      assert_that
        (!calls, List.length result.observations, ck_exists)
        (equal_to (6, 6, true)))

(* ---------- Out_dir_check: --out-dir prefix guard ---------- *)

let _no_env (_ : string) : string option = None

let _override_env name =
  if String.equal name "BAYESIAN_RUNNER_ALLOW_NON_SWEEP_OUTPUT" then Some "1"
  else None

let _override_set_to_zero name =
  if String.equal name "BAYESIAN_RUNNER_ALLOW_NON_SWEEP_OUTPUT" then Some "0"
  else None

let test_out_dir_check_accepts_tmp_sweeps_path _ =
  assert_that
    (Out_dir_check.validate ~out_dir:"/tmp/sweeps/test-foo" ~env_lookup:_no_env
       ())
    is_ok

let test_out_dir_check_rejects_repo_path _ =
  assert_that
    (Out_dir_check.validate ~out_dir:"dev/experiments/grid-screening"
       ~env_lookup:_no_env ())
    is_error

let test_out_dir_check_rejects_other_tmp_paths _ =
  (* /tmp/foo (without the /sweeps/ segment) must still fail; the prefix is
     strict and intentionally excludes /tmp/scratch, /tmp/x, etc. *)
  assert_that
    (Out_dir_check.validate ~out_dir:"/tmp/foo/bar" ~env_lookup:_no_env ())
    is_error

let test_out_dir_check_rejects_tmp_sweeps_without_trailing_slash _ =
  (* "/tmp/sweeps" (no trailing slash) is a literal path, not a parent —
     and an output written there clobbers a sibling-style file. Strict
     prefix match (with the trailing slash) forces a subdirectory. *)
  assert_that
    (Out_dir_check.validate ~out_dir:"/tmp/sweeps" ~env_lookup:_no_env ())
    is_error

let test_out_dir_check_override_one_allows_bad_path _ =
  assert_that
    (Out_dir_check.validate ~out_dir:"dev/experiments/grid-screening"
       ~env_lookup:_override_env ())
    is_ok

let test_out_dir_check_override_set_to_zero_does_not_allow _ =
  (* Only "1" enables the override; "0" or any other value is treated as
     "not overridden". Prevents an accidental
     BAYESIAN_RUNNER_ALLOW_NON_SWEEP_OUTPUT=0 from silently disabling the
     check (which would be the worst possible failure mode). *)
  assert_that
    (Out_dir_check.validate ~out_dir:"dev/experiments/grid-screening"
       ~env_lookup:_override_set_to_zero ())
    is_error

let test_out_dir_check_error_message_names_override _ =
  (* Operators reading the error in CI logs need to see the override name
     so they can decide whether to set it (rather than guess). *)
  match
    Out_dir_check.validate ~out_dir:"dev/experiments/grid-screening"
      ~env_lookup:_no_env ()
  with
  | Ok () -> assert_failure "expected Error"
  | Error status ->
      let msg = Status.show status in
      assert_bool
        ("expected error message to mention \
          BAYESIAN_RUNNER_ALLOW_NON_SWEEP_OUTPUT, got: " ^ msg)
        (String.is_substring msg
           ~substring:"BAYESIAN_RUNNER_ALLOW_NON_SWEEP_OUTPUT")

let suite =
  "Tuner_bin.Bayesian_runner"
  >::: [
         "Spec.load: simple spec parses" >:: test_load_simple_spec_parses;
         "Spec.load: UCB + Composite parses"
         >:: test_load_ucb_acquisition_and_composite_objective_parses;
         "Spec.load: malformed file raises Failure"
         >:: test_load_malformed_raises;
         "Spec.load: (int) marker per binding -> int_keys populated"
         >:: test_load_int_marker_per_binding;
         "Spec.load: no (int) markers -> int_keys = []"
         >:: test_load_no_int_marker_defaults_to_empty_int_keys;
         "Spec round-trip: non-empty int_keys preserved"
         >:: test_int_keys_round_trip_non_empty;
         "Spec.load: explicit (int_keys ...) merges with per-binding markers"
         >:: test_load_explicit_int_keys_field_merges_with_per_binding_markers;
         "Spec.load: malformed (int extra) marker -> Failure"
         >:: test_load_malformed_int_marker_with_extra_atom_raises;
         "Spec.load: (int_alias) marker -> Failure"
         >:: test_load_int_alias_marker_raises;
         "Spec.load: bare int atom marker -> Failure"
         >:: test_load_bare_int_atom_marker_raises;
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
         "Spec.load: holdout_folds present -> Some [..]"
         >:: test_holdout_folds_present_parses_to_some;
         "Spec.load: holdout_folds () -> Some []"
         >:: test_holdout_folds_empty_list_parses_to_some_empty;
         "Spec.load: holdout_folds omitted -> None"
         >:: test_holdout_folds_omitted_parses_to_none;
         "Spec round-trip: holdout_folds = None"
         >:: test_holdout_folds_round_trip_none;
         "Spec round-trip: holdout_folds = Some [..]"
         >:: test_holdout_folds_round_trip_some;
         "Spec round-trip: holdout_folds = Some []"
         >:: test_holdout_folds_round_trip_some_empty;
         "Phase-3 fixture: bayesian-multi-param-2026-05-16.sexp parses"
         >:: test_phase3_fixture_parses;
         "Phase-3 fixture: 11 knobs in expected order"
         >:: test_phase3_fixture_bounds_cover_expected_tracks;
         "PR-D: Runner.run_and_write early-stop fires on flat objective"
         >:: test_early_stop_fires_on_flat_objective;
         "PR-D: Runner.run_and_write emits early_stopped stop_reason line"
         >:: test_early_stop_emits_stop_reason_line;
         "PR-D: Runner.run_and_write emits budget_exhausted stop_reason line"
         >:: test_no_early_stop_emits_budget_exhausted_line;
         "PR-D: Spec.load sentinel_bounds (sentinel form) -> Some"
         >:: test_sentinel_bounds_parses_to_some;
         "PR-D: Spec.load sentinel_bounds omitted -> None"
         >:: test_sentinel_bounds_omitted_parses_to_none;
         "PR-D: Spec.load sentinel_bounds (plain form) -> Some"
         >:: test_sentinel_bounds_plain_form_also_parses;
         "PR-D: bound_spec round-trip: Sentinel"
         >:: test_sentinel_bound_spec_round_trip;
         "PR-D: bound_spec round-trip: Plain"
         >:: test_plain_bound_spec_round_trip;
         "PR-D: plain_range for Plain returns input"
         >:: test_plain_range_for_plain_returns_input;
         "PR-D: plain_range for Sentinel expands below threshold"
         >:: test_plain_range_for_sentinel_expands_below_threshold;
         "PR-D: decode_sentinel_sample Plain always Some"
         >:: test_decode_sentinel_sample_plain_always_some;
         "PR-D: decode_sentinel_sample below threshold -> None"
         >:: test_decode_sentinel_sample_below_threshold_is_none;
         "PR-D: decode_sentinel_sample at/above threshold -> Some"
         >:: test_decode_sentinel_sample_at_or_above_threshold_is_some;
         "PR-D: Spec.load length_scales -> Some"
         >:: test_length_scales_parses_to_some;
         "PR-D: Spec.load length_scales omitted -> None"
         >:: test_length_scales_omitted_parses_to_none;
         "PR-D: Spec.load early_stop -> Some" >:: test_early_stop_parses_to_some;
         "PR-D: Spec.load early_stop omitted -> None"
         >:: test_early_stop_omitted_parses_to_none;
         "PR-D: to_bo_config propagates length_scales + early_stop"
         >:: test_to_bo_config_propagates_pr_d_fields;
         "checkpoint: resume after partial run produces identical artefacts"
         >:: test_resume_equivalent_to_full_run;
         "checkpoint: bo_checkpoint.sexp present + parseable after run"
         >:: test_checkpoint_file_written_per_iter;
         "checkpoint: resume at full budget skips evaluator"
         >:: test_resume_at_full_budget_skips_evaluator;
         "checkpoint: resume with changed spec raises Failure"
         >:: test_resume_with_changed_spec_raises;
         "checkpoint: wrong schema_version raises Failure"
         >:: test_resume_with_wrong_schema_version_raises;
         "checkpoint: missing checkpoint starts fresh"
         >:: test_missing_checkpoint_starts_fresh;
         "Out_dir_check accepts /tmp/sweeps/<name>"
         >:: test_out_dir_check_accepts_tmp_sweeps_path;
         "Out_dir_check rejects repo-relative path"
         >:: test_out_dir_check_rejects_repo_path;
         "Out_dir_check rejects other /tmp paths"
         >:: test_out_dir_check_rejects_other_tmp_paths;
         "Out_dir_check rejects /tmp/sweeps (no trailing slash)"
         >:: test_out_dir_check_rejects_tmp_sweeps_without_trailing_slash;
         "Out_dir_check override=1 allows bad path"
         >:: test_out_dir_check_override_one_allows_bad_path;
         "Out_dir_check override=0 does not disable check"
         >:: test_out_dir_check_override_set_to_zero_does_not_allow;
         "Out_dir_check error message names override env var"
         >:: test_out_dir_check_error_message_names_override;
       ]

let () = run_test_tt_main suite
