# Wire spec.objective into score_cell — design (2026-05-18)

Plan-only doc. Lays out how to bring `bayesian_runner_scoring.score_cell` in
line with the objective specified in `bayesian_runner_spec.t.objective` so that
the production sweep described in
`dev/plans/bayesian-production-sweep-2026-05-18.md` actually optimises the
4-term Composite it promises.

Companion to `dev/plans/bayesian-production-sweep-2026-05-18.md` (#1192).

## 0. The bug

`dev/plans/bayesian-production-sweep-2026-05-18.md` §4 promises the BO loop
will optimise:

```sexp
(Composite
  ((SharpeRatio 0.40)
   (CalmarRatio 0.30)
   (CVaR95 -0.20)
   (MaxDrawdown -0.10)))
```

The shipped wiring disagrees. In walk-forward mode:

```
trading/trading/backtest/tuner/bin/bayesian_runner.ml:208
  → Evaluator.build_walk_forward
  → Bayesian_runner_scoring.score_cell
```

`score_cell` (`bayesian_runner_scoring.ml:51-79`) hardcodes:

```
loss  = -mean_sharpe
      + 0.10 * max(0, candidate_maxdd - baseline_maxdd)
      + 10.0 * gate_fail
score = -loss
```

The spec's `objective` field is only read in legacy mode
(`bayesian_runner.ml:131`, via `Spec.to_grid_objective`). In walk-forward mode
it is never consulted. Calmar and CVaR95 weights are silently ignored.

If we kick off the §4 sweep today, the BO will optimise mean-Sharpe-minus-a-
small-MaxDD-hinge instead of the 4-term Composite. The winning cell will
be Sharpe-greedy and Calmar/tail-risk-blind — exactly the failure mode the
Composite was designed to avoid.

## 1. Resolutions for the six open questions

### Q1. CVaR95 not in `variant_stability`

`Walk_forward.Walk_forward_types.variant_stability` (lines 36-46 of
`walk_forward_types.mli`) carries only:

- `total_return_pct`
- `sharpe_ratio`
- `max_drawdown_pct`
- `calmar_ratio`
- `cagr_pct`

CVaR95 is a `Trading_simulation_types.Metric_types.metric_type` variant (the
sexp parser already accepts it — `metric_types.mli:157`), but is not
precomputed in the walk-forward aggregate. Three options:

- **(a)** Drop CVaR95 from the v1 Composite — use 3-term Composite
  `(SharpeRatio 0.40)(CalmarRatio 0.30)(MaxDrawdown -0.10)`. Renormalise to
  `(SharpeRatio 0.50)(CalmarRatio 0.375)(MaxDrawdown -0.125)` if we want the
  Composite to sum to the same total weight, or keep raw weights and accept
  the lower magnitude.
- **(b)** Add CVaR95 to `variant_stability` and thread it from per-fold
  metric_sets through `walk_forward_report.compute`. Touches the
  walk_forward types + render + every test that pins the aggregate shape
  (10+ files).
- **(c)** Compute CVaR95 online in `score_cell` from a new per-fold returns
  field added to `fold_actual`. Same surface impact as (b) but the
  computation lives at the BO boundary, not in the WF library.

**Recommendation: (a) for the v1 sweep.** Justification:

- The 3-term Composite still penalises drawdown via the `MaxDrawdown -0.10`
  term. The marginal information CVaR95 adds over MaxDrawdown for the
  production sweep is small — both are tail-risk surrogates, and at N=5
  folds the empirical CVaR95 is computed off only 5 (or fewer) fold-return
  samples, which is statistically meaningless.
- (b) and (c) are 1-2 day refactors that touch the walk-forward type
  surface used by 5 PRs of in-flight + landed code (Phase 3 PR-A through
  PR-E). The cost is high; the v1 sweep yield is low.
- A follow-up (`dev/plans/cvar-in-walk-forward-aggregate-YYYY-MM-DD.md`)
  can pick (b) when we have either more folds or a real reason to break
  CVaR out from MaxDD.

**Action on the production-sweep plan:** §4 should be amended to the 3-term
Composite. This design doc's PR-1 lands the wiring, and we update the
production-sweep doc in the same PR.

### Q2. `baseline_aggregate` shape under Composite

Today's `score_cell` reads `baseline_stab.max_drawdown_pct.mean` for the
MaxDD hinge but otherwise ignores `baseline_aggregate`. Under Composite,
three options:

- **(i)** Keep the hinge mechanic + apply Composite on top (composite on
  raw candidate metrics, MaxDD hinge as an additive penalty against
  baseline).
- **(ii)** Drop the hinge entirely; score the candidate by its raw
  Composite. Baseline aggregate becomes unused.
- **(iii)** Composite-relative-to-baseline: compute Composite over
  candidate, Composite over baseline, score = `candidate_composite -
  baseline_composite`. Preserves the "improvement over baseline"
  semantics.

**Recommendation: (iii).** Justification:

- The whole point of running walk-forward CV with a baseline variant is to
  measure improvement, not absolute level. The production-sweep plan §6's
  promote-gate already compares against Cell-E baseline.
- (i) double-counts MaxDD (once via the hinge, once via the Composite's
  `MaxDrawdown -0.10` weight). Confusing.
- (ii) loses the baseline-relative signal; cells that score high in
  absolute terms but are no better than Cell-E pass the BO loop
  unfiltered. Bad in a sweep where the goal is to BEAT Cell-E.

Concretely: `score = composite(candidate) - composite(baseline)`. Identity
case (candidate == baseline) yields 0; improvement yields positive; worse
candidate yields negative. The BO loop's "higher is better" contract is
preserved.

Note: this changes the IDENTITY-case test invariant from "`+mean_sharpe`"
to "`0.0`". Old test `test_identity_candidate_equals_baseline` becomes a
NEW assertion under the Composite path — kept under Sharpe-default path.

### Q3. Gate penalty integration

The shipped formula has `-lambda_gate * gate_penalty_value` (= -10.0 on
Fail). Under Composite-relative scoring:

```
score = composite(cand) - composite(base) - lambda_gate * gate_penalty(cand)
```

**Recommendation: keep the gate penalty additive on top of the Composite
delta.** Justification:

- Gates and objective are orthogonal concerns. The gate is the M-of-N
  fold-pair pass requirement (per `Fold_gate.t`). A cell that wins on
  Composite but fails the gate is still a bad cell — the M-of-N
  requirement is "this cell didn't catastrophically fail any folds".
- The hard -10.0 magnitude was chosen specifically to dominate any
  marginal Sharpe improvement; under the Composite delta (which typically
  has magnitude ~0.1-0.5 between candidate variants on the same walk-
  forward window), -10.0 STILL dominates. No re-tuning of the gate-penalty
  constant needed.
- This also keeps `test_gate_pass_vs_fail_score_difference`'s -10.0
  invariant intact verbatim.

### Q4. Mean vs median across folds

The production-sweep plan §3 says "median-fold OOS metric".
`variant_stability.*.mean` is precomputed; `*.median` is not (per_metric_stats
in `walk_forward_types.mli:27-33` carries only `mean / stdev / min / max`).

Two options:

- **(a)** Extend `per_metric_stats` to carry `median`. Same surface
  impact as Q1 option (b) — touches the WF type / aggregate writers /
  every test.
- **(b)** Accept `mean` as the v1 fold aggregator. The production-sweep
  plan §3 calls for median; v1 uses mean and we file the follow-up.

**Recommendation: (b) for v1.** Justification:

- At N=5 folds, mean and median agree on most cells. The 2020 COVID
  outlier (fold 2) and 2022 bear (fold 3) are the cells where they
  diverge — and there the median would mask information the mean
  surfaces. A 5-fold mean is closer to "average fold behaviour" than
  a 5-fold median.
- The walk-forward type surface is touched by 5+ in-flight PRs. Adding
  `median` is a separate refactor.
- The production-sweep plan §3 should also be amended in the same PR
  that lands this change. The §3 wording ("MEDIAN-fold OOS metric") is
  aspirational; we should reword to "mean-fold OOS metric" until the
  follow-up adds median.

Follow-up: `dev/plans/median-in-walk-forward-stats-YYYY-MM-DD.md`.

### Q5. Backward compat

The existing `score_cell` tests in `test_bayesian_runner_scoring.ml` (15
tests, 502 LOC) pin the current formula. The new formula MUST be additive:

- If `objective = Sharpe` (the lib default), preserve today's behavior
  byte-for-byte. All 15 existing tests stay green.
- If `objective = Composite [...]`, switch to the new formula.
- Other objectives (`Calmar`, `TotalReturn`, `Concavity_coef`) — switch
  to a "single-metric relative" formula:
  `score = metric(cand) - metric(base) + maxdd_hinge_term + gate_term`
  with the maxdd_hinge_term re-enabled (since the Composite case
  subsumes the hinge into the Composite delta, but single-metric cases
  still need the explicit DD hinge to preserve risk discipline).

**Recommendation: implement as a pattern-match in `score_cell` with an
explicit Sharpe-default branch.** The signature gains an `objective`
parameter:

```ocaml
val score_cell :
  parameters:(string * float) list ->
  candidate_label:string ->
  baseline_label:string ->
  candidate_aggregate:Walk_forward.Walk_forward_types.aggregate ->
  baseline_aggregate:Walk_forward.Walk_forward_types.aggregate ->
  objective:Tuner.Grid_search.objective ->     (* NEW *)
  float Status.status_or
```

In the .ml:

```ocaml
let score_cell ~parameters:_ ~candidate_label ~baseline_label
    ~candidate_aggregate ~baseline_aggregate ~objective =
  let%bind candidate_stab = ...
  let%bind baseline_stab = ...
  let%bind candidate_verdict = ...
  let gate_penalty = _compute_gate_penalty candidate_verdict in
  match objective with
  | Tuner.Grid_search.Sharpe ->
      (* legacy path — preserves all 15 existing tests *)
      _score_sharpe_with_hinge ~candidate_stab ~baseline_stab ~gate_penalty
  | Composite weights ->
      _score_composite_relative ~candidate_stab ~baseline_stab
        ~weights ~gate_penalty
  | Calmar | TotalReturn | Concavity_coef ->
      _score_single_metric_relative ~objective ~candidate_stab
        ~baseline_stab ~gate_penalty
```

This means **no existing test changes**. All 15 existing tests are
re-routed through the Sharpe branch (which is the default and matches the
shipped formula byte-for-byte). New tests added for Composite + the
other single-metric branches.

The score_cell .mli docstring needs a rewrite to document the per-objective
branching. The "Scoring formula" section in the current .mli should split
into one paragraph per objective branch.

### Q6. Wire-through

Today `Evaluator.build_walk_forward` (in `bayesian_runner_evaluator.mli:79`)
does not carry an objective. It calls `Bayesian_runner_scoring.score_cell`
without one. The call edge needs:

```
Spec.t.objective : objective_spec
  → Spec.to_grid_objective : Tuner.Grid_search.objective
  → _run_walk_forward_mode (bayesian_runner.ml:208)
  → Evaluator.build_walk_forward (~objective : Tuner.Grid_search.objective)
  → _score_or_fail (bayesian_runner_evaluator.ml:112)
  → Bayesian_runner_scoring.score_cell (~objective)
```

Three call-site changes:

1. `bayesian_runner.ml:_run_walk_forward_mode` (line 208): compute
   `let objective = Spec.to_grid_objective spec.objective in` (same line
   already in legacy mode at line 131) and pass `~objective` into
   `Evaluator.build_walk_forward`.

2. `bayesian_runner_evaluator.mli:build_walk_forward` (line 79): add
   `objective : Tuner.Grid_search.objective ->` to the signature.
   Test stubs in `test_bayesian_runner_evaluator.ml` need updates to pass
   `~objective:Sharpe` (preserves existing behavior in those tests).

3. `bayesian_runner_evaluator.ml:build_walk_forward` (line 125):
   add `~objective` to the closure's captured args, pass it through to
   `_score_or_fail`, which passes it to `Bayesian_runner_scoring.score_cell`.

The objective should be captured at `build_walk_forward` build-time (not
per-iteration call-time) since it's a spec-level constant. Same closure
shape as the existing `baseline_label` / `baseline_aggregate` captures.

**Logging:** The walk-forward mode startup log line at `bayesian_runner.ml`
line ~220 (currently logs `total_budget / initial_random / bounds /
holdout_folds`) should ALSO log `objective=<label>` via
`Tuner.Grid_search.objective_label objective` — mirrors the legacy-mode
log at line 132-138. Diagnostic only; no test impact.

## 2. PR breakdown (≤500 LOC each)

### PR-1: Thread objective through evaluator + scoring signatures (~250 LOC)

Mechanical signature change + Sharpe-default branch. No behavioral change.

**Files:**

- `trading/trading/backtest/tuner/bin/bayesian_runner_scoring.mli`
  - Add `objective:Tuner.Grid_search.objective` param to `score_cell`.
  - Rewrite "Scoring formula" docstring to note the new param + future
    Composite branch (which lands in PR-2).
  - Add `val _score_sharpe_with_hinge` (internal helper exposed for
    test introspection, like `_lambda_dd`).
- `trading/trading/backtest/tuner/bin/bayesian_runner_scoring.ml`
  - Extract the existing formula into a private `_score_sharpe_with_hinge`
    helper.
  - Pattern-match on `objective` in `score_cell`:
    - `Sharpe` → existing formula (unchanged).
    - `Composite | Calmar | TotalReturn | Concavity_coef` → return
      `Status.error_unimplemented` for now (PR-2 implements these).
- `trading/trading/backtest/tuner/bin/bayesian_runner_evaluator.mli`
  - Add `objective:Tuner.Grid_search.objective` param to
    `build_walk_forward`.
- `trading/trading/backtest/tuner/bin/bayesian_runner_evaluator.ml`
  - Capture `objective` in `build_walk_forward`'s closure.
  - Pass it to `_score_or_fail` → `score_cell`.
- `trading/trading/backtest/tuner/bin/bayesian_runner.ml`
  - In `_run_walk_forward_mode`: compute `objective` via
    `Spec.to_grid_objective spec.objective`, pass to
    `Evaluator.build_walk_forward`.
  - Add `objective=<label>` to the mode-startup log line.
- `trading/trading/backtest/tuner/bin/test/test_bayesian_runner_scoring.ml`
  - Update every call site to pass `~objective:Tuner.Grid_search.Sharpe`.
  - All 15 existing tests stay green (the Sharpe branch is unchanged).
  - Add 1 new test: `test_unimplemented_objective_returns_error` —
    asserts `Composite` returns `Status.Unimplemented` (or equivalent)
    until PR-2 lands.
- `trading/trading/backtest/tuner/bin/test/test_bayesian_runner_evaluator.ml`
  - Update every `build_walk_forward` test call site to pass
    `~objective:Sharpe`. No behavioral change.

**Estimated LOC:** ~250. Mostly mechanical signature plumbing + test
updates. The actual scoring formula stays unchanged in this PR.

**Test plan:**
- `dune build && dune runtest trading/backtest/tuner/bin/test/` — all
  existing tests green.
- The new "unimplemented Composite" test fails before PR-2 lands; passes
  after PR-2's flip.

### PR-2: Implement Composite-relative + single-metric-relative scoring (~300 LOC)

Behavioral change. Adds the new scoring formulas for the non-Sharpe branches.

**Files:**

- `trading/trading/backtest/tuner/bin/bayesian_runner_scoring.mli`
  - Document the three formula branches in the "Scoring formula" docstring:
    - Sharpe → existing formula (preserved).
    - Composite weights → `Σᵢ wᵢ · (cand_metricᵢ - base_metricᵢ) - lambda_gate * gate_penalty`.
    - Calmar / TotalReturn / Concavity_coef → `(cand_metric - base_metric) + lambda_dd * max(0, cand_maxdd - base_maxdd) + lambda_gate * gate_penalty`.
  - Add `val _score_composite_relative` and
    `val _score_single_metric_relative` for test introspection.
  - Note in the docstring: "CVaR95 weight in Composite is silently dropped
    in v1 — see `dev/plans/cvar-in-walk-forward-aggregate-YYYY-MM-DD.md`
    follow-up. Other metric_types not in the WF aggregate
    (`TotalReturnPct`, `SharpeRatio`, `MaxDrawdown`, `CalmarRatio`,
    `CAGR`) are likewise dropped."
- `trading/trading/backtest/tuner/bin/bayesian_runner_scoring.ml`
  - Implement `_score_composite_relative ~candidate_stab ~baseline_stab
    ~weights ~gate_penalty`:
    - For each `(metric_type, weight)` pair in `weights`:
      - Look up `cand_metric_value` in `candidate_stab` (the 5
        per_metric_stats fields: total_return_pct / sharpe_ratio /
        max_drawdown_pct / calmar_ratio / cagr_pct, mapped from
        metric_type via a helper). Drop unmapped metric_types
        (CVaR95, etc.) with a warning logged to stderr the first time
        per `Bayesian_runner_scoring.t` lifetime.
      - Look up `base_metric_value` in `baseline_stab` the same way.
      - Accumulate `weight * (cand_metric_value - base_metric_value)`.
    - Subtract `_lambda_gate * gate_penalty`.
  - Implement `_score_single_metric_relative` along the same lines for
    Calmar / TotalReturn / Concavity_coef. The MaxDD hinge stays for these.
  - Add a `_metric_type_to_stability_field` helper that maps
    `Metric_types.metric_type` → `variant_stability -> per_metric_stats
    option`. Returns `None` for metric types not present in
    `variant_stability`.
- `trading/trading/backtest/tuner/bin/test/test_bayesian_runner_scoring.ml`
  - **8 new tests** under a "Composite scoring" suite:
    1. `test_composite_identity_returns_zero` — candidate == baseline
       → score = 0.0.
    2. `test_composite_sharpe_only_weight` — `Composite ((SharpeRatio
       1.0))` reduces to `(cand_sharpe - base_sharpe)`.
    3. `test_composite_three_term_production_formula` — exact
       computation against the v1 production weights
       `((SharpeRatio 0.40)(CalmarRatio 0.30)(MaxDrawdown -0.10))`.
    4. `test_composite_negative_weight_penalises_metric` — confirms
       `(MaxDrawdown -0.10)` PENALISES higher MaxDD (per sexp parser's
       support for negative weights at `test_grid_search.ml:148`).
    5. `test_composite_missing_metric_dropped_silently` — `Composite
       ((CVaR95 -0.20)(SharpeRatio 1.0))` collapses to
       `1.0 * (cand_sharpe - base_sharpe)` since CVaR95 is not in
       variant_stability. **Documents the v1 behaviour.**
    6. `test_composite_gate_fail_score_diff` — analogous to existing
       gate test: Composite + Pass vs Composite + Fail → score diff =
       -10.0.
    7. `test_calmar_objective_relative` — `Calmar` objective reduces
       to `(cand_calmar - base_calmar) + maxdd_hinge + gate_penalty`.
    8. `test_total_return_objective_relative` — same for TotalReturn.
  - Update `test_unimplemented_objective_returns_error` from PR-1 →
    remove (Composite is now implemented).

**Estimated LOC:** ~300. Most of it is the test suite (~200 LOC); the
helper + Composite implementation is ~50-80 LOC.

**Test plan:**
- `dune build && dune runtest trading/backtest/tuner/bin/test/` — all
  tests green.
- Smoke run: rebuild `bayesian_runner.exe`; run a 5-eval Composite-spec
  smoke against an existing walk-forward fixture; visually verify the
  `bo_log.csv` shows varying scores and the best.sexp has finite output.

### PR-3: Amend production-sweep doc to match shipped scorer (~50 LOC of doc)

Doc-only. Lands alongside PR-2 or as a follow-up.

**Files:**

- `dev/plans/bayesian-production-sweep-2026-05-18.md`
  - §4 Objective function — drop CVaR95 from the Composite. Rewrite as:
    ```sexp
    (Composite
      ((SharpeRatio 0.50)
       (CalmarRatio 0.375)
       (MaxDrawdown -0.125)))
    ```
    Note the renormalisation (Sharpe + Calmar + MaxDD weights raised to
    preserve magnitude after dropping CVaR's -0.20 weight). Document
    "CVaR95 dropped in v1; follow-up `dev/plans/cvar-in-walk-forward-aggregate-YYYY-MM-DD.md`."
  - §3 OOS aggregator — change "MEDIAN-fold OOS metric" to "mean-fold
    OOS metric". Document follow-up `dev/plans/median-in-walk-forward-stats-YYYY-MM-DD.md`.
  - §6 Acceptance gate — adjust the "Median-fold composite" rows to
    "Mean-fold composite". The 5 gates themselves do NOT change.
  - §0 Cell-E baseline reference table — drop the "Median-fold composite"
    row; keep "Composite (4-term)" (which becomes "Composite (3-term)"
    after the §4 amend) as the v1 baseline to measure.

**Estimated LOC:** ~50 of doc edits.

## 3. Total effort

| PR | What | Estimated LOC | Risk |
|----|------|---------------|------|
| PR-1 | Thread `objective` through signatures + Sharpe-default branch | ~250 | Low — mechanical, no behavior change |
| PR-2 | Implement Composite-relative + single-metric-relative | ~300 | Medium — new formula, new tests, lib-side surface |
| PR-3 | Amend production-sweep doc | ~50 doc | Low — doc only |
| **Total** | | **~600** | |

PR-1 + PR-2 sum to ~550 LOC — slightly over the 500 LOC PR-sizing target.
If reviewers prefer, PR-1 can be further split:

- PR-1a: Add `objective` param to `score_cell.mli` + `.ml` (Sharpe-default
  branch only); update score_cell tests. (~150 LOC)
- PR-1b: Add `objective` param to `build_walk_forward.mli` + `.ml` + wire
  through `bayesian_runner.ml`; update evaluator tests. (~100 LOC)

This split keeps each PR under 200 LOC and lets the reviewer audit the
type-surface change (PR-1a) separately from the call-site plumbing
(PR-1b).

## 4. Test plan (full stack)

Land in sequence:

1. PR-1 lands. `dune runtest trading/backtest/tuner/bin/test/` green; all
   existing 15 score_cell tests + evaluator tests + binary smoke tests
   green. New "Composite returns Unimplemented" test asserts the gap.
2. PR-2 lands. New 8-test Composite suite green. The "Unimplemented" test
   is removed.
3. PR-3 lands (doc).
4. Phase A smoke (per production-sweep §7 Phase A step 2) re-runs with
   the amended 3-term Composite spec. The 5-eval BO produces varying
   scores; `best.sexp` shows finite output.

Acceptance: the production-sweep Phase B can dispatch with the amended
spec, and the BO will optimise the Composite the plan claims it does.

## 5. Open follow-ups

- `dev/plans/cvar-in-walk-forward-aggregate-YYYY-MM-DD.md` — Q1 option
  (b): add CVaR95 (and other tail-risk metrics) to `variant_stability` +
  thread from per-fold metric_sets. Touches WF type surface; ~1-2 day
  refactor.
- `dev/plans/median-in-walk-forward-stats-YYYY-MM-DD.md` — Q4 option
  (a): add `median` to `per_metric_stats`. Same surface impact as the
  CVaR follow-up.
- `dev/plans/cvar-online-in-scorer-YYYY-MM-DD.md` — Q1 option (c)
  alternative: compute CVaR95 online in `score_cell` from a per-fold
  returns field. Smaller surface change but adds compute to the BO hot
  path.

## 6. Risks

| Risk | Mitigation |
|------|------------|
| Breaking existing 15 score_cell tests | Sharpe-default branch is byte-identical to today's formula; all 15 tests pass through it unchanged. |
| Composite formula doesn't match production-sweep plan's intent | PR-3 amends the plan to match the implementation, with the v1/v2 follow-up documented explicitly. CVaR drop is justified at §1 Q1. |
| Other consumers of `score_cell` break | `score_cell` has exactly one caller (`_score_or_fail` in `bayesian_runner_evaluator.ml:112`). No other consumers. |
| `Metric_types.metric_type` map to `variant_stability` field is hacky | Centralised in one helper (`_metric_type_to_stability_field`). All metric types not present return `None`. Pinned by `test_composite_missing_metric_dropped_silently`. |
| GP posterior corruption from score-magnitude shift | The Composite branch is opt-in via spec. Sharpe-default unchanged. Existing Sharpe-spec sweeps don't change behavior. |
| Logging-asymmetry between legacy and walk-forward mode | PR-1 adds `objective=<label>` to the WF mode-startup log; matches legacy mode. |

## 7. Acceptance gates (for this plan itself)

This plan is approved when:

1. The Q1 recommendation (drop CVaR95 for v1) is accepted — the
   production-sweep Composite formula amends to 3-term.
2. The Q2 recommendation (Composite-relative-to-baseline) is accepted as
   the scoring semantics.
3. The Q5 recommendation (additive backward-compat via per-objective
   pattern-match) is accepted as the implementation shape.
4. The PR-1 / PR-2 / PR-3 split is acceptable (or PR-1 is further split
   into PR-1a + PR-1b per §3).

If any gate fails, revise + re-circulate. If all pass, land PR-1 first.

## 8. Companion docs

- `dev/plans/bayesian-production-sweep-2026-05-18.md` — the sweep this
  plan unblocks
- `dev/plans/bayesian-multi-param-scaling-2026-05-16.md` — Phase 3 plan
  whose §3.1 scoring-formula spec this design extends
- `dev/plans/bayesian-opt-2026-05-03.md` — original T-B Bayesian opt
  design
