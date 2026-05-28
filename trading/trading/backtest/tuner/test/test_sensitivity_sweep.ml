(** Unit tests for {!Tuner_bin.Sensitivity_sweep}. Exercises the pure
    perturbation-generation, scoring-row assembly, and markdown-rendering
    helpers — the CLI wrapper ([sensitivity_sweep_main.ml]) is not tested here,
    as it requires a real walk-forward executor. *)

open OUnit2
open Core
open Matchers
module Sweep = Tuner_bin.Sensitivity_sweep
module Wf_spec = Walk_forward.Spec
module Wf_runner = Walk_forward.Walk_forward_runner
module Wf_window = Walk_forward.Window_spec
module Wf_executor = Walk_forward.Walk_forward_executor
module Wf_types = Walk_forward.Walk_forward_types
module Scenario = Scenario_lib.Scenario

(* ---------- perturbation_pcts ---------- *)

let test_perturbation_pcts_are_four_in_order _ =
  assert_that Sweep.perturbation_pcts
    (elements_are
       [
         float_equal (-0.10);
         float_equal (-0.05);
         float_equal 0.05;
         float_equal 0.10;
       ])

(* ---------- generate_perturbations ---------- *)

let test_generate_one_knob_yields_four_rows _ =
  let perts =
    Sweep.generate_perturbations
      ~best_params:[ ("a", 1.0) ]
      ~bounds:[ ("a", (0.0, 2.0)) ]
  in
  assert_that perts (size_is 4)

let test_generate_three_knobs_yields_twelve_rows _ =
  let perts =
    Sweep.generate_perturbations
      ~best_params:[ ("a", 1.0); ("b", 1.0); ("c", 1.0) ]
      ~bounds:[ ("a", (0.0, 2.0)); ("b", (0.0, 2.0)); ("c", (0.0, 2.0)) ]
  in
  assert_that perts (size_is 12)

let test_generate_perturbed_value_arithmetic _ =
  (* best_value = 0.8, bounds (0.0, 2.0). Pcts -0.10, -0.05, +0.05, +0.10
     → 0.72, 0.76, 0.84, 0.88. None clipped. *)
  let perts =
    Sweep.generate_perturbations
      ~best_params:[ ("a", 0.8) ]
      ~bounds:[ ("a", (0.0, 2.0)) ]
  in
  assert_that perts
    (elements_are
       [
         all_of
           [
             field (fun (p : Sweep.perturbation) -> p.pct) (float_equal (-0.10));
             field
               (fun (p : Sweep.perturbation) -> p.perturbed_value)
               (float_equal ~epsilon:1e-9 0.72);
             field (fun (p : Sweep.perturbation) -> p.clipped) (equal_to false);
           ];
         all_of
           [
             field (fun (p : Sweep.perturbation) -> p.pct) (float_equal (-0.05));
             field
               (fun (p : Sweep.perturbation) -> p.perturbed_value)
               (float_equal ~epsilon:1e-9 0.76);
           ];
         all_of
           [
             field (fun (p : Sweep.perturbation) -> p.pct) (float_equal 0.05);
             field
               (fun (p : Sweep.perturbation) -> p.perturbed_value)
               (float_equal ~epsilon:1e-9 0.84);
           ];
         all_of
           [
             field (fun (p : Sweep.perturbation) -> p.pct) (float_equal 0.10);
             field
               (fun (p : Sweep.perturbation) -> p.perturbed_value)
               (float_equal ~epsilon:1e-9 0.88);
           ];
       ])

let test_generate_clipping_to_upper_bound _ =
  (* best_value = 1.95, +10% → 2.145 → clipped to 2.0 *)
  let perts =
    Sweep.generate_perturbations
      ~best_params:[ ("a", 1.95) ]
      ~bounds:[ ("a", (0.0, 2.0)) ]
  in
  let plus_ten =
    List.find_exn perts ~f:(fun (p : Sweep.perturbation) ->
        Float.equal p.pct 0.10)
  in
  assert_that plus_ten
    (all_of
       [
         field
           (fun (p : Sweep.perturbation) -> p.perturbed_value)
           (float_equal 2.0);
         field (fun (p : Sweep.perturbation) -> p.clipped) (equal_to true);
       ])

