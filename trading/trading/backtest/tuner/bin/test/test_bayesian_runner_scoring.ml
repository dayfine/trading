(** Unit tests for {!Tuner_bin.Bayesian_runner_scoring}.

    The scorer is pure: input = two pre-computed walk-forward aggregates, output
    = float (or [Status.t] error on bad lookup). Tests construct synthetic
    {!Walk_forward.Walk_forward_types.aggregate} records by hand — no real
    walk-forward run, no backtest invocation. This keeps the test suite fast and
    the failure surface localised to the scoring formula itself.

    Coverage map (plan §7 PR-A):

    - Identity case: candidate == baseline → score = +mean_sharpe(baseline).
    - MaxDD hinge zero: candidate MaxDD ≤ baseline → no penalty.
    - MaxDD hinge linear: candidate MaxDD > baseline by Δpp → penalty =
      lambda_dd * Δ exactly.
    - Gate Pass / Fail boundary: same Sharpe/MaxDD, only verdict differs → score
      diff = -lambda_gate * gate_penalty_value = -10.0.
    - Missing-variant lookups in stability and verdicts return Status.Error.
    - Sharpe improvement: candidate Sharpe > baseline Sharpe → score strictly
      greater than baseline self-score.
    - Edge cases: zero-fold aggregate, exactly-at-baseline-MaxDD, exact
      gate-Pass at zero penalty, baseline label missing from baseline aggregate,
      candidate MaxDD < baseline (negative hinge clipped). *)

open OUnit2
open Core
open Matchers
module Scoring = Tuner_bin.Bayesian_runner_scoring
module Wf = Walk_forward.Walk_forward_types
module FG = Walk_forward.Fold_gate

(** Default objective used by every test in this module. PR-1 of the wire-spec
    plan ships the Sharpe-default branch only; existing tests must continue to
    pass byte-for-byte through this branch. *)
let _sharpe : Tuner.Grid_search.objective = Tuner.Grid_search.Sharpe

(* ---------- synthetic-aggregate builders ---------- *)

let _stats ?(stdev = Float.nan) ?(min = Float.nan) ?(max = Float.nan) ~mean () :
    Wf.per_metric_stats =
  { mean; stdev; min; max }

let _stability_record ~label ~sharpe_mean ~maxdd_mean : Wf.variant_stability =
  {
    variant_label = label;
    total_return_pct = _stats ~mean:0.0 ();
    sharpe_ratio = _stats ~mean:sharpe_mean ();
    max_drawdown_pct = _stats ~mean:maxdd_mean ();
    calmar_ratio = _stats ~mean:0.0 ();
    cagr_pct = _stats ~mean:Float.nan ();
  }

(** Build a synthetic aggregate with two variants and the requested verdict on
    the candidate. The baseline verdict is always [Pass] (one row in the
    [verdicts] list); the candidate verdict is the caller-supplied row. *)
let _make_aggregate ~baseline_label ~candidate_label ~baseline_sharpe
    ~baseline_maxdd ~candidate_sharpe ~candidate_maxdd ~candidate_verdict
    ?(fold_count = 3) () : Wf.aggregate =
  let baseline_stab =
    _stability_record ~label:baseline_label ~sharpe_mean:baseline_sharpe
      ~maxdd_mean:baseline_maxdd
  in
  let candidate_stab =
    _stability_record ~label:candidate_label ~sharpe_mean:candidate_sharpe
      ~maxdd_mean:candidate_maxdd
  in
  {
    fold_count;
    baseline_label;
    metric_label = "sharpe_ratio";
    stability = [ baseline_stab; candidate_stab ];
    sensitivity = [];
    verdicts = [ (candidate_label, candidate_verdict) ];
  }

let _pass_verdict ?(wins = 3) ?(n = 3) () : FG.verdict = Pass { wins; n }

let _fail_verdict ?(wins = 0) ?(n = 3) ?(worst_fold = "fold-001")
    ?(worst_gap = 0.5) ?(reason = "M-threshold miss") () : FG.verdict =
  Fail { wins; n; worst_fold; worst_gap; reason }

(* ---------- shared constants ---------- *)

