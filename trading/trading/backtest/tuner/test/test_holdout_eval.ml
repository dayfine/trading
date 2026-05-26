(** Unit tests for {!Tuner_bin.Holdout_eval}. Exercises the pure pairing,
    verdict-classification, and markdown-rendering helpers against synthetic
    {!Walk_forward.Walk_forward_types.fold_actual} lists.

    The CLI wrapper ([holdout_eval_main.ml]) is not tested here — it is a thin
    arg-parser around these helpers + the production walk-forward executor;
    testing it would require a real backtest. *)

open OUnit2
open Core
open Matchers
module Holdout = Tuner_bin.Holdout_eval
module Wf_types = Walk_forward.Walk_forward_types

(* ---------- Builders ---------- *)

let _fold_actual ?(total_return_pct = 0.0) ?(calmar_ratio = 0.0)
    ?(cagr_pct = 0.0) ?(avg_holding_days = Float.nan) ~fold_name ~variant_label
    ~sharpe_ratio ~max_drawdown_pct () : Wf_types.fold_actual =
  {
    fold_name;
    variant_label;
    total_return_pct;
    sharpe_ratio;
    max_drawdown_pct;
    calmar_ratio;
    cagr_pct;
    avg_holding_days;
  }

(* ---------- classify_verdict ---------- *)

let test_classify_robust _ =
  assert_that
    (Holdout.classify_verdict ~mean_paired_sharpe_delta:0.20)
    (equal_to Holdout.Robust)

let test_classify_drops_at_threshold _ =
  (* exactly at the threshold counts as Drops (> hurdle is Robust) *)
  assert_that
    (Holdout.classify_verdict ~mean_paired_sharpe_delta:Holdout.robust_threshold)
    (equal_to Holdout.Drops)

let test_classify_drops_small_positive _ =
  assert_that
    (Holdout.classify_verdict ~mean_paired_sharpe_delta:0.02)
    (equal_to Holdout.Drops)

let test_classify_fails_negative _ =
  assert_that
    (Holdout.classify_verdict ~mean_paired_sharpe_delta:(-0.10))
    (equal_to Holdout.Fails)

let test_classify_nan_is_fails _ =
  assert_that
    (Holdout.classify_verdict ~mean_paired_sharpe_delta:Float.nan)
    (equal_to Holdout.Fails)

(* ---------- pair_fold_actuals ---------- *)

let _make_pair_fixture () =
  [
    _fold_actual ~fold_name:"fold-024" ~variant_label:"cell-E"
      ~sharpe_ratio:0.50 ~max_drawdown_pct:20.0 ();
    _fold_actual ~fold_name:"fold-025" ~variant_label:"cell-E"
      ~sharpe_ratio:0.80 ~max_drawdown_pct:15.0 ();
    _fold_actual ~fold_name:"fold-026" ~variant_label:"cell-E"
      ~sharpe_ratio:1.00 ~max_drawdown_pct:10.0 ();
    _fold_actual ~fold_name:"fold-027" ~variant_label:"cell-E"
      ~sharpe_ratio:0.60 ~max_drawdown_pct:18.0 ();
    _fold_actual ~fold_name:"fold-024" ~variant_label:"bo-iter-best"
      ~sharpe_ratio:0.70 ~max_drawdown_pct:17.0 ();
    _fold_actual ~fold_name:"fold-025" ~variant_label:"bo-iter-best"
      ~sharpe_ratio:0.85 ~max_drawdown_pct:12.0 ();
    _fold_actual ~fold_name:"fold-026" ~variant_label:"bo-iter-best"
      ~sharpe_ratio:1.20 ~max_drawdown_pct:8.0 ();
    _fold_actual ~fold_name:"fold-027" ~variant_label:"bo-iter-best"
      ~sharpe_ratio:0.50 ~max_drawdown_pct:22.0 ();
  ]

let test_pair_fold_actuals_returns_one_row_per_match _ =
  let fixture = _make_pair_fixture () in
  let rows =
    Holdout.pair_fold_actuals ~candidate_label:"bo-iter-best"
      ~baseline_label:"cell-E" ~fold_actuals:fixture
  in
  assert_that rows (size_is 4)

let test_pair_fold_actuals_computes_deltas _ =
  let fixture = _make_pair_fixture () in
  let rows =
    Holdout.pair_fold_actuals ~candidate_label:"bo-iter-best"
      ~baseline_label:"cell-E" ~fold_actuals:fixture
  in
  (* First row: fold-024, cand 0.70, base 0.50, Δ +0.20; cand DD 17, base DD 20, Δ -3 *)
  assert_that rows
    (elements_are
       [
         all_of
           [
             field
               (fun (r : Holdout.per_fold_row) -> r.fold_name)
               (equal_to "fold-024");
             field
               (fun (r : Holdout.per_fold_row) -> r.delta_sharpe)
               (float_equal 0.20);
             field
               (fun (r : Holdout.per_fold_row) -> r.delta_max_drawdown_pct)
               (float_equal (-3.0));
           ];
         field
           (fun (r : Holdout.per_fold_row) -> r.fold_name)
           (equal_to "fold-025");
         field
           (fun (r : Holdout.per_fold_row) -> r.fold_name)
           (equal_to "fold-026");
         field
           (fun (r : Holdout.per_fold_row) -> r.fold_name)
           (equal_to "fold-027");
       ])

