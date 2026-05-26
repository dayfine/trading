(** Post-sweep holdout-evaluation CLI for a finished BO sweep.

    After a Bayesian-optimisation sweep converges, this exe loads the
    checkpoint, identifies the {b best} observation (highest [metric]), and
    re-runs that single parameter assignment through the walk-forward executor
    on the {b holdout subset} of folds (as declared by the BO spec's
    [holdout_folds] field).

    The result is a markdown report that compares the candidate's per-fold
    Sharpe + MaxDD against a baseline (Cell-E with empty overrides) over the
    same holdout folds. The aggregate verdict is one of:

    - {b ROBUST} — mean per-fold paired Sharpe Δ > [+0.05]
    - {b DROPS} — mean per-fold paired Sharpe Δ in [0, +0.05]
    - {b FAILS} — mean per-fold paired Sharpe Δ < [0]

    {b Why "holdout" instead of "OOS validation"?} The existing
    {!Tuner_bin.Bayesian_runner_oos_validator} is invoked inline by the BO
    runner immediately after the sweep finishes and writes [oos_report.md]
    automatically. This module is a standalone post-sweep tool that an operator
    runs after the fact — typically when investigating a sweep that already
    finished, or when the [oos_report.md] is missing because the sweep was
    killed before the OOS step ran. The two tools share concept but not entry
    point; this one accepts an arbitrary [bo_checkpoint.sexp] + walk-forward
    spec.

    Plan: [dev/notes/next-session-priorities-2026-05-26.md] — post-v7-sweep
    analysis scripts.

    Usage:

    {v
      holdout_eval.exe --checkpoint <bo_checkpoint.sexp>
                       --walk-forward-spec <spec.sexp>
                       --out <report.md>
                       [--fixtures-root <path>]
                       [--baseline-aggregate <aggregate.sexp>]
                       [--parallel N]                (default 1, max 16)
    v}

    [--checkpoint] — path to [bo_checkpoint.sexp] produced by
    {!Tuner_bin.Bayesian_runner_runner.run_and_write}.

    [--walk-forward-spec] — path to the same {!Walk_forward.Spec.t} the BO ran
    against. Its [Window_spec.generate] expansion is filtered to the holdout
    subset.

    [--out] — destination path for the markdown report (overwritten on each
    run). The parent directory must exist.

    [--fixtures-root] — directory the walk-forward spec's [base_scenario]
    resolves against. Defaults to {!Scenario_lib.Fixtures_root.resolve}'s
    default.

    [--baseline-aggregate] — optional path to a pre-computed Cell-E
    [aggregate.sexp]. When supplied, the report adds an annotation row with the
    all-fold baseline mean Sharpe / MaxDD for cross-reference; the holdout
    verdict is unaffected (verdict is always computed against the in-run
    baseline variant). *)

(** {1 Pure helpers — exposed for the test suite} *)

(** Verdict computed from the mean per-fold paired Sharpe Δ. See module-level
    docstring for the thresholds. *)
type verdict = Robust | Drops | Fails [@@deriving sexp, show, eq]

val robust_threshold : float
(** Mean per-fold paired Sharpe Δ above which the verdict is {!Robust}. Pinned
    at [0.05] (one-sigma improvement on a typical Sharpe scale). *)

val classify_verdict : mean_paired_sharpe_delta:float -> verdict
(** [classify_verdict ~mean_paired_sharpe_delta] returns:

    - {!Robust} when [mean_paired_sharpe_delta > robust_threshold]
    - {!Drops} when [0.0 <= mean_paired_sharpe_delta <= robust_threshold]
    - {!Fails} when [mean_paired_sharpe_delta < 0.0]

    Total: returns a verdict for every finite float. [Float.nan] inputs are
    classified as {!Fails} (no improvement could be measured). *)

type per_fold_row = {
  fold_name : string;
  candidate_sharpe : float;
  baseline_sharpe : float;
  delta_sharpe : float;
  candidate_max_drawdown_pct : float;
  baseline_max_drawdown_pct : float;
  delta_max_drawdown_pct : float;
}
[@@deriving sexp, show, eq]
(** One row of the per-fold table in the markdown report. The deltas are
    [candidate - baseline]; for [delta_sharpe] higher is better, for
    [delta_max_drawdown_pct] lower is better. *)

type report = {
  candidate_label : string;
  baseline_label : string;
  holdout_folds : int list;
      (** 1-indexed fold positions evaluated (echoed from the BO spec). *)
  best_iteration_index : int;
      (** 0-based position of the best observation in
          [bo_checkpoint.iterations]. *)
  best_iteration_score : float;
      (** [metric] field of the best observation in the checkpoint. *)
  rows : per_fold_row list;
      (** Per-fold rows in fold-generation order (same order the walk-forward
          executor produces them). *)
  mean_paired_sharpe_delta : float;
      (** Arithmetic mean of [rows[i].delta_sharpe]. [Float.nan] when [rows] is
          empty. *)
  mean_paired_max_drawdown_delta : float;
      (** Arithmetic mean of [rows[i].delta_max_drawdown_pct]. [Float.nan] when
          [rows] is empty. *)
  verdict : verdict;
}
[@@deriving sexp, show, eq]
(** Structured holdout-evaluation result. Surfaced (rather than collapsing to a
    [verdict]) so the markdown renderer can quote per-fold detail and tests can
    pin every cell. *)

val pair_fold_actuals :
  candidate_label:string ->
  baseline_label:string ->
  fold_actuals:Walk_forward.Walk_forward_types.fold_actual list ->
  per_fold_row list
(** [pair_fold_actuals ~candidate_label ~baseline_label ~fold_actuals]
    partitions [fold_actuals] by [variant_label], matches candidate ↔ baseline
    rows by [fold_name], and returns one {!per_fold_row} per matched fold in the
    order candidate rows appear in [fold_actuals].

    Raises [Failure] when:

    - [candidate_label] has zero matching rows in [fold_actuals];
    - [baseline_label] has zero matching rows in [fold_actuals];
    - no candidate row has a matching baseline row by [fold_name] (callsite bug:
      variants ran on different folds). *)

val build_report :
  candidate_label:string ->
  baseline_label:string ->
  holdout_folds:int list ->
  best_iteration_index:int ->
  best_iteration_score:float ->
  fold_actuals:Walk_forward.Walk_forward_types.fold_actual list ->
  report
(** Assemble the {!report} from the executor's per-fold actuals plus
    bookkeeping. Computes the per-fold rows via {!pair_fold_actuals}, the two
    mean deltas, and the {!verdict}. *)

val render_report :
  report ->
  checkpoint_path:string ->
  walk_forward_spec_path:string ->
  baseline_aggregate_path:string option ->
  baseline_all_fold_mean_sharpe:float option ->
  baseline_all_fold_mean_max_drawdown_pct:float option ->
  string
(** Render the report as a markdown string. The all-fold baseline annotations
    are optional — populated when the caller loaded a [--baseline-aggregate]
    file and skipped otherwise.

    Deterministic — same inputs yield byte-identical output (no time/env reads).
*)