let _candidate_label = "bo-iter-7"
let _baseline_label = "cell-E"
let _no_params : (string * float) list = []
let _epsilon = 1e-9

(* ---------- 1. Identity case ---------- *)

(** When candidate aggregate == baseline aggregate (same variant labels, same
    metrics, gate Pass), score = +mean_sharpe (since MaxDD hinge is 0.0 and gate
    penalty is 0.0). *)
let test_identity_candidate_equals_baseline _ =
  let agg =
    _make_aggregate ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:0.85
      ~baseline_maxdd:12.0 ~candidate_sharpe:0.85 ~candidate_maxdd:12.0
      ~candidate_verdict:(_pass_verdict ()) ()
  in
  let result =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:agg
      ~baseline_aggregate:agg ~objective:_sharpe
  in
  assert_that result (is_ok_and_holds (float_equal ~epsilon:_epsilon 0.85))

(* ---------- 2. MaxDD hinge zero (improvement) ---------- *)

(** Candidate MaxDD (10.0) < baseline MaxDD (15.0) → no penalty. Score equals
    +mean_sharpe(candidate). *)
let test_maxdd_hinge_zero_on_improvement _ =
  let candidate_agg =
    _make_aggregate ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:0.5
      ~baseline_maxdd:15.0 ~candidate_sharpe:1.2 ~candidate_maxdd:10.0
      ~candidate_verdict:(_pass_verdict ()) ()
  in
  let baseline_agg =
    _make_aggregate ~baseline_label:_baseline_label
      ~candidate_label:_baseline_label ~baseline_sharpe:0.5 ~baseline_maxdd:15.0
      ~candidate_sharpe:0.5 ~candidate_maxdd:15.0
      ~candidate_verdict:(_pass_verdict ()) ()
  in
  let result =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:candidate_agg
      ~baseline_aggregate:baseline_agg ~objective:_sharpe
  in
  assert_that result (is_ok_and_holds (float_equal ~epsilon:_epsilon 1.2))

(* ---------- 3. MaxDD hinge linear on excess ---------- *)

(** Candidate MaxDD = 20.0 vs baseline = 15.0 → Δ = 5.0pp; penalty = lambda_dd
    (0.10) * 5.0 = 0.5; score = +mean_sharpe (1.0) - 0.5 = 0.5. *)
let test_maxdd_hinge_linear_on_excess _ =
  let candidate_agg =
    _make_aggregate ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:0.5
      ~baseline_maxdd:15.0 ~candidate_sharpe:1.0 ~candidate_maxdd:20.0
      ~candidate_verdict:(_pass_verdict ()) ()
  in
  let baseline_agg =
    _make_aggregate ~baseline_label:_baseline_label
      ~candidate_label:_baseline_label ~baseline_sharpe:0.5 ~baseline_maxdd:15.0
      ~candidate_sharpe:0.5 ~candidate_maxdd:15.0
      ~candidate_verdict:(_pass_verdict ()) ()
  in
  let result =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:candidate_agg
      ~baseline_aggregate:baseline_agg ~objective:_sharpe
  in
  assert_that result (is_ok_and_holds (float_equal ~epsilon:_epsilon 0.5))

(* ---------- 4. Gate Pass / Fail boundary ---------- *)

(** Two candidates differ only in verdict. Score difference must equal exactly
    -lambda_gate * gate_penalty_value = -1.0 * 10.0 = -10.0. *)
let test_gate_pass_vs_fail_score_difference _ =
  let pass_agg =
    _make_aggregate ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:0.5
      ~baseline_maxdd:15.0 ~candidate_sharpe:0.9 ~candidate_maxdd:15.0
      ~candidate_verdict:(_pass_verdict ()) ()
  in
  let fail_agg =
    _make_aggregate ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:0.5
      ~baseline_maxdd:15.0 ~candidate_sharpe:0.9 ~candidate_maxdd:15.0
      ~candidate_verdict:(_fail_verdict ()) ()
  in
  let baseline_agg = pass_agg in
  let pass_result =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:pass_agg
      ~baseline_aggregate:baseline_agg ~objective:_sharpe
  in
  let fail_result =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:fail_agg
      ~baseline_aggregate:baseline_agg ~objective:_sharpe
  in
  match (pass_result, fail_result) with
  | Ok p, Ok f -> assert_that (p -. f) (float_equal ~epsilon:_epsilon 10.0)
  | _ ->
      assert_failure
        "expected both score_cell calls to succeed for pass/fail comparison"