let test_generate_clipping_to_lower_bound _ =
  (* best_value = 0.06, -10% → 0.054 → clipped to 0.10 (lower bound) *)
  let perts =
    Sweep.generate_perturbations
      ~best_params:[ ("a", 0.06) ]
      ~bounds:[ ("a", (0.10, 1.0)) ]
  in
  let minus_ten =
    List.find_exn perts ~f:(fun (p : Sweep.perturbation) ->
        Float.equal p.pct (-0.10))
  in
  assert_that minus_ten
    (all_of
       [
         field
           (fun (p : Sweep.perturbation) -> p.perturbed_value)
           (float_equal 0.10);
         field (fun (p : Sweep.perturbation) -> p.clipped) (equal_to true);
       ])

let test_generate_replaces_only_the_target_knob _ =
  let perts =
    Sweep.generate_perturbations
      ~best_params:[ ("a", 1.0); ("b", 0.5); ("c", 0.3) ]
      ~bounds:[ ("a", (0.0, 2.0)); ("b", (0.0, 1.0)); ("c", (0.0, 1.0)) ]
  in
  (* Take the -10% perturbation on "b": b becomes 0.45, a stays 1.0, c stays 0.3. *)
  let b_pert =
    List.find_exn perts ~f:(fun (p : Sweep.perturbation) ->
        String.equal p.knob "b" && Float.equal p.pct (-0.10))
  in
  assert_that b_pert.parameters
    (elements_are
       [
         pair (equal_to "a") (float_equal 1.0);
         pair (equal_to "b") (float_equal ~epsilon:1e-9 0.45);
         pair (equal_to "c") (float_equal 0.3);
       ])

let test_generate_zero_knob_is_no_op _ =
  (* Pin the .mli claim: zero-valued knob (best_value = 0.0) → every
     perturbation yields perturbed_value = 0.0 because 0.0 * (1 + pct) = 0.0
     for every pct, and 0.0 is within bounds (0.0, 1.0) so clipped = false. *)
  let perts =
    Sweep.generate_perturbations
      ~best_params:[ ("a", 0.0) ]
      ~bounds:[ ("a", (0.0, 1.0)) ]
  in
  assert_that perts
    (elements_are
       [
         all_of
           [
             field (fun (p : Sweep.perturbation) -> p.knob) (equal_to "a");
             field (fun (p : Sweep.perturbation) -> p.pct) (float_equal (-0.10));
             field
               (fun (p : Sweep.perturbation) -> p.perturbed_value)
               (float_equal 0.0);
             field (fun (p : Sweep.perturbation) -> p.clipped) (equal_to false);
           ];
         all_of
           [
             field (fun (p : Sweep.perturbation) -> p.knob) (equal_to "a");
             field (fun (p : Sweep.perturbation) -> p.pct) (float_equal (-0.05));
             field
               (fun (p : Sweep.perturbation) -> p.perturbed_value)
               (float_equal 0.0);
             field (fun (p : Sweep.perturbation) -> p.clipped) (equal_to false);
           ];
         all_of
           [
             field (fun (p : Sweep.perturbation) -> p.knob) (equal_to "a");
             field (fun (p : Sweep.perturbation) -> p.pct) (float_equal 0.05);
             field
               (fun (p : Sweep.perturbation) -> p.perturbed_value)
               (float_equal 0.0);
             field (fun (p : Sweep.perturbation) -> p.clipped) (equal_to false);
           ];
         all_of
           [
             field (fun (p : Sweep.perturbation) -> p.knob) (equal_to "a");
             field (fun (p : Sweep.perturbation) -> p.pct) (float_equal 0.10);
             field
               (fun (p : Sweep.perturbation) -> p.perturbed_value)
               (float_equal 0.0);
             field (fun (p : Sweep.perturbation) -> p.clipped) (equal_to false);
           ];
       ])

let test_generate_drops_knob_missing_from_bounds _ =
  let perts =
    Sweep.generate_perturbations
      ~best_params:[ ("a", 1.0); ("unknown", 0.5) ]
      ~bounds:[ ("a", (0.0, 2.0)) ]
  in
  (* Only "a" survives; "unknown" silently dropped → 4 rows. *)
  assert_that perts (size_is 4);
  assert_that
    (List.for_all perts ~f:(fun (p : Sweep.perturbation) ->
         String.equal p.knob "a"))
    (equal_to true)

