(** Unit tests for {!Tuner_bin.Bayesian_runner_scoring}.

    The scorer is pure: input = two pre-computed walk-forward aggregates, output
    = float (or [Status.t] error on bad lookup). Tests construct synthetic
    {!Walk_forward.Walk_forward_types.aggregate} records by hand — no real
    walk-forward run, no backtest invocation. This keeps the test suite fast and
    the failure surface localised to the scoring formula itself.

    Coverage map (plan §7 PR-A + wire-spec PR-2):

    Sharpe branch (PR-A):

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
      candidate MaxDD < baseline (negative hinge clipped).

    Composite + single-metric branches (wire-spec PR-2):

    - Composite identity (cand == base) → score = 0.0.
    - Composite ((SharpeRatio 1.0)) → 1.0·(cand_sharpe - base_sharpe).
    - Composite 3-term production weights → exact computed score.
    - Composite negative-weight penalises higher metric.
    - Composite drops unmapped metric (CVaR95) silently → v1 behaviour.
    - Composite gate Pass vs Fail score diff = -10.0.
    - Calmar / TotalReturn objectives: (Δmetric - hinge - gate).

    Composite AvgHoldingDays infra (P5 of hold-period-deep-dive-2026-05-19):

    - Composite ((AvgHoldingDays 0.10)) → 0.10·(cand_hold - base_hold).
    - Composite P5 4-term formula → exact computed score (regression). *)

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
    avg_holding_days = _stats ~mean:Float.nan ();
  }

(** Fuller builder that lets composite + single-metric-relative tests pin the
    Calmar / TotalReturn / CAGR / AvgHoldingDays columns. [_stability_record]
    above is kept intact so the existing 16 Sharpe-path tests remain
    byte-identical. *)
let _stability_full ?(avg_holding_days_mean = Float.nan) ~label ~sharpe_mean
    ~maxdd_mean ~calmar_mean ~total_return_mean () : Wf.variant_stability =
  {
    variant_label = label;
    total_return_pct = _stats ~mean:total_return_mean ();
    sharpe_ratio = _stats ~mean:sharpe_mean ();
    max_drawdown_pct = _stats ~mean:maxdd_mean ();
    calmar_ratio = _stats ~mean:calmar_mean ();
    cagr_pct = _stats ~mean:Float.nan ();
    avg_holding_days = _stats ~mean:avg_holding_days_mean ();
  }