(* ---------- 5. Synthetic Fail variant (fold-pair count mismatch) ---------- *)

(** Per walk_forward_report.mli:30-35, fold-pair count mismatch yields a Fail
    verdict. The scorer must treat it identically to a regular Fail (same
    penalty magnitude). *)
let test_synthetic_fail_treated_as_regular_fail _ =
  let synthetic_fail : FG.verdict =
    Fail
      {
        wins = 0;
        n = 3;
        worst_fold = "(none)";
        worst_gap = 0.0;
        reason = "fold-pair count mismatch (synthetic)";
      }
  in
  let regular_fail = _fail_verdict () in
  let make_agg verdict =
    _make_aggregate ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:0.5
      ~baseline_maxdd:15.0 ~candidate_sharpe:0.9 ~candidate_maxdd:15.0
      ~candidate_verdict:verdict ()
  in
  let synth_agg = make_agg synthetic_fail in
  let regular_agg = make_agg regular_fail in
  let baseline_agg =
    _make_aggregate ~baseline_label:_baseline_label
      ~candidate_label:_baseline_label ~baseline_sharpe:0.5 ~baseline_maxdd:15.0
      ~candidate_sharpe:0.5 ~candidate_maxdd:15.0
      ~candidate_verdict:(_pass_verdict ()) ()
  in
  let synth =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:synth_agg
      ~baseline_aggregate:baseline_agg ~objective:_sharpe
  in
  let regular =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:regular_agg
      ~baseline_aggregate:baseline_agg ~objective:_sharpe
  in
  match (synth, regular) with
  | Ok s, Ok r -> assert_that s (float_equal ~epsilon:_epsilon r)
  | _ -> assert_failure "expected both score_cell calls to succeed"

(* ---------- 6. Sharpe improvement ---------- *)

(** Candidate Sharpe (1.5) > baseline Sharpe (0.5), same MaxDD, both Pass →
    candidate score (1.5) > baseline self-score (0.5). *)
let test_sharpe_improvement_increases_score _ =
  let candidate_agg =
    _make_aggregate ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:0.5
      ~baseline_maxdd:15.0 ~candidate_sharpe:1.5 ~candidate_maxdd:15.0
      ~candidate_verdict:(_pass_verdict ()) ()
  in
  let baseline_agg =
    _make_aggregate ~baseline_label:_baseline_label
      ~candidate_label:_baseline_label ~baseline_sharpe:0.5 ~baseline_maxdd:15.0
      ~candidate_sharpe:0.5 ~candidate_maxdd:15.0
      ~candidate_verdict:(_pass_verdict ()) ()
  in
  let candidate_score =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:candidate_agg
      ~baseline_aggregate:baseline_agg ~objective:_sharpe
  in
  let baseline_score =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_baseline_label
      ~baseline_label:_baseline_label ~candidate_aggregate:baseline_agg
      ~baseline_aggregate:baseline_agg ~objective:_sharpe
  in
  match (candidate_score, baseline_score) with
  | Ok c, Ok b -> assert_that c (gt (module Float_ord) b)
  | _ -> assert_failure "expected both score_cell calls to succeed"

(* ---------- 7. Missing variant in stability ---------- *)

let test_missing_candidate_in_stability_returns_error _ =
  (* Build an aggregate whose stability does NOT contain the requested
     candidate label. *)
  let agg : Wf.aggregate =
    {
      fold_count = 3;
      baseline_label = _baseline_label;
      metric_label = "sharpe_ratio";
      stability =
        [
          _stability_record ~label:_baseline_label ~sharpe_mean:0.5
            ~maxdd_mean:15.0;
        ];
      sensitivity = [];
      verdicts = [ (_candidate_label, _pass_verdict ()) ];
    }
  in
  let result =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:agg
      ~baseline_aggregate:agg ~objective:_sharpe
  in
  assert_that result (is_error_with Status.NotFound)

(* ---------- 8. Missing variant in verdicts ---------- *)