(* ---------- sensitivity_threshold ---------- *)

let test_threshold_returns_half_improvement _ =
  (* best 0.20, baseline 0.00 → improvement 0.20 → threshold 0.10 *)
  assert_that
    (Sweep.sensitivity_threshold ~best_score:0.20 ~baseline_score:0.0)
    (is_some_and (float_equal 0.10))

let test_threshold_none_when_best_not_above_baseline _ =
  assert_that
    (Sweep.sensitivity_threshold ~best_score:0.0 ~baseline_score:0.0)
    is_none;
  assert_that
    (Sweep.sensitivity_threshold ~best_score:(-0.1) ~baseline_score:0.0)
    is_none

(* ---------- build_rows ---------- *)

let _make_perturbation ~knob ~pct ~perturbed_value : Sweep.perturbation =
  {
    knob;
    pct;
    perturbed_value;
    clipped = false;
    parameters = [ (knob, perturbed_value) ];
  }

let test_build_rows_zips_perturbations_and_scores _ =
  let perts =
    [
      _make_perturbation ~knob:"a" ~pct:(-0.10) ~perturbed_value:0.9;
      _make_perturbation ~knob:"a" ~pct:0.10 ~perturbed_value:1.1;
    ]
  in
  let rows =
    Sweep.build_rows ~best_score:0.20 ~baseline_score:0.0 ~perturbations:perts
      ~scores:[ 0.18; 0.05 ]
  in
  assert_that rows
    (elements_are
       [
         all_of
           [
             field (fun (r : Sweep.scored_row) -> r.knob) (equal_to "a");
             field (fun (r : Sweep.scored_row) -> r.pct) (float_equal (-0.10));
             field (fun (r : Sweep.scored_row) -> r.score) (float_equal 0.18);
             field
               (fun (r : Sweep.scored_row) -> r.delta_vs_best)
               (float_equal ~epsilon:1e-9 (-0.02));
             field (fun (r : Sweep.scored_row) -> r.sensitive) (equal_to false);
           ];
         all_of
           [
             field (fun (r : Sweep.scored_row) -> r.score) (float_equal 0.05);
             (* threshold = 0.10; score 0.05 < 0.10 → sensitive *)
             field (fun (r : Sweep.scored_row) -> r.sensitive) (equal_to true);
           ];
       ])

let test_build_rows_length_mismatch_raises _ =
  let perts = [ _make_perturbation ~knob:"a" ~pct:0.10 ~perturbed_value:1.1 ] in
  let f () =
    ignore
      (Sweep.build_rows ~best_score:0.1 ~baseline_score:0.0 ~perturbations:perts
         ~scores:[ 0.1; 0.2 ]
        : Sweep.scored_row list)
  in
  try
    f ();
    assert_failure "expected Invalid_argument for length mismatch"
  with Invalid_argument msg ->
    assert_that
      (String.is_substring msg ~substring:"length mismatch")
      (equal_to true)

let test_build_rows_never_flags_sensitive_when_no_improvement _ =
  let perts = [ _make_perturbation ~knob:"a" ~pct:0.10 ~perturbed_value:1.1 ] in
  let rows =
    Sweep.build_rows ~best_score:0.0 ~baseline_score:0.0 ~perturbations:perts
      ~scores:[ -10.0 ]
  in
  assert_that rows
    (elements_are
       [ field (fun (r : Sweep.scored_row) -> r.sensitive) (equal_to false) ])

(* ---------- render_report ---------- *)

let _sample_report () : Sweep.report =
  {
    candidate_label_prefix = "sensitivity";
    baseline_label = "cell-E";
    best_iteration_index = 25;
    best_score = 0.20;
    baseline_score = 0.0;
    rows =
      [
        {
          knob = "initial_stop_buffer";
          pct = -0.10;
          perturbed_value = 0.9;
          clipped = false;
          score = 0.18;
          delta_vs_best = -0.02;
          sensitive = false;
        };
        {
          knob = "initial_stop_buffer";
          pct = 0.10;
          perturbed_value = 1.1;
          clipped = false;
          score = 0.05;
          delta_vs_best = -0.15;
          sensitive = true;
        };
      ];
  }