let test_pair_fold_actuals_raises_on_missing_candidate _ =
  let fixture = _make_pair_fixture () in
  let f () =
    ignore
      (Holdout.pair_fold_actuals ~candidate_label:"missing-label"
         ~baseline_label:"cell-E" ~fold_actuals:fixture
        : Holdout.per_fold_row list)
  in
  try
    f ();
    assert_failure "expected Failure for missing candidate label"
  with Failure msg ->
    assert_that
      (String.is_substring msg ~substring:"no rows for candidate")
      (equal_to true)

let test_pair_fold_actuals_raises_on_disjoint_fold_names _ =
  let fixture =
    [
      _fold_actual ~fold_name:"fold-001" ~variant_label:"cell-E"
        ~sharpe_ratio:0.5 ~max_drawdown_pct:10.0 ();
      _fold_actual ~fold_name:"fold-002" ~variant_label:"bo-iter-best"
        ~sharpe_ratio:0.7 ~max_drawdown_pct:12.0 ();
    ]
  in
  let f () =
    ignore
      (Holdout.pair_fold_actuals ~candidate_label:"bo-iter-best"
         ~baseline_label:"cell-E" ~fold_actuals:fixture
        : Holdout.per_fold_row list)
  in
  try
    f ();
    assert_failure "expected Failure for disjoint folds"
  with Failure msg ->
    assert_that
      (String.is_substring msg ~substring:"no candidate fold_name matched")
      (equal_to true)

(* ---------- build_report ---------- *)

let test_build_report_robust_picks_strong_candidate _ =
  (* Candidate dominates baseline: mean ΔSharpe = (0.2 + 0.05 + 0.2 - 0.1) /
     4 = 0.0875 > 0.05 → Robust. *)
  let fixture = _make_pair_fixture () in
  let report =
    Holdout.build_report ~candidate_label:"bo-iter-best"
      ~baseline_label:"cell-E" ~holdout_folds:[ 25; 26; 27; 28 ]
      ~best_iteration_index:25 ~best_iteration_score:0.171 ~fold_actuals:fixture
  in
  assert_that report
    (all_of
       [
         field (fun (r : Holdout.report) -> r.verdict) (equal_to Holdout.Robust);
         field (fun (r : Holdout.report) -> r.rows) (size_is 4);
         field
           (fun (r : Holdout.report) -> r.best_iteration_index)
           (equal_to 25);
         field
           (fun (r : Holdout.report) -> r.mean_paired_sharpe_delta)
           (float_equal ~epsilon:1e-9 0.0875);
       ])

let test_build_report_drops_when_marginal _ =
  (* Two folds: ΔSharpe values (0.04, 0.02) — mean 0.03 ∈ (0, 0.05] → Drops. *)
  let fixture =
    [
      _fold_actual ~fold_name:"f-1" ~variant_label:"cell-E" ~sharpe_ratio:0.50
        ~max_drawdown_pct:10.0 ();
      _fold_actual ~fold_name:"f-2" ~variant_label:"cell-E" ~sharpe_ratio:0.60
        ~max_drawdown_pct:11.0 ();
      _fold_actual ~fold_name:"f-1" ~variant_label:"cand" ~sharpe_ratio:0.54
        ~max_drawdown_pct:9.0 ();
      _fold_actual ~fold_name:"f-2" ~variant_label:"cand" ~sharpe_ratio:0.62
        ~max_drawdown_pct:11.0 ();
    ]
  in
  let report =
    Holdout.build_report ~candidate_label:"cand" ~baseline_label:"cell-E"
      ~holdout_folds:[ 1; 2 ] ~best_iteration_index:0 ~best_iteration_score:0.05
      ~fold_actuals:fixture
  in
  assert_that report.verdict (equal_to Holdout.Drops)

let test_build_report_fails_on_negative_delta _ =
  let fixture =
    [
      _fold_actual ~fold_name:"f-1" ~variant_label:"cell-E" ~sharpe_ratio:0.50
        ~max_drawdown_pct:10.0 ();
      _fold_actual ~fold_name:"f-1" ~variant_label:"cand" ~sharpe_ratio:0.30
        ~max_drawdown_pct:15.0 ();
    ]
  in
  let report =
    Holdout.build_report ~candidate_label:"cand" ~baseline_label:"cell-E"
      ~holdout_folds:[ 1 ] ~best_iteration_index:0 ~best_iteration_score:(-0.1)
      ~fold_actuals:fixture
  in
  assert_that report.verdict (equal_to Holdout.Fails);
  assert_that report.mean_paired_sharpe_delta (float_equal (-0.20))