let test_missing_candidate_in_verdicts_returns_error _ =
  let agg : Wf.aggregate =
    {
      fold_count = 3;
      baseline_label = _baseline_label;
      metric_label = "sharpe_ratio";
      stability =
        [
          _stability_record ~label:_baseline_label ~sharpe_mean:0.5
            ~maxdd_mean:15.0;
          _stability_record ~label:_candidate_label ~sharpe_mean:1.0
            ~maxdd_mean:15.0;
        ];
      sensitivity = [];
      (* No verdict for candidate_label. *)
      verdicts = [];
    }
  in
  let result =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:agg
      ~baseline_aggregate:agg ~objective:_sharpe
  in
  assert_that result (is_error_with Status.NotFound)

(* ---------- 9. Missing baseline in baseline_aggregate ---------- *)

let test_missing_baseline_in_baseline_aggregate_returns_error _ =
  let candidate_agg =
    _make_aggregate ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:0.5
      ~baseline_maxdd:15.0 ~candidate_sharpe:1.0 ~candidate_maxdd:15.0
      ~candidate_verdict:(_pass_verdict ()) ()
  in
  let baseline_agg : Wf.aggregate =
    {
      fold_count = 3;
      baseline_label = _baseline_label;
      metric_label = "sharpe_ratio";
      stability =
        [
          _stability_record ~label:"some-other-label" ~sharpe_mean:0.5
            ~maxdd_mean:15.0;
        ];
      sensitivity = [];
      verdicts = [];
    }
  in
  let result =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:candidate_agg
      ~baseline_aggregate:baseline_agg ~objective:_sharpe
  in
  assert_that result (is_error_with Status.NotFound)

(* ---------- 10. Zero-fold aggregate ---------- *)

let test_zero_fold_aggregate_returns_error _ =
  let agg =
    _make_aggregate ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:0.5
      ~baseline_maxdd:15.0 ~candidate_sharpe:1.0 ~candidate_maxdd:15.0
      ~candidate_verdict:(_pass_verdict ()) ~fold_count:0 ()
  in
  let result =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:agg
      ~baseline_aggregate:agg ~objective:_sharpe
  in
  assert_that result (is_error_with Status.Invalid_argument)

(* ---------- 11. Exactly at baseline MaxDD ---------- *)

(** Candidate MaxDD == baseline MaxDD → hinge = 0 (boundary). *)
let test_exactly_at_baseline_maxdd_zero_hinge _ =
  let baseline_maxdd = 18.0 in
  let candidate_agg =
    _make_aggregate ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:0.5 ~baseline_maxdd
      ~candidate_sharpe:0.8 ~candidate_maxdd:baseline_maxdd
      ~candidate_verdict:(_pass_verdict ()) ()
  in
  let baseline_agg =
    _make_aggregate ~baseline_label:_baseline_label
      ~candidate_label:_baseline_label ~baseline_sharpe:0.5 ~baseline_maxdd
      ~candidate_sharpe:0.5 ~candidate_maxdd:baseline_maxdd
      ~candidate_verdict:(_pass_verdict ()) ()
  in
  let result =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:candidate_agg
      ~baseline_aggregate:baseline_agg ~objective:_sharpe
  in
  (* No MaxDD penalty, no gate penalty → score = +0.8. *)
  assert_that result (is_ok_and_holds (float_equal ~epsilon:_epsilon 0.8))

(* ---------- 12. Negative-Sharpe candidate (Pass) ---------- *)

(** Candidate with negative Sharpe (e.g. -0.3), Pass verdict, identical MaxDD.
    Score = +(-0.3) = -0.3. Confirms sign-handling does not collapse. *)
let test_negative_sharpe_candidate_score_negative _ =
  let agg =
    _make_aggregate ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:0.0
      ~baseline_maxdd:10.0 ~candidate_sharpe:(-0.3) ~candidate_maxdd:10.0
      ~candidate_verdict:(_pass_verdict ()) ()
  in
  let result =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:agg
      ~baseline_aggregate:agg ~objective:_sharpe
  in
  assert_that result (is_ok_and_holds (float_equal ~epsilon:_epsilon (-0.3)))