let test_render_report_contains_required_sections _ =
  let r = _sample_report () in
  let md =
    Sweep.render_report r ~checkpoint_path:"/tmp/ck.sexp"
      ~walk_forward_spec_path:"/tmp/wf.sexp"
      ~baseline_aggregate_path:"/tmp/agg.sexp"
  in
  assert_that
    (List.for_all
       [
         "# Sensitivity-sweep report";
         "## Summary";
         "## Per-perturbation results";
         "| Knob | Pct | Perturbed value |";
         "`initial_stop_buffer`";
         "-10%";
         "+10%";
         "0.900000";
         "1.100000";
         "## Sensitivity summary";
         "**yes**";
       ] ~f:(fun substring -> String.is_substring md ~substring))
    (equal_to true)

let test_render_report_lists_each_sensitive_knob_uniquely _ =
  let r = _sample_report () in
  let md =
    Sweep.render_report r ~checkpoint_path:"/tmp/ck.sexp"
      ~walk_forward_spec_path:"/tmp/wf.sexp"
      ~baseline_aggregate_path:"/tmp/agg.sexp"
  in
  (* Only one sensitive knob, even though the same knob has two rows; the
     summary deduplicates. *)
  assert_that
    (String.is_substring md
       ~substring:"1 sensitive perturbation(s) across 1 knob(s)")
    (equal_to true)

let test_render_report_no_sensitive_says_robust _ =
  let robust_report : Sweep.report =
    {
      candidate_label_prefix = "sensitivity";
      baseline_label = "cell-E";
      best_iteration_index = 5;
      best_score = 0.20;
      baseline_score = 0.0;
      rows =
        [
          {
            knob = "a";
            pct = -0.05;
            perturbed_value = 0.95;
            clipped = false;
            score = 0.19;
            delta_vs_best = -0.01;
            sensitive = false;
          };
        ];
    }
  in
  let md =
    Sweep.render_report robust_report ~checkpoint_path:"/tmp/ck.sexp"
      ~walk_forward_spec_path:"/tmp/wf.sexp"
      ~baseline_aggregate_path:"/tmp/agg.sexp"
  in
  assert_that
    (String.is_substring md
       ~substring:"No perturbations crossed the sensitivity threshold")
    (equal_to true)

(* ---------- build_spec_with_baseline ---------- *)

let _date y m d = Date.create_exn ~y ~m:(Month.of_int_exn m) ~d

let _make_template ~baseline_label : Wf_spec.t =
  let folds : Wf_window.explicit_fold list =
    [
      {
        name = "fold-001";
        train_period = None;
        test_period =
          { start_date = _date 2020 1 1; end_date = _date 2020 1 31 };
      };
      {
        name = "fold-002";
        train_period = None;
        test_period =
          { start_date = _date 2020 2 1; end_date = _date 2020 2 28 };
      };
    ]
  in
  {
    base_scenario = "stub-base";
    window_spec = Wf_window.Explicit folds;
    (* Template carries only an arbitrary placeholder variant — the bug we're
       pinning is that [build_spec_with_baseline] must NOT preserve the
       template's variants verbatim; it must REPLACE them with [baseline;
       candidate]. A template-carried "should-not-survive" entry makes that
       check rigorous. *)
    variants = [ { label = "should-not-survive"; overrides = [] } ];
    baseline_label;
    gate = { metric = Sharpe; m = 1; n = 2; worst_delta = 1.0 };
  }

let test_build_spec_replaces_variants_with_baseline_and_candidate _ =
  let template = _make_template ~baseline_label:"cell-E" in
  let spec =
    Sweep.build_spec_with_baseline
      ~candidate_label:"sensitivity-knob-001-pct-+5" ~candidate_overrides:[]
      ~template
  in
  assert_that spec.variants
    (elements_are
       [
         all_of
           [
             field (fun (v : Wf_runner.variant) -> v.label) (equal_to "cell-E");
             field
               (fun (v : Wf_runner.variant) -> v.overrides)
               (equal_to ([] : Sexp.t list));
           ];
         all_of
           [
             field
               (fun (v : Wf_runner.variant) -> v.label)
               (equal_to "sensitivity-knob-001-pct-+5");
             field
               (fun (v : Wf_runner.variant) -> v.overrides)
               (equal_to ([] : Sexp.t list));
           ];
       ])

