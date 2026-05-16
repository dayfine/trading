(** Out-of-sample (OOS) validation for the Phase-3 Bayesian optimizer's best
    cell.

    After the BO loop converges, this module re-evaluates the best cell on the
    held-out folds (per the spec's [holdout_folds] field) and decides whether
    the cell generalises out-of-sample.

    The acceptance rule is plan §6.3 of
    [dev/plans/bayesian-multi-param-scaling-2026-05-16.md] — the "no-overfit
    hurdle": OOS mean Sharpe must be within [0.10] of the in-sample mean Sharpe.
    A larger gap signals the BO over-fit the in-sample folds and the cell is
    {b rejected} for production pinning.

    Pure split: this module {b never} runs a backtest. It consumes a flat list
    of per-fold measurements (the {!Walk_forward.Walk_forward_types.fold_actual}
    list the walk-forward executor produces) and the {!Bayesian_runner_spec.t}
    holdout-fold positions, partitions the measurements, and emits a structured
    {!oos_result} + a markdown {!oos_report.md}-shaped string. The caller (the
    [bayesian_runner.exe] binary in PR-E) is responsible for actually executing
    the best cell's walk-forward sweep and supplying the per-fold rows. *)

module Wf_types = Walk_forward.Walk_forward_types

val _no_overfit_hurdle_sharpe : float
(** Maximum permitted absolute gap between in-sample mean Sharpe and
    out-of-sample mean Sharpe before the cell is rejected as over-fit. Plan §6.3
    pins this at [0.10]. Exposed for diagnostic logging and for the test suite.
*)

(** Outcome of the OOS validation step.

    - [Accept]: the OOS Sharpe is within {!_no_overfit_hurdle_sharpe} of the
      in-sample Sharpe.
    - [Reject_overfit]: the OOS Sharpe gap exceeds the hurdle (over-fit).
    - [Reject_insufficient_data]: there are not enough OOS folds to compute a
      meaningful mean (zero OOS rows after partitioning). The caller's spec must
      list at least one valid holdout fold position. *)
type verdict = Accept | Reject_overfit | Reject_insufficient_data
[@@deriving sexp]

type oos_result = {
  candidate_label : string;
      (** Walk-forward variant label the OOS validator scored (e.g.
          [bo-iter-best]). Recorded for the markdown report. *)
  in_sample_mean_sharpe : float;
      (** Arithmetic mean of [sharpe_ratio] across {b in-sample} folds (those
          whose 1-indexed position is NOT in
          [Bayesian_runner_spec.holdout_folds]) for the [candidate_label]
          variant. [Float.nan] when no in-sample folds remain after
          partitioning. *)
  oos_mean_sharpe : float;
      (** Arithmetic mean of [sharpe_ratio] across {b out-of-sample} folds
          (those whose 1-indexed position IS in
          [Bayesian_runner_spec.holdout_folds]). [Float.nan] when no OOS folds
          matched. *)
  gap : float;
      (** Signed difference [oos_mean_sharpe - in_sample_mean_sharpe]. The
          {!verdict} rejects when [abs(gap) > _no_overfit_hurdle_sharpe]. *)
  in_sample_fold_count : int;
      (** Number of in-sample folds the means were computed over. *)
  oos_fold_count : int;
      (** Number of OOS folds the means were computed over. *)
  per_oos_fold : (string * float) list;
      (** [(fold_name, sharpe_ratio)] pairs for each OOS fold, in
          first-appearance order. The renderer surfaces these per-fold so the
          operator can see whether the gap is driven by a single anomalous fold.
      *)
  verdict : verdict;  (** Accept / Reject decision. *)
}
[@@deriving sexp]
(** Output of {!validate}. The full structured shape is exposed (rather than
    just the verdict) so the binary can log it, persist it as [oos_result.sexp],
    and use it as input to {!render_report}. *)

val validate :
  candidate_label:string ->
  holdout_folds:int list ->
  fold_actuals:Wf_types.fold_actual list ->
  oos_result
(** [validate ~candidate_label ~holdout_folds ~fold_actuals] partitions
    [fold_actuals] (already filtered to the candidate variant, OR carrying
    multiple variants — the function filters internally by
    [variant_label = candidate_label]) into in-sample vs OOS by 1-indexed fold
    position.

    The fold-position-to-name mapping follows
    {!Walk_forward.Window_spec.generate}'s output order: fold position [k]
    (1-indexed) corresponds to the [k-1]-th fold in [fold_actuals] (filtered to
    the candidate variant, then ordered by appearance). This matches how the
    walk-forward runner produces fold actuals — outer = variants, inner = folds
    in generation order — so the caller can pass the executor's [fold_actuals]
    verbatim.

    Returns an {!oos_result} with [verdict = Reject_insufficient_data] when no
    OOS rows match (e.g. empty [holdout_folds] or positions beyond the fold
    count); [Reject_overfit] when [abs(gap) > _no_overfit_hurdle_sharpe];
    otherwise [Accept].

    Pure: no I/O, no exceptions on well-formed inputs (positions beyond the fold
    count are silently dropped — they produce [Reject_insufficient_data] rather
    than raising). *)

val render_report :
  oos_result -> spec_path:string -> baseline_label:string -> string
(** [render_report result ~spec_path ~baseline_label] returns a markdown string
    suitable for writing to [oos_report.md].

    Sections (deterministic, byte-stable for the same input):

    + Title + the BO spec path + the candidate / baseline labels.
    + In-sample vs OOS mean Sharpe table.
    + Per-OOS-fold table.
    + Verdict block — [Accept] / [Reject_overfit] / [Reject_insufficient_data]
      with the gap value and the [_no_overfit_hurdle_sharpe] hurdle.

    The markdown is plain text; no images, no escaping needed for the inputs
    this binary produces. *)

val write_report :
  string -> oos_result -> spec_path:string -> baseline_label:string -> unit
(** [write_report path result ~spec_path ~baseline_label] writes the rendered
    report to [path] via [Out_channel.with_file]. Creates / truncates the file;
    parent directory must already exist. *)