(* ---------- 13. Both penalties simultaneously ---------- *)

(** Candidate over-MaxDD by 4.0pp AND verdict Fail. Penalty = 0.10*4.0 +
    1.0*10.0 = 10.4; score = sharpe - 10.4. *)
let test_both_maxdd_and_gate_penalties_combine _ =
  let candidate_agg =
    _make_aggregate ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:0.5
      ~baseline_maxdd:15.0 ~candidate_sharpe:1.0 ~candidate_maxdd:19.0
      ~candidate_verdict:(_fail_verdict ()) ()
  in
  let baseline_agg =
    _make_aggregate ~baseline_label:_baseline_label
      ~candidate_label:_baseline_label ~baseline_sharpe:0.5 ~baseline_maxdd:15.0
      ~candidate_sharpe:0.5 ~candidate_maxdd:15.0
      ~candidate_verdict:(_pass_verdict ()) ()
  in
  let result =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:candidate_agg
      ~baseline_aggregate:baseline_agg ~objective:_sharpe
  in
  (* Expected: -loss = -(-1.0 + 0.10*4.0 + 1.0*10.0) = -(9.4) = -9.4 *)
  assert_that result (is_ok_and_holds (float_equal ~epsilon:_epsilon (-9.4)))

(* ---------- 14. parameters argument does not affect score ---------- *)

(** Two calls with the same aggregates but different [~parameters] return
    identical scores. Pins the API contract that parameters are for logging
    only. *)
let test_parameters_do_not_affect_score _ =
  let agg =
    _make_aggregate ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:0.5
      ~baseline_maxdd:15.0 ~candidate_sharpe:0.9 ~candidate_maxdd:15.0
      ~candidate_verdict:(_pass_verdict ()) ()
  in
  let s1 =
    Scoring.score_cell
      ~parameters:[ ("x", 0.0); ("y", 0.0) ]
      ~candidate_label:_candidate_label ~baseline_label:_baseline_label
      ~candidate_aggregate:agg ~baseline_aggregate:agg ~objective:_sharpe
  in
  let s2 =
    Scoring.score_cell
      ~parameters:[ ("x", 99.0); ("y", -42.0); ("z", 1.5) ]
      ~candidate_label:_candidate_label ~baseline_label:_baseline_label
      ~candidate_aggregate:agg ~baseline_aggregate:agg ~objective:_sharpe
  in
  match (s1, s2) with
  | Ok a, Ok b -> assert_that a (float_equal ~epsilon:_epsilon b)
  | _ -> assert_failure "expected both score_cell calls to succeed"

(* ---------- 15. Non-Sharpe objectives return Status.Unimplemented ---------- *)

(** PR-1 of the wire-spec plan ships the Sharpe-default branch only; passing any
    other [objective] yields [Status.Unimplemented]. PR-2 will replace these
    stubs with the Composite-relative + single-metric-relative formulas and
    remove this assertion. *)
let test_non_sharpe_objective_returns_unimplemented _ =
  let agg =
    _make_aggregate ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:0.5
      ~baseline_maxdd:15.0 ~candidate_sharpe:0.9 ~candidate_maxdd:15.0
      ~candidate_verdict:(_pass_verdict ()) ()
  in
  let composite : Tuner.Grid_search.objective =
    Composite
      [
        (Trading_simulation_types.Metric_types.SharpeRatio, 0.5);
        (Trading_simulation_types.Metric_types.MaxDrawdown, -0.1);
      ]
  in
  let other_objectives : Tuner.Grid_search.objective list =
    [ composite; Calmar; TotalReturn; Concavity_coef ]
  in
  List.iter other_objectives ~f:(fun obj ->
      let result =
        Scoring.score_cell ~parameters:_no_params
          ~candidate_label:_candidate_label ~baseline_label:_baseline_label
          ~candidate_aggregate:agg ~baseline_aggregate:agg ~objective:obj
      in
      assert_that result (is_error_with Status.Unimplemented))

(* ---------- 16. Sharpe-branch helper is byte-identical to score_cell ---------- *)

(** Pins the contract that [score_cell ~objective:Sharpe] dispatches through
    [_score_sharpe_with_hinge] with no transformation. If a refactor breaks this
    byte-equivalence, the BO loop's posterior drifts silently — this test
    catches it. *)