let test_build_spec_passes_through_candidate_overrides _ =
  let template = _make_template ~baseline_label:"cell-E" in
  let knob_override = Sexp.of_string "(knob_a 0.55)" in
  let spec =
    Sweep.build_spec_with_baseline ~candidate_label:"cand"
      ~candidate_overrides:[ knob_override ] ~template
  in
  match spec.variants with
  | [ baseline; candidate ] ->
      assert_that baseline.overrides (equal_to ([] : Sexp.t list));
      assert_that candidate.overrides (elements_are [ equal_to knob_override ])
  | _ -> assert_failure "expected exactly two variants"

let test_build_spec_uses_template_baseline_label _ =
  (* If the operator runs sensitivity sweep against a non-cell-E baseline (e.g.
     a different research stratum), the spec must propagate that label rather
     than hardcoding any particular value. *)
  let template = _make_template ~baseline_label:"strat-2026-05-stratum-3" in
  let spec =
    Sweep.build_spec_with_baseline ~candidate_label:"cand"
      ~candidate_overrides:[] ~template
  in
  match spec.variants with
  | baseline :: _ ->
      assert_that baseline.label (equal_to "strat-2026-05-stratum-3")
  | [] -> assert_failure "expected non-empty variants"

(* ---------- end-to-end executor regression: cell-E label must be present ----- *)

(** Deterministic stub runner — returns a fold_actual whose Sharpe is hashed
    from the scenario name so a label-mix-up would surface as a value mismatch,
    not a silent identical reading. Mirrors the shape
    [test_walk_forward_executor_parallel.ml] uses. *)
let _stub_runner (s : Scenario.t) : Wf_types.fold_actual =
  let h = String.hash s.name in
  let f = Float.of_int (h mod 1000) in
  {
    fold_name = "";
    variant_label = "";
    total_return_pct = f;
    sharpe_ratio = f /. 100.0;
    max_drawdown_pct = (f /. 10.0) +. 1.0;
    calmar_ratio = (f /. 50.0) +. 0.1;
    cagr_pct = (f /. 2.0) +. 0.5;
    avg_holding_days = (f /. 5.0) +. 7.0;
  }

let _stub_base () : Scenario.t =
  let expected : Scenario.expected =
    {
      total_return_pct = { min_f = -100.0; max_f = 500.0 };
      total_trades = { min_f = 0.0; max_f = 1000.0 };
      win_rate = { min_f = 0.0; max_f = 100.0 };
      sharpe_ratio = { min_f = -2.0; max_f = 3.0 };
      max_drawdown_pct = { min_f = 0.0; max_f = 90.0 };
      avg_holding_days = { min_f = 0.0; max_f = 500.0 };
      open_positions_value = None;
      unrealized_pnl = None;
      sortino_ratio_annualized = None;
      calmar_ratio = None;
      ulcer_index = None;
      wall_seconds = None;
    }
  in
  {
    name = "stub-base";
    description = "stub base for sensitivity-sweep regression test";
    period = { start_date = _date 2020 1 1; end_date = _date 2020 1 31 };
    universe_path = "universes/parity-7sym.sexp";
    config_overrides = [];
    strategy = Backtest.Strategy_choice.default;
    slippage_bps = None;
    cost_model = None;
    expected;
  }

