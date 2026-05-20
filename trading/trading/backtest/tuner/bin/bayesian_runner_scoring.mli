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
     {- [Composite weights] — composite-relative-to-baseline (plan §1 Q2 (iii)):
        {v
          score(cell) = Σᵢ wᵢ · (cand_metricᵢ - base_metricᵢ)
                      - lambda_gate * gate_penalty(cell)
        v}
        The identity case (candidate == baseline) yields a composite-delta of
        [0.0]; improvement yields a positive score; worse candidate yields
        negative. The "higher is better" BO contract is preserved.

        Weighted metrics are looked up against the candidate's and baseline's
        {!Walk_forward.Walk_forward_types.variant_stability} record via
        {!_metric_mean_from_stability}. The six metrics carried by the
        walk-forward aggregate are mapped — [TotalReturnPct], [SharpeRatio],
        [MaxDrawdown], [CalmarRatio], [CAGR], [AvgHoldingDays]. Any other
        metric_type in [weights] (notably [CVaR95]) is silently dropped — plan
        §1 Q1 v1 behaviour; the production sweep [Composite] formula is the
        3-term [(SharpeRatio 0.40)(CalmarRatio 0.30)(MaxDrawdown -0.10)] (CVaR95
        deferred to a walk-forward follow-up).

        [AvgHoldingDays] was added 2026-05-20 (P5 infra of
        [dev/plans/hold-period-deep-dive-2026-05-19.md]) so the Composite scorer
        can carry a hold-cadence reward term, e.g.
        [(SharpeRatio 0.50)(CalmarRatio 0.30)(MaxDrawdown -0.10) (AvgHoldingDays
         0.10)] — positive weight rewards candidates whose mean hold exceeds the
        baseline by N days, linearly.

        See {!_score_composite_relative}.
     }
     {- [Calmar] / [TotalReturn] / [Concavity_coef] — single-metric-relative
        (plan §1 Q5):
        {v
          score(cell) = (cand_metric - base_metric)
                      - lambda_dd  * max(0, cand_maxdd - base_maxdd)
                      - lambda_gate * gate_penalty(cell)
        v}
        The MaxDD hinge is retained for the single-metric branches because
        (unlike Composite) the objective does not itself include a MaxDD
        penalty, so an unhinged single-metric scorer would lose risk discipline.

        Note: [Concavity_coef] is not carried in [variant_stability]; both
        candidate and baseline metric values are [0.0] under this branch, so the
        score reduces to [-(lambda_dd*hinge + lambda_gate*gate_penalty)]. Until
        a follow-up threads concavity into the walk-forward aggregate the
        Concavity_coef objective effectively scores by risk-discipline alone —
        documented behaviour, not a bug. See {!_score_single_metric_relative}.
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

val _score_composite_relative :
  candidate_stab:Walk_forward.Walk_forward_types.variant_stability ->
  baseline_stab:Walk_forward.Walk_forward_types.variant_stability ->
  weights:(Trading_simulation_types.Metric_types.metric_type * float) list ->
  gate_penalty:float ->
  float
(** Composite-relative-to-baseline scoring helper. Exposed for test
    introspection.

    {v
      score = Σᵢ wᵢ · (cand_metricᵢ - base_metricᵢ)
            - _lambda_gate * gate_penalty
    v}

    Metric types not carried in
    {!Walk_forward.Walk_forward_types.variant_stability} (anything other than
    [TotalReturnPct], [SharpeRatio], [MaxDrawdown], [CalmarRatio], [CAGR]) are
    silently dropped. Plan §1 Q1 v1 behaviour. *)

val _score_single_metric_relative :
  objective:Tuner.Grid_search.objective ->
  candidate_stab:Walk_forward.Walk_forward_types.variant_stability ->
  baseline_stab:Walk_forward.Walk_forward_types.variant_stability ->
  gate_penalty:float ->
  float
(** Single-metric-relative scoring helper for [Calmar] / [TotalReturn] /
    [Concavity_coef]. Exposed for test introspection.

    {v
      score = (cand_metric - base_metric)
            - _lambda_dd  * max(0, cand_maxdd - base_maxdd)
            - _lambda_gate * gate_penalty
    v}

    The caller is responsible for not routing [Sharpe] or [Composite _] through
    this helper — the implementation defensively returns [0.0] for the
    metric_value of those objectives so the formula remains total. *)

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
      Sharpe-with-MaxDD-hinge formula.
    - [Composite _] — composite-relative-to-baseline (Σ wᵢ·Δmetricᵢ - gate).
    - [Calmar] / [TotalReturn] / [Concavity_coef] — single-metric-relative
      ((cand - base) - hinge - gate).

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

    Determinism: same inputs → byte-identical [float] output (modulo IEEE-754
    quirks; no floating-point reduction order dependencies because the
    aggregate's [mean] fields are already pre-reduced). *)