(** Build a synthetic aggregate with full-column variants (Sharpe, MaxDD,
    Calmar, TotalReturn, optional AvgHoldingDays). Used by the Composite +
    single-metric-relative suite below.

    [?baseline_avg_hold] / [?candidate_avg_hold] default to [Float.nan] so
    existing tests (which don't touch the AvgHoldingDays column) are
    byte-identical through this builder. *)
let _make_aggregate_full ?(baseline_avg_hold = Float.nan)
    ?(candidate_avg_hold = Float.nan) ~baseline_label ~candidate_label
    ~baseline_sharpe ~baseline_maxdd ~baseline_calmar ~baseline_return
    ~candidate_sharpe ~candidate_maxdd ~candidate_calmar ~candidate_return
    ~candidate_verdict ?(fold_count = 3) () : Wf.aggregate =
  let baseline_stab =
    _stability_full ~avg_holding_days_mean:baseline_avg_hold
      ~label:baseline_label ~sharpe_mean:baseline_sharpe
      ~maxdd_mean:baseline_maxdd ~calmar_mean:baseline_calmar
      ~total_return_mean:baseline_return ()
  in
  let candidate_stab =
    _stability_full ~avg_holding_days_mean:candidate_avg_hold
      ~label:candidate_label ~sharpe_mean:candidate_sharpe
      ~maxdd_mean:candidate_maxdd ~calmar_mean:candidate_calmar
      ~total_return_mean:candidate_return ()
  in
  {
    fold_count;
    baseline_label;
    metric_label = "sharpe_ratio";
    stability = [ baseline_stab; candidate_stab ];
    sensitivity = [];
    verdicts = [ (candidate_label, candidate_verdict) ];
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

(** Assert that [f ()] raises a [Failure] whose message contains [substring].
    OUnit's [assert_raises] needs the exact exception payload, but
    [paired_delta] embeds dynamic context (fold counts, label dumps) in its
    Failure message — substring-match is the right contract. *)
let assert_raises_failure_containing (substring : string) (f : unit -> unit) :
    unit =
  match
    try
      f ();
      None
    with
    | Failure msg -> Some msg
    | _ as e -> assert_failure ("expected Failure, got: " ^ Exn.to_string e)
  with
  | None -> assert_failure "expected Failure, but f returned normally"
  | Some msg ->
      if String.is_substring msg ~substring then ()
      else
        assert_failure
          (Printf.sprintf "expected Failure with substring %S, got: %S"
             substring msg)

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

(* ---------- 15. Composite-identity case ---------- *)

(** Candidate == baseline under [Composite [...]] yields composite-delta of
    [0.0]; with Pass verdict the gate penalty is [0.0], so score = 0.0. Pins the
    relative-to-baseline contract from plan §1 Q2 (iii). *)
let test_composite_identity_returns_zero _ =
  let agg =
    _make_aggregate_full ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:1.2
      ~baseline_maxdd:12.0 ~baseline_calmar:1.8 ~baseline_return:25.0
      ~candidate_sharpe:1.2 ~candidate_maxdd:12.0 ~candidate_calmar:1.8
      ~candidate_return:25.0 ~candidate_verdict:(_pass_verdict ()) ()
  in
  let composite : Tuner.Grid_search.objective =
    Composite
      [
        (Trading_simulation_types.Metric_types.SharpeRatio, 0.40);
        (Trading_simulation_types.Metric_types.CalmarRatio, 0.30);
        (Trading_simulation_types.Metric_types.MaxDrawdown, -0.10);
      ]
  in
  let result =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:agg
      ~baseline_aggregate:agg ~objective:composite
  in
  assert_that result (is_ok_and_holds (float_equal ~epsilon:_epsilon 0.0))

(* ---------- 16. Composite single-weight reduces to a Sharpe delta ---------- *)

(** [Composite ((SharpeRatio 1.0))] reduces to
    [1.0 * (cand_sharpe - base_sharpe)] with no MaxDD penalty (the Composite
    branch omits the explicit hinge — risk discipline is encoded via the
    negative MaxDD weight in the Composite itself, not via an extra hinge). *)
let test_composite_sharpe_only_weight _ =
  let candidate_agg =
    _make_aggregate_full ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:0.5
      ~baseline_maxdd:15.0 ~baseline_calmar:0.8 ~baseline_return:10.0
      ~candidate_sharpe:1.2 ~candidate_maxdd:20.0 ~candidate_calmar:0.6
      ~candidate_return:18.0 ~candidate_verdict:(_pass_verdict ()) ()
  in
  let baseline_agg =
    _make_aggregate_full ~baseline_label:_baseline_label
      ~candidate_label:_baseline_label ~baseline_sharpe:0.5 ~baseline_maxdd:15.0
      ~baseline_calmar:0.8 ~baseline_return:10.0 ~candidate_sharpe:0.5
      ~candidate_maxdd:15.0 ~candidate_calmar:0.8 ~candidate_return:10.0
      ~candidate_verdict:(_pass_verdict ()) ()
  in
  let composite : Tuner.Grid_search.objective =
    Composite [ (Trading_simulation_types.Metric_types.SharpeRatio, 1.0) ]
  in
  let result =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:candidate_agg
      ~baseline_aggregate:baseline_agg ~objective:composite
  in
  (* score = 1.0 * (1.2 - 0.5) - 0 (Pass) = 0.7 *)
  assert_that result (is_ok_and_holds (float_equal ~epsilon:_epsilon 0.7))

(* ---------- 17. Composite 3-term production formula ---------- *)

(** Exact computation against the v1 production weights
    [((SharpeRatio 0.40)(CalmarRatio 0.30)(MaxDrawdown -0.10))]:
    - candidate_sharpe = 1.2, baseline_sharpe = 0.6 → ΔSharpe = 0.6
    - candidate_calmar = 1.0, baseline_calmar = 0.5 → ΔCalmar = 0.5
    - candidate_maxdd = 18.0, baseline_maxdd = 12.0 → ΔMaxDD = 6.0 score =
      0.40·0.6 + 0.30·0.5 + (-0.10)·6.0 - 0 = 0.24 + 0.15 - 0.60 = -0.21 *)
let test_composite_three_term_production_formula _ =
  let candidate_agg =
    _make_aggregate_full ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:0.6
      ~baseline_maxdd:12.0 ~baseline_calmar:0.5 ~baseline_return:0.0
      ~candidate_sharpe:1.2 ~candidate_maxdd:18.0 ~candidate_calmar:1.0
      ~candidate_return:0.0 ~candidate_verdict:(_pass_verdict ()) ()
  in
  let baseline_agg =
    _make_aggregate_full ~baseline_label:_baseline_label
      ~candidate_label:_baseline_label ~baseline_sharpe:0.6 ~baseline_maxdd:12.0
      ~baseline_calmar:0.5 ~baseline_return:0.0 ~candidate_sharpe:0.6
      ~candidate_maxdd:12.0 ~candidate_calmar:0.5 ~candidate_return:0.0
      ~candidate_verdict:(_pass_verdict ()) ()
  in
  let composite : Tuner.Grid_search.objective =
    Composite
      [
        (Trading_simulation_types.Metric_types.SharpeRatio, 0.40);
        (Trading_simulation_types.Metric_types.CalmarRatio, 0.30);
        (Trading_simulation_types.Metric_types.MaxDrawdown, -0.10);
      ]
  in
  let result =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:candidate_agg
      ~baseline_aggregate:baseline_agg ~objective:composite
  in
  assert_that result (is_ok_and_holds (float_equal ~epsilon:_epsilon (-0.21)))

(* ---------- 18. Composite: negative MaxDD weight penalises higher MaxDD ---------- *)

(** Sanity-check the negative-weight contract: when only MaxDrawdown carries a
    negative weight, a HIGHER candidate MaxDD must produce a LOWER score than a
    lower candidate MaxDD (with all else equal). *)
let test_composite_negative_weight_penalises_metric _ =
  let high_maxdd_agg =
    _make_aggregate_full ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:0.5
      ~baseline_maxdd:10.0 ~baseline_calmar:0.5 ~baseline_return:0.0
      ~candidate_sharpe:0.5 ~candidate_maxdd:20.0 ~candidate_calmar:0.5
      ~candidate_return:0.0 ~candidate_verdict:(_pass_verdict ()) ()
  in
  let low_maxdd_agg =
    _make_aggregate_full ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:0.5
      ~baseline_maxdd:10.0 ~baseline_calmar:0.5 ~baseline_return:0.0
      ~candidate_sharpe:0.5 ~candidate_maxdd:5.0 ~candidate_calmar:0.5
      ~candidate_return:0.0 ~candidate_verdict:(_pass_verdict ()) ()
  in
  let composite : Tuner.Grid_search.objective =
    Composite [ (Trading_simulation_types.Metric_types.MaxDrawdown, -0.10) ]
  in
  let high_result =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:high_maxdd_agg
      ~baseline_aggregate:high_maxdd_agg ~objective:composite
  in
  let low_result =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:low_maxdd_agg
      ~baseline_aggregate:low_maxdd_agg ~objective:composite
  in
  match (high_result, low_result) with
  | Ok h, Ok l -> assert_that l (gt (module Float_ord) h)
  | _ ->
      assert_failure
        "expected both score_cell calls to succeed for negative-weight \
         comparison"

(* ---------- 19. Composite drops unmapped metrics silently ---------- *)

(** [CVaR95] is not carried in [variant_stability]; under the v1 design it is
    silently dropped from the weighted sum. With weights
    [((CVaR95 -0.20)(SharpeRatio 1.0))], the score reduces to
    [1.0 * (cand_sharpe - base_sharpe)] — identical to the
    [test_composite_sharpe_only_weight] expected value. Documents the v1
    behaviour. *)
let test_composite_missing_metric_dropped_silently _ =
  let candidate_agg =
    _make_aggregate_full ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:0.5
      ~baseline_maxdd:15.0 ~baseline_calmar:0.5 ~baseline_return:0.0
      ~candidate_sharpe:1.2 ~candidate_maxdd:15.0 ~candidate_calmar:0.5
      ~candidate_return:0.0 ~candidate_verdict:(_pass_verdict ()) ()
  in
  let baseline_agg =
    _make_aggregate_full ~baseline_label:_baseline_label
      ~candidate_label:_baseline_label ~baseline_sharpe:0.5 ~baseline_maxdd:15.0
      ~baseline_calmar:0.5 ~baseline_return:0.0 ~candidate_sharpe:0.5
      ~candidate_maxdd:15.0 ~candidate_calmar:0.5 ~candidate_return:0.0
      ~candidate_verdict:(_pass_verdict ()) ()
  in
  let composite_with_cvar : Tuner.Grid_search.objective =
    Composite
      [
        (Trading_simulation_types.Metric_types.CVaR95, -0.20);
        (Trading_simulation_types.Metric_types.SharpeRatio, 1.0);
      ]
  in
  let result =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:candidate_agg
      ~baseline_aggregate:baseline_agg ~objective:composite_with_cvar
  in
  (* CVaR95 dropped; SharpeRatio kept; score = 1.0 * (1.2 - 0.5) = 0.7 *)
  assert_that result (is_ok_and_holds (float_equal ~epsilon:_epsilon 0.7))

(* ---------- 20. Composite + gate Pass vs Fail score diff ---------- *)

(** Composite scoring under Pass vs Fail with same metrics differs by exactly
    -lambda_gate * gate_penalty_value = -10.0 (analogous to the existing Sharpe
    gate test). *)
let test_composite_gate_fail_score_diff _ =
  let composite : Tuner.Grid_search.objective =
    Composite
      [
        (Trading_simulation_types.Metric_types.SharpeRatio, 0.40);
        (Trading_simulation_types.Metric_types.CalmarRatio, 0.30);
        (Trading_simulation_types.Metric_types.MaxDrawdown, -0.10);
      ]
  in
  let pass_agg =
    _make_aggregate_full ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:0.5
      ~baseline_maxdd:15.0 ~baseline_calmar:0.5 ~baseline_return:0.0
      ~candidate_sharpe:0.9 ~candidate_maxdd:15.0 ~candidate_calmar:0.7
      ~candidate_return:0.0 ~candidate_verdict:(_pass_verdict ()) ()
  in
  let fail_agg =
    _make_aggregate_full ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:0.5
      ~baseline_maxdd:15.0 ~baseline_calmar:0.5 ~baseline_return:0.0
      ~candidate_sharpe:0.9 ~candidate_maxdd:15.0 ~candidate_calmar:0.7
      ~candidate_return:0.0 ~candidate_verdict:(_fail_verdict ()) ()
  in
  let pass_result =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:pass_agg
      ~baseline_aggregate:pass_agg ~objective:composite
  in
  let fail_result =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:fail_agg
      ~baseline_aggregate:pass_agg ~objective:composite
  in
  match (pass_result, fail_result) with
  | Ok p, Ok f -> assert_that (p -. f) (float_equal ~epsilon:_epsilon 10.0)
  | _ ->
      assert_failure
        "expected both score_cell calls to succeed for composite pass/fail \
         comparison"

(* ---------- 21. Calmar objective: single-metric-relative formula ---------- *)

(** [Calmar] objective scores as
    [(cand_calmar - base_calmar) - lambda_dd * max(0, cand_maxdd - base_maxdd) -
     lambda_gate * gate_penalty]. With candidate_calmar=1.4,
    baseline_calmar=0.8, candidate_maxdd=20.0, baseline_maxdd=15.0, Pass: score
    = 0.6 - 0.10*5.0 - 0 = 0.1. *)
let test_calmar_objective_relative _ =
  let candidate_agg =
    _make_aggregate_full ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:0.5
      ~baseline_maxdd:15.0 ~baseline_calmar:0.8 ~baseline_return:0.0
      ~candidate_sharpe:0.5 ~candidate_maxdd:20.0 ~candidate_calmar:1.4
      ~candidate_return:0.0 ~candidate_verdict:(_pass_verdict ()) ()
  in
  let baseline_agg =
    _make_aggregate_full ~baseline_label:_baseline_label
      ~candidate_label:_baseline_label ~baseline_sharpe:0.5 ~baseline_maxdd:15.0
      ~baseline_calmar:0.8 ~baseline_return:0.0 ~candidate_sharpe:0.5
      ~candidate_maxdd:15.0 ~candidate_calmar:0.8 ~candidate_return:0.0
      ~candidate_verdict:(_pass_verdict ()) ()
  in
  let result =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:candidate_agg
      ~baseline_aggregate:baseline_agg ~objective:Tuner.Grid_search.Calmar
  in
  assert_that result (is_ok_and_holds (float_equal ~epsilon:_epsilon 0.1))

(* ---------- 22. TotalReturn objective: single-metric-relative formula ---------- *)

(** [TotalReturn] objective scores as
    [(cand_return - base_return) - hinge - gate]. candidate_return=30.0,
    baseline_return=20.0 (Δ=10.0), candidate_maxdd=15.0, baseline_maxdd=15.0
    (hinge=0), Fail: score = 10.0 - 0 - 1.0*10.0 = 0.0. *)
let test_total_return_objective_relative _ =
  let candidate_agg =
    _make_aggregate_full ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:0.5
      ~baseline_maxdd:15.0 ~baseline_calmar:0.0 ~baseline_return:20.0
      ~candidate_sharpe:0.5 ~candidate_maxdd:15.0 ~candidate_calmar:0.0
      ~candidate_return:30.0 ~candidate_verdict:(_fail_verdict ()) ()
  in
  let baseline_agg =
    _make_aggregate_full ~baseline_label:_baseline_label
      ~candidate_label:_baseline_label ~baseline_sharpe:0.5 ~baseline_maxdd:15.0
      ~baseline_calmar:0.0 ~baseline_return:20.0 ~candidate_sharpe:0.5
      ~candidate_maxdd:15.0 ~candidate_calmar:0.0 ~candidate_return:20.0
      ~candidate_verdict:(_pass_verdict ()) ()
  in
  let result =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:candidate_agg
      ~baseline_aggregate:baseline_agg ~objective:Tuner.Grid_search.TotalReturn
  in
  assert_that result (is_ok_and_holds (float_equal ~epsilon:_epsilon 0.0))

(* ---------- 23. Composite with AvgHoldingDays weight (P5) ---------- *)

(** P5 infra: encoding the hold-cadence reward as [(AvgHoldingDays w)] in a
    Composite. With baseline avg_hold = 12.0 days (current cell-E P50 ≈ 12d),
    candidate avg_hold = 30.0 days (Weinstein- target), w = 0.10, and a one-term
    Composite weight on AvgHoldingDays: score = 0.10 · (30.0 - 12.0) - 0 (Pass)
    = 1.8. *)
let test_composite_avg_holding_days_weight _ =
  let agg =
    _make_aggregate_full ~baseline_avg_hold:12.0 ~candidate_avg_hold:30.0
      ~baseline_label:_baseline_label ~candidate_label:_candidate_label
      ~baseline_sharpe:0.5 ~baseline_maxdd:15.0 ~baseline_calmar:0.8
      ~baseline_return:10.0 ~candidate_sharpe:0.5 ~candidate_maxdd:15.0
      ~candidate_calmar:0.8 ~candidate_return:10.0
      ~candidate_verdict:(_pass_verdict ()) ()
  in
  let composite : Tuner.Grid_search.objective =
    Composite [ (Trading_simulation_types.Metric_types.AvgHoldingDays, 0.10) ]
  in
  let result =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:agg
      ~baseline_aggregate:agg ~objective:composite
  in
  assert_that result (is_ok_and_holds (float_equal ~epsilon:_epsilon 1.8))

(* ---------- 24. Composite P5 production formula (4-term) ---------- *)

(** P5 infra: end-to-end exact computation against the shipped P5 weights
    [((SharpeRatio 0.50)(CalmarRatio 0.30)(MaxDrawdown -0.10) (AvgHoldingDays
     0.10))]:
    - ΔSharpe = 1.2 - 0.6 = 0.6 → +0.50 · 0.6 = +0.30
    - ΔCalmar = 1.0 - 0.5 = 0.5 → +0.30 · 0.5 = +0.15
    - ΔMaxDD = 18.0 - 12.0 = 6.0 → -0.10 · 6.0 = -0.60
    - ΔAvgHoldingDays = 25.0 - 12.0 = 13.0 → +0.10 · 13.0 = +1.30
    - sum = 0.30 + 0.15 - 0.60 + 1.30 = 1.15
    - gate penalty (Pass) = 0
    - score = 1.15 *)
let test_composite_p5_production_formula _ =
  let candidate_agg =
    _make_aggregate_full ~baseline_avg_hold:12.0 ~candidate_avg_hold:25.0
      ~baseline_label:_baseline_label ~candidate_label:_candidate_label
      ~baseline_sharpe:0.6 ~baseline_maxdd:12.0 ~baseline_calmar:0.5
      ~baseline_return:0.0 ~candidate_sharpe:1.2 ~candidate_maxdd:18.0
      ~candidate_calmar:1.0 ~candidate_return:0.0
      ~candidate_verdict:(_pass_verdict ()) ()
  in
  let baseline_agg =
    _make_aggregate_full ~baseline_avg_hold:12.0 ~candidate_avg_hold:12.0
      ~baseline_label:_baseline_label ~candidate_label:_baseline_label
      ~baseline_sharpe:0.6 ~baseline_maxdd:12.0 ~baseline_calmar:0.5
      ~baseline_return:0.0 ~candidate_sharpe:0.6 ~candidate_maxdd:12.0
      ~candidate_calmar:0.5 ~candidate_return:0.0
      ~candidate_verdict:(_pass_verdict ()) ()
  in
  let composite : Tuner.Grid_search.objective =
    Composite
      [
        (Trading_simulation_types.Metric_types.SharpeRatio, 0.50);
        (Trading_simulation_types.Metric_types.CalmarRatio, 0.30);
        (Trading_simulation_types.Metric_types.MaxDrawdown, -0.10);
        (Trading_simulation_types.Metric_types.AvgHoldingDays, 0.10);
      ]
  in
  let result =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:candidate_agg
      ~baseline_aggregate:baseline_agg ~objective:composite
  in
  assert_that result (is_ok_and_holds (float_equal ~epsilon:_epsilon 1.15))

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

(** [score_cell_with_penalty] with [gate_penalty_value=2.0] produces a
    pass-vs-fail score difference of exactly 2.0, not 10.0 (the legacy default).
    Pins the soft-gate use case for V3+ sweeps where the legacy 10.0 dominates
    the composite-metric signal. *)
let test_score_cell_with_penalty_soft_gate _ =
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
    Scoring.score_cell_with_penalty ~gate_penalty_value:2.0
      ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:pass_agg
      ~baseline_aggregate:baseline_agg ~objective:_sharpe
  in
  let fail_result =
    Scoring.score_cell_with_penalty ~gate_penalty_value:2.0
      ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:fail_agg
      ~baseline_aggregate:baseline_agg ~objective:_sharpe
  in
  match (pass_result, fail_result) with
  | Ok p, Ok f -> assert_that (p -. f) (float_equal ~epsilon:_epsilon 2.0)
  | _ ->
      assert_failure
        "expected both score_cell_with_penalty calls to succeed for pass/fail \
         comparison"

(** [score_cell] (no penalty override) must produce the same score as
    [score_cell_with_penalty ~gate_penalty_value:_gate_penalty_value]. Ensures
    the wrapper preserves the legacy contract byte-for-byte. *)
let test_score_cell_matches_with_penalty_at_default _ =
  let fail_agg =
    _make_aggregate ~baseline_label:_baseline_label
      ~candidate_label:_candidate_label ~baseline_sharpe:0.5
      ~baseline_maxdd:15.0 ~candidate_sharpe:0.9 ~candidate_maxdd:15.0
      ~candidate_verdict:(_fail_verdict ()) ()
  in
  let baseline_agg = fail_agg in
  let legacy =
    Scoring.score_cell ~parameters:_no_params ~candidate_label:_candidate_label
      ~baseline_label:_baseline_label ~candidate_aggregate:fail_agg
      ~baseline_aggregate:baseline_agg ~objective:_sharpe
  in
  let explicit =
    Scoring.score_cell_with_penalty
      ~gate_penalty_value:Scoring._gate_penalty_value ~parameters:_no_params
      ~candidate_label:_candidate_label ~baseline_label:_baseline_label
      ~candidate_aggregate:fail_agg ~baseline_aggregate:baseline_agg
      ~objective:_sharpe
  in
  match (legacy, explicit) with
  | Ok l, Ok e -> assert_that l (float_equal ~epsilon:_epsilon e)
  | _ ->
      assert_failure
        "expected both score_cell and score_cell_with_penalty to succeed"

(* ---------- Paired-Δ scoring (T1.3) ----------

   The paired-Δ primitive consumes per-fold actuals (not the cross-fold
   aggregate). Tests construct synthetic [Wf.fold_actual] lists directly —
   no walk-forward run, no aggregate. See plan
   [dev/plans/tuning-research-driven-program-v2-2026-05-25.md] §M1 T1.3. *)

(** Construct a synthetic [fold_actual]. Defaults are NaN for fields not pinned
    by the test (so accidental reads on the wrong metric branch fail loudly
    rather than silently substituting [0.0]). *)
let _fold_actual ?(variant_label = _candidate_label)
    ?(total_return_pct = Float.nan) ?(sharpe_ratio = Float.nan)
    ?(max_drawdown_pct = Float.nan) ?(calmar_ratio = Float.nan)
    ?(cagr_pct = Float.nan) ?(avg_holding_days = Float.nan) ~fold_name () :
    Wf.fold_actual =
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

(** When candidate == baseline, every Δ_i is 0.0 → mean = 0, stdev = 0,
    n_matched = fold_count. Pins the identity case from plan §M1 T1.3. *)
let test_paired_delta_identical_inputs _ =
  let actuals =
    [
      _fold_actual ~fold_name:"f0" ~sharpe_ratio:0.7 ();
      _fold_actual ~fold_name:"f1" ~sharpe_ratio:1.2 ();
      _fold_actual ~fold_name:"f2" ~sharpe_ratio:(-0.3) ();
    ]
  in
  let result =
    Scoring.paired_delta ~candidate_actuals:actuals ~baseline_actuals:actuals
      ~metric:`Sharpe
  in
  assert_that result
    (all_of
       [
         field
           (fun s -> s.Scoring.mean_delta)
           (float_equal ~epsilon:_epsilon 0.0);
         field
           (fun s -> s.Scoring.stdev_delta)
           (float_equal ~epsilon:_epsilon 0.0);
         field (fun s -> s.Scoring.n_matched) (equal_to 3);
       ])

(** Constant outperformance: candidate Sharpe = baseline + 0.5 on every fold →
    mean_delta = 0.5 exactly, stdev_delta = 0, n_matched = fold_count. This is
    the per-knob signal the BO loop will see; the test confirms it survives the
    matched aggregation. *)
let test_paired_delta_constant_outperformance _ =
  let baseline =
    [
      _fold_actual ~fold_name:"f0" ~sharpe_ratio:0.7 ();
      _fold_actual ~fold_name:"f1" ~sharpe_ratio:1.2 ();
      _fold_actual ~fold_name:"f2" ~sharpe_ratio:(-0.3) ();
    ]
  in
  let candidate =
    [
      _fold_actual ~fold_name:"f0" ~sharpe_ratio:1.2 ();
      _fold_actual ~fold_name:"f1" ~sharpe_ratio:1.7 ();
      _fold_actual ~fold_name:"f2" ~sharpe_ratio:0.2 ();
    ]
  in
  let result =
    Scoring.paired_delta ~candidate_actuals:candidate ~baseline_actuals:baseline
      ~metric:`Sharpe
  in
  assert_that result
    (all_of
       [
         field
           (fun s -> s.Scoring.mean_delta)
           (float_equal ~epsilon:_epsilon 0.5);
         field
           (fun s -> s.Scoring.stdev_delta)
           (float_equal ~epsilon:_epsilon 0.0);
         field (fun s -> s.Scoring.n_matched) (equal_to 3);
       ])

(** Partial overlap: candidate has [f0; f1; f2], baseline has [f0; f2; f3].
    Matched set = [f0; f2] → n_matched = 2; mean is over f0 + f2 only (f1
    dropped because no baseline pair, f3 dropped because no candidate pair).
    Pins matching-by-fold_name and the explicit drop semantics for
    unmatched-on-either-side folds. *)
let test_paired_delta_partial_match _ =
  let baseline =
    [
      _fold_actual ~fold_name:"f0" ~sharpe_ratio:0.5 ();
      _fold_actual ~fold_name:"f2" ~sharpe_ratio:1.0 ();
      _fold_actual ~fold_name:"f3" ~sharpe_ratio:99.0 () (* dropped *);
    ]
  in
  let candidate =
    [
      _fold_actual ~fold_name:"f0" ~sharpe_ratio:0.8 () (* Δ = +0.3 *);
      _fold_actual ~fold_name:"f1" ~sharpe_ratio:88.0 () (* dropped *);
      _fold_actual ~fold_name:"f2" ~sharpe_ratio:1.5 () (* Δ = +0.5 *);
    ]
  in
  let result =
    Scoring.paired_delta ~candidate_actuals:candidate ~baseline_actuals:baseline
      ~metric:`Sharpe
  in
  (* mean over [0.3; 0.5] = 0.4; stdev = sqrt(((0.3-0.4)^2 + (0.5-0.4)^2) / 1)
     = sqrt(0.02) ≈ 0.141421356 *)
  assert_that result
    (all_of
       [
         field
           (fun s -> s.Scoring.mean_delta)
           (float_equal ~epsilon:_epsilon 0.4);
         field
           (fun s -> s.Scoring.stdev_delta)
           (float_equal ~epsilon:_epsilon (Float.sqrt 0.02));
         field (fun s -> s.Scoring.n_matched) (equal_to 2);
       ])

(** Disjoint fold names → [Failure] raised. The function refuses to return
    [n_matched = 0] / [NaN] because a disjoint pair is a callsite bug (runs on
    different walk-forward specs); failing loudly surfaces it immediately rather
    than letting a meaningless score reach the BO loop. *)
let test_paired_delta_no_match_raises _ =
  let baseline =
    [
      _fold_actual ~fold_name:"a0" ~sharpe_ratio:0.5 ();
      _fold_actual ~fold_name:"a1" ~sharpe_ratio:1.0 ();
    ]
  in
  let candidate =
    [
      _fold_actual ~fold_name:"b0" ~sharpe_ratio:0.8 ();
      _fold_actual ~fold_name:"b1" ~sharpe_ratio:1.5 ();
    ]
  in
  let f () =
    let _ =
      Scoring.paired_delta ~candidate_actuals:candidate
        ~baseline_actuals:baseline ~metric:`Sharpe
    in
    ()
  in
  assert_raises_failure_containing
    "Bayesian_runner_scoring.paired_delta: no fold names matched" f

(** Discriminator dispatch: pin one alternate metric (`Total_return_pct`) to
    confirm the per-fold field selection is correct. The Sharpe-only tests above
    could pass even if the implementation always read [sharpe_ratio] — this test
    catches that bug. *)
let test_paired_delta_total_return_metric _ =
  let baseline =
    [
      _fold_actual ~fold_name:"f0" ~sharpe_ratio:0.5 ~total_return_pct:10.0 ();
      _fold_actual ~fold_name:"f1" ~sharpe_ratio:1.0 ~total_return_pct:20.0 ();
    ]
  in
  let candidate =
    [
      _fold_actual ~fold_name:"f0" ~sharpe_ratio:99.0 ~total_return_pct:15.0 ();
      _fold_actual ~fold_name:"f1" ~sharpe_ratio:99.0 ~total_return_pct:30.0 ();
    ]
  in
  let result =
    Scoring.paired_delta ~candidate_actuals:candidate ~baseline_actuals:baseline
      ~metric:`Total_return_pct
  in
  (* Δ_total_return = [5.0; 10.0]; mean = 7.5; the bogus sharpe_ratio = 99.0
     on candidates would corrupt this score if the dispatch were wrong. *)
  assert_that result
    (all_of
       [
         field
           (fun s -> s.Scoring.mean_delta)
           (float_equal ~epsilon:_epsilon 7.5);
         field (fun s -> s.Scoring.n_matched) (equal_to 2);
       ])

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
         "Sharpe branch == _score_sharpe_with_hinge helper"
         >:: test_sharpe_branch_equals_helper;
         "hyperparameter constants pinned"
         >:: test_hyperparameter_constants_pinned;
         "score_cell_with_penalty: soft gate (2.0) → diff = 2.0"
         >:: test_score_cell_with_penalty_soft_gate;
         "score_cell_with_penalty at default == legacy score_cell"
         >:: test_score_cell_matches_with_penalty_at_default;
         "Composite: identity (cand == base) → score = 0.0"
         >:: test_composite_identity_returns_zero;
         "Composite ((SharpeRatio 1.0)) → cand_sharpe - base_sharpe"
         >:: test_composite_sharpe_only_weight;
         "Composite 3-term production weights → exact computed score"
         >:: test_composite_three_term_production_formula;
         "Composite negative weight penalises higher metric"
         >:: test_composite_negative_weight_penalises_metric;
         "Composite drops unmapped metric (CVaR95) silently"
         >:: test_composite_missing_metric_dropped_silently;
         "Composite gate Pass vs Fail → score diff = -10.0"
         >:: test_composite_gate_fail_score_diff;
         "Calmar objective: (Δcalmar - hinge - gate)"
         >:: test_calmar_objective_relative;
         "TotalReturn objective: (Δreturn - hinge - gate)"
         >:: test_total_return_objective_relative;
         "Composite (AvgHoldingDays w): score = w · (cand_hold - base_hold)"
         >:: test_composite_avg_holding_days_weight;
         "Composite P5 production formula (4-term incl. AvgHoldingDays)"
         >:: test_composite_p5_production_formula;
         (* Paired-Δ (T1.3) *)
         "paired_delta: identical inputs → mean=0, stdev=0, n=fold_count"
         >:: test_paired_delta_identical_inputs;
         "paired_delta: constant outperformance → mean=Δ, stdev=0"
         >:: test_paired_delta_constant_outperformance;
         "paired_delta: partial fold-name overlap → n_matched=intersection"
         >:: test_paired_delta_partial_match;
         "paired_delta: disjoint fold names → Failure raised"
         >:: test_paired_delta_no_match_raises;
         "paired_delta: metric=Total_return_pct discriminator dispatches"
         >:: test_paired_delta_total_return_metric;
       ]

let () = run_test_tt_main suite