let test_executor_with_built_spec_does_not_raise_on_baseline_label _ =
  (* Regression for the 2026-05-28 crash: sensitivity_sweep_main built
     single-variant specs containing only the candidate, so
     [Walk_forward_report.compute] raised:

       baseline_label "cell-E" not present in fold_actuals
       (labels: bo-iter-best)

     The fix is for [build_spec_with_baseline] to include the baseline
     variant. This test invokes [execute_spec] (via the stub runner so no
     real backtest runs) against a spec built by the helper and asserts:

     1. No exception is raised.
     2. The returned aggregate carries [baseline_label = "cell-E"] (matches
        what was requested via the template).
     3. The fold_actuals carry both the baseline and candidate labels —
        pre-fix this would have been candidate-only. *)
  let template = _make_template ~baseline_label:"cell-E" in
  let spec =
    Sweep.build_spec_with_baseline ~candidate_label:"bo-iter-best"
      ~candidate_overrides:[] ~template
  in
  let base = _stub_base () in
  let result =
    Wf_executor.execute_spec ~base ~spec
      ~fixtures_root:"/tmp/unused-by-stub-runner" ~run_one:_stub_runner ()
  in
  assert_that result.aggregate.baseline_label (equal_to "cell-E");
  let labels_in_actuals =
    List.map result.fold_actuals ~f:(fun fa -> fa.variant_label)
    |> List.dedup_and_sort ~compare:String.compare
  in
  assert_that labels_in_actuals
    (elements_are [ equal_to "bo-iter-best"; equal_to "cell-E" ])

let test_executor_produces_one_fold_per_variant_pair _ =
  (* Two folds × two variants = four fold_actual rows. Pins that the helper
     does not silently introduce extra (or zero) variants. *)
  let template = _make_template ~baseline_label:"cell-E" in
  let spec =
    Sweep.build_spec_with_baseline ~candidate_label:"bo-iter-best"
      ~candidate_overrides:[] ~template
  in
  let base = _stub_base () in
  let result =
    Wf_executor.execute_spec ~base ~spec
      ~fixtures_root:"/tmp/unused-by-stub-runner" ~run_one:_stub_runner ()
  in
  assert_that result.fold_actuals (size_is 4)

let suite =
  "Tuner_bin.Sensitivity_sweep"
  >::: [
         "perturbation_pcts is four values in order"
         >:: test_perturbation_pcts_are_four_in_order;
         "generate: one knob → four rows"
         >:: test_generate_one_knob_yields_four_rows;
         "generate: three knobs → twelve rows"
         >:: test_generate_three_knobs_yields_twelve_rows;
         "generate: perturbed values match v*(1+pct)"
         >:: test_generate_perturbed_value_arithmetic;
         "generate: upper bound clipping"
         >:: test_generate_clipping_to_upper_bound;
         "generate: lower bound clipping"
         >:: test_generate_clipping_to_lower_bound;
         "generate: only the target knob's value changes"
         >:: test_generate_replaces_only_the_target_knob;
         "generate: zero-valued knob produces no-op perturbations"
         >:: test_generate_zero_knob_is_no_op;
         "generate: knobs missing from bounds are dropped"
         >:: test_generate_drops_knob_missing_from_bounds;
         "threshold = half of improvement"
         >:: test_threshold_returns_half_improvement;
         "threshold is None when best ≤ baseline"
         >:: test_threshold_none_when_best_not_above_baseline;
         "build_rows zips perturbations and scores"
         >:: test_build_rows_zips_perturbations_and_scores;
         "build_rows raises Invalid_argument on length mismatch"
         >:: test_build_rows_length_mismatch_raises;
         "build_rows never flags sensitive when best ≤ baseline"
         >:: test_build_rows_never_flags_sensitive_when_no_improvement;
         "render_report contains required sections"
         >:: test_render_report_contains_required_sections;
         "render_report dedupes sensitive knobs in summary"
         >:: test_render_report_lists_each_sensitive_knob_uniquely;
         "render_report no-sensitive path says 'robust'"
         >:: test_render_report_no_sensitive_says_robust;
         "build_spec_with_baseline replaces template variants with baseline + \
          candidate"
         >:: test_build_spec_replaces_variants_with_baseline_and_candidate;
         "build_spec_with_baseline passes through candidate overrides"
         >:: test_build_spec_passes_through_candidate_overrides;
         "build_spec_with_baseline uses template's baseline_label verbatim"
         >:: test_build_spec_uses_template_baseline_label;
         "executor on built spec does not raise on baseline_label lookup \
          (regression for 2026-05-28 crash)"
         >:: test_executor_with_built_spec_does_not_raise_on_baseline_label;
         "executor on built spec produces one fold_actual per (variant, fold)"
         >:: test_executor_produces_one_fold_per_variant_pair;
       ]

let () = run_test_tt_main suite
