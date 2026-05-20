(** Pure scoring function for the Phase 3 Bayesian optimizer.

    Consumes a per-cell walk-forward
    {!Walk_forward.Walk_forward_types.aggregate} plus a baseline aggregate
    (always Cell E on the same walk-forward spec) and returns the BO loop's
    "higher is better" score for that cell. Splitting the scorer out of
    {!Tuner_bin.Bayesian_runner_evaluator} keeps it pure and unit-testable: the
    evaluator (PR-C) calls this function after running the walk-forward CV; this
    module never touches the filesystem, never spawns a subprocess, never reads
    a config.

    Scoring formula — per-objective dispatch (plan
    [dev/plans/wire-spec-objective-into-score-cell-2026-05-18.md] §1 Q5):

    {ul
     {- [Sharpe] (default) — preserves the legacy formula byte-for-byte (plan
        [dev/plans/bayesian-multi-param-scaling-2026-05-16.md] §3.1):
        {v
          loss(cell)  = -mean_sharpe(cell)
                      + lambda_dd  * max(0, mean_maxdd(cell) - baseline_maxdd)
                      + lambda_gate * gate_penalty(cell)
          score(cell) = -loss(cell)
        v}
        See {!_score_sharpe_with_hinge}.
     }
     {- [Composite _] / [Calmar] / [TotalReturn] / [Concavity_coef] — return
        [Status.Unimplemented]. PR-2 of the wire-spec plan implements the
        Composite-relative and single-metric-relative branches. PR-1 (this
        change) ships the signature plumbing only; the BO sweep should set
        [objective = Sharpe] until PR-2 lands.
     }
    }

    where:

    - [mean_sharpe(cell)] is the cell's mean per-fold Sharpe ratio, computed
      from the {!Walk_forward.Walk_forward_types.aggregate}'s [stability] entry
      for the candidate variant. NOTE: the precomputed
      [stability[v].sharpe_ratio.mean] is used as-is. Plan §3.1 calls for
      excluding folds whose return is below the degenerate-portfolio floor
      ([-50%]); the aggregate's mean does not carry the per-fold return so the
      exclusion is implemented at the upstream walk-forward harness when
      relevant — for the scorer's signature here, only the aggregate is in
      scope. The signature is reserved to accept a per-fold list in a future
      revision; PR-A delivers the aggregate-only path with the constant
      {!_degenerate_fold_floor_return_pct} declared for documentation.

    - [mean_maxdd(cell)] is the cell's mean per-fold MaxDD%, also drawn from
      [stability[v].max_drawdown_pct.mean].

    - [baseline_maxdd] is read from the baseline aggregate's
      [stability[<baseline_label>].max_drawdown_pct.mean]; PR-A reads the
      baseline dynamically rather than hardcoding a value, so the score remains
      correct when the Cell E baseline re-pins.

    - [gate_penalty(cell)] is [0.0] if the candidate variant's [verdicts] entry
      is [Pass _], else {!_gate_penalty_value}. The synthetic Fail variant from
      a fold-pair count mismatch (see
      {!Walk_forward.Walk_forward_report.compute}) collapses to the same penalty
      — no special case.

    Hyperparameter tuning rationale lives in the plan §3.1; the constants below
    are exposed in the mli so callers can introspect them (e.g. for diagnostic
    output) but the values are pinned, not overridable. *)

val _lambda_dd : float
(** Penalty coefficient on excess MaxDD over baseline. Default [0.10] — every
    1pp of excess MaxDD costs 0.10 units of Sharpe-equivalent loss. *)

val _gate_penalty_value : float
(** Magnitude of the gate-fail penalty. Default [10.0] — chosen to dominate any
    marginal Sharpe improvement so cells failing the M-of-N gate are pushed to
    the tail of the search distribution. *)

val _lambda_gate : float
(** Penalty coefficient on the gate verdict. Default [1.0]. The product
    [lambda_gate * gate_penalty_value = 10.0] is the effective loss bump on
    [Fail]. *)

val _degenerate_fold_floor_return_pct : float
(** Per-fold total-return floor below which the fold is considered
    degenerate-portfolio (mass liquidation cascade). Default [-50.0].

    Reserved for the per-fold scoring path; the aggregate-only path here uses
    the aggregate's precomputed mean Sharpe directly. Documented in the mli so
    callers in PR-C can wire per-fold exclusion when the walk-forward harness
    surfaces per-fold returns to the scorer. *)

val _score_sharpe_with_hinge :
  candidate_stab:Walk_forward.Walk_forward_types.variant_stability ->
  baseline_stab:Walk_forward.Walk_forward_types.variant_stability ->
  gate_penalty:float ->
  float
(** Pure Sharpe-with-MaxDD-hinge formula. Exposed so tests can introspect the
    branch directly (mirrors the existing [_lambda_dd] / [_gate_penalty_value]
    exposure). The top-level [score_cell] routes [objective = Sharpe] through
    this helper.

    {v
      loss  = -candidate_stab.sharpe_ratio.mean
            + _lambda_dd  * max(0, candidate_stab.max_drawdown_pct.mean
                                   - baseline_stab.max_drawdown_pct.mean)
            + _lambda_gate * gate_penalty
      score = -loss
    v} *)

val score_cell :
  parameters:(string * float) list ->
  candidate_label:string ->
  baseline_label:string ->
  candidate_aggregate:Walk_forward.Walk_forward_types.aggregate ->
  baseline_aggregate:Walk_forward.Walk_forward_types.aggregate ->
  objective:Tuner.Grid_search.objective ->
  float Status.status_or
(** [score_cell ~parameters ~candidate_label ~baseline_label
     ~candidate_aggregate ~baseline_aggregate ~objective] returns the BO score
    (higher-is-better) for the candidate cell.

    [parameters] is accepted for logging-shape symmetry with the existing
    evaluator surface; the score does not depend on the parameter values
    directly (it depends only on the walk-forward outcomes). It is required so
    callers cannot accidentally pass a "blank" assignment when the BO loop
    expects per-iteration cells.

    [objective] selects the scoring branch (see top-of-module docstring):

    - [Sharpe] (default for existing sweeps) — preserves the legacy
      Sharpe-with-MaxDD-hinge formula. All existing tests + production sweeps
      continue to use this path.
    - [Composite _] / [Calmar] / [TotalReturn] / [Concavity_coef] — return
      [Status.Unimplemented] until PR-2 implements them.

    [candidate_aggregate] and [baseline_aggregate] are produced by
    {!Walk_forward.Walk_forward_report.compute}. The candidate aggregate is the
    output of the walk-forward run for the cell under test; the baseline
    aggregate is the Cell E reference run on the SAME walk-forward spec (window
    / fold layout / gate).

    Error cases (each carrying a structured {!Status.t}):

    - [Status.NotFound] when [candidate_label] is not present in
      [candidate_aggregate.stability].
    - [Status.NotFound] when [candidate_label] is not present in
      [candidate_aggregate.verdicts].
    - [Status.NotFound] when [baseline_label] is not present in
      [baseline_aggregate.stability].
    - [Status.Invalid_argument] when [candidate_aggregate.fold_count = 0] — a
      zero-fold aggregate cannot yield a meaningful mean Sharpe.
    - [Status.Unimplemented] when [objective] is anything other than [Sharpe]
      (lifted in PR-2 of the wire-spec plan).

    Determinism: same inputs → byte-identical [float] output (modulo IEEE-754
    quirks; no floating-point reduction order dependencies because the
    aggregate's [mean] fields are already pre-reduced). *)