(* ---------- render_report ---------- *)

let test_render_report_contains_required_sections _ =
  let fixture = _make_pair_fixture () in
  let report =
    Holdout.build_report ~candidate_label:"bo-iter-best"
      ~baseline_label:"cell-E" ~holdout_folds:[ 25; 26; 27; 28 ]
      ~best_iteration_index:25 ~best_iteration_score:0.171 ~fold_actuals:fixture
  in
  let md =
    Holdout.render_report report ~checkpoint_path:"/tmp/ck.sexp"
      ~walk_forward_spec_path:"/tmp/wf.sexp" ~baseline_aggregate_path:None
      ~baseline_all_fold_mean_sharpe:None
      ~baseline_all_fold_mean_max_drawdown_pct:None
  in
  (* Required sections: title, candidate metadata, per-fold table header,
     each fold name, verdict. *)
  assert_that
    (List.for_all
       [
         "# Holdout-fold evaluation report";
         "## Candidate";
         "## Per-holdout-fold metrics";
         "| Fold | Cand Sharpe | Base Sharpe |";
         "`fold-024`";
         "`fold-027`";
         "**ROBUST**";
         "iter 25";
       ] ~f:(fun substring -> String.is_substring md ~substring))
    (equal_to true)

let test_render_report_includes_annotation_when_baseline_aggregate_supplied _ =
  let fixture = _make_pair_fixture () in
  let report =
    Holdout.build_report ~candidate_label:"bo-iter-best"
      ~baseline_label:"cell-E" ~holdout_folds:[ 25; 26; 27; 28 ]
      ~best_iteration_index:25 ~best_iteration_score:0.171 ~fold_actuals:fixture
  in
  let md =
    Holdout.render_report report ~checkpoint_path:"/tmp/ck.sexp"
      ~walk_forward_spec_path:"/tmp/wf.sexp"
      ~baseline_aggregate_path:(Some "/tmp/agg.sexp")
      ~baseline_all_fold_mean_sharpe:(Some 0.893)
      ~baseline_all_fold_mean_max_drawdown_pct:(Some 15.7)
  in
  assert_that
    (List.for_all
       [
         "All-fold baseline annotation";
         "Baseline aggregate: `/tmp/agg.sexp`";
         "0.8930";
         "15.7000";
       ] ~f:(fun substring -> String.is_substring md ~substring))
    (equal_to true)

let test_render_report_omits_annotation_when_none _ =
  let fixture = _make_pair_fixture () in
  let report =
    Holdout.build_report ~candidate_label:"bo-iter-best"
      ~baseline_label:"cell-E" ~holdout_folds:[ 25; 26; 27; 28 ]
      ~best_iteration_index:25 ~best_iteration_score:0.171 ~fold_actuals:fixture
  in
  let md =
    Holdout.render_report report ~checkpoint_path:"/tmp/ck.sexp"
      ~walk_forward_spec_path:"/tmp/wf.sexp" ~baseline_aggregate_path:None
      ~baseline_all_fold_mean_sharpe:None
      ~baseline_all_fold_mean_max_drawdown_pct:None
  in
  assert_that
    (String.is_substring md ~substring:"All-fold baseline annotation")
    (equal_to false)

let suite =
  "Tuner_bin.Holdout_eval"
  >::: [
         "classify Robust above threshold" >:: test_classify_robust;
         "classify Drops AT the threshold (strict-greater is Robust)"
         >:: test_classify_drops_at_threshold;
         "classify Drops on small positive Δ"
         >:: test_classify_drops_small_positive;
         "classify Fails on negative Δ" >:: test_classify_fails_negative;
         "classify Fails on NaN Δ" >:: test_classify_nan_is_fails;
         "pair_fold_actuals returns one row per matched fold"
         >:: test_pair_fold_actuals_returns_one_row_per_match;
         "pair_fold_actuals computes Δ Sharpe and Δ MaxDD"
         >:: test_pair_fold_actuals_computes_deltas;
         "pair_fold_actuals raises on missing candidate label"
         >:: test_pair_fold_actuals_raises_on_missing_candidate;
         "pair_fold_actuals raises on disjoint fold names"
         >:: test_pair_fold_actuals_raises_on_disjoint_fold_names;
         "build_report verdict Robust on strong candidate"
         >:: test_build_report_robust_picks_strong_candidate;
         "build_report verdict Drops on marginal candidate"
         >:: test_build_report_drops_when_marginal;
         "build_report verdict Fails on negative Δ"
         >:: test_build_report_fails_on_negative_delta;
         "render_report contains required sections"
         >:: test_render_report_contains_required_sections;
         "render_report includes baseline annotation when supplied"
         >:: test_render_report_includes_annotation_when_baseline_aggregate_supplied;
         "render_report omits annotation when not supplied"
         >:: test_render_report_omits_annotation_when_none;
       ]

let () = run_test_tt_main suite