let test_sharpe_branch_equals_helper _ =
  let agg =
    _make_aggregate ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:0.5
      ~baseline_maxdd:15.0 ~candidate_sharpe:1.0 ~candidate_maxdd:19.0
      ~candidate_verdict:(_fail_verdict ()) ()
  in
  let baseline_agg =
    _make_aggregate ~baseline_label:_baseline_label
      ~candidate_label:_baseline_label ~baseline_sharpe:0.5 ~baseline_maxdd:15.0
      ~candidate_sharpe:0.5 ~candidate_maxdd:15.0
      ~candidate_verdict:(_pass_verdict ()) ()
  in
  let candidate_stab =
    List.find_exn agg.stability ~f:(fun v ->
        String.equal v.variant_label _candidate_label)
  in
  let baseline_stab =
    List.find_exn baseline_agg.stability ~f:(fun v ->
        String.equal v.variant_label _baseline_label)
  in
  let direct =
    Scoring._score_sharpe_with_hinge ~candidate_stab ~baseline_stab
      ~gate_penalty:Scoring._gate_penalty_value
  in
  let routed =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:agg
      ~baseline_aggregate:baseline_agg ~objective:_sharpe
  in
  assert_that routed (is_ok_and_holds (float_equal ~epsilon:_epsilon direct))

(* ---------- 17. Hyperparameter constants are pinned ---------- *)

(** CP4 — pin the documented constants. If anyone changes a constant they must
    also change the test, which is the desired contract. *)
let test_hyperparameter_constants_pinned _ =
  assert_that Scoring._lambda_dd (float_equal ~epsilon:_epsilon 0.10);
  assert_that Scoring._gate_penalty_value (float_equal ~epsilon:_epsilon 10.0);
  assert_that Scoring._lambda_gate (float_equal ~epsilon:_epsilon 1.0);
  assert_that Scoring._degenerate_fold_floor_return_pct
    (float_equal ~epsilon:_epsilon (-50.0))

let suite =
  "Tuner_bin.Bayesian_runner_scoring"
  >::: [
         "identity: candidate==baseline → score = +mean_sharpe"
         >:: test_identity_candidate_equals_baseline;
         "MaxDD hinge: improvement → no penalty"
         >:: test_maxdd_hinge_zero_on_improvement;
         "MaxDD hinge: Δpp excess → linear penalty"
         >:: test_maxdd_hinge_linear_on_excess;
         "gate verdict: Pass vs Fail → score diff = -10.0"
         >:: test_gate_pass_vs_fail_score_difference;
         "synthetic Fail (fold-pair mismatch) ≡ regular Fail"
         >:: test_synthetic_fail_treated_as_regular_fail;
         "Sharpe improvement strictly raises score"
         >:: test_sharpe_improvement_increases_score;
         "missing candidate in stability → Status.NotFound"
         >:: test_missing_candidate_in_stability_returns_error;
         "missing candidate in verdicts → Status.NotFound"
         >:: test_missing_candidate_in_verdicts_returns_error;
         "missing baseline in baseline_aggregate → Status.NotFound"
         >:: test_missing_baseline_in_baseline_aggregate_returns_error;
         "zero-fold aggregate → Status.Invalid_argument"
         >:: test_zero_fold_aggregate_returns_error;
         "MaxDD exactly at baseline → zero hinge"
         >:: test_exactly_at_baseline_maxdd_zero_hinge;
         "negative-Sharpe candidate → negative score"
         >:: test_negative_sharpe_candidate_score_negative;
         "both MaxDD + gate penalties combine additively"
         >:: test_both_maxdd_and_gate_penalties_combine;
         "parameters argument does not affect score"
         >:: test_parameters_do_not_affect_score;
         "non-Sharpe objectives → Status.Unimplemented (PR-1)"
         >:: test_non_sharpe_objective_returns_unimplemented;
         "Sharpe branch == _score_sharpe_with_hinge helper"
         >:: test_sharpe_branch_equals_helper;
         "hyperparameter constants pinned"
         >:: test_hyperparameter_constants_pinned;
       ]

let () = run_test_tt_main suite
