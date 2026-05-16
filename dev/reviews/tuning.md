Reviewed SHA: b23e76dc188bf843102865945bec6753f047990f

## Structural Checklist — Bayesian Phase 3 PR-A (PR #1126, scoring function)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | |
| H2 | dune build | PASS | |
| H3 | dune runtest trading/backtest/tuner/ | PASS | 15 tests in test_bayesian_runner_scoring.exe passed; pre-existing failures on test_bayesian_opt and test_grid_search_bin / test_bayesian_runner_bin confirmed as pre-existing on origin/main |
| P1 | Functions ≤ 50 lines (linter) | PASS | All functions: _lambda_dd (1L), _gate_penalty_value (1L), _lambda_gate (1L), _degenerate_fold_floor_return_pct (1L), _lookup_stability (14L), _lookup_verdict (11L), _compute_maxdd_hinge (3L), _compute_gate_penalty (2L), score_cell (29L). All under 50L; linter gates clean. |
| P2 | No magic numbers (linter) | PASS | All numeric parameters are named constants at module level (lines 6–9): _lambda_dd=0.10, _gate_penalty_value=10.0, _lambda_gate=1.0, _degenerate_fold_floor_return_pct=-50.0. Formula uses these constants only; no inline literals. |
| P3 | Config completeness | PASS | No configurable thresholds in this module — all hyperparameters are named constants pinned at the module level for deterministic reproducibility. Formula is pure. |
| P4 | Public-symbol export hygiene (linter) | PASS | Single public function (score_cell) is fully documented; all internal helpers prefixed with underscore. mli-coverage linter gates clean. |
| P5 | Internal helpers prefixed per convention | PASS | All internal functions (_lookup_stability, _lookup_verdict, _compute_maxdd_hinge, _compute_gate_penalty) and constants (_lambda_dd, etc.) correctly prefixed with underscore. |
| P6 | Tests conform to `.claude/rules/test-patterns.md` (presence + conformance) | PASS | 15 tests in test_bayesian_runner_scoring.ml. Sub-rule 1 (no List.exists+equal_to): clean. Sub-rule 2 (no let_=result patterns): clean. Sub-rule 3 (no bare match without Matchers): match statements use assert_that, is_ok_and_holds, float_equal, gt; no bare match arms. Tests use canonical Matchers composition via assert_that/is_ok_and_holds; no nested assert_that in callbacks. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) — FLAG if any found | PASS | No modifications to core modules. All changes under trading/trading/backtest/tuner/bin/ and dev/status/tuning.md only. |
| A2 | No new `analysis/` imports into `trading/trading/` outside established backtest exception surface | PASS | New module consumes walk_forward (trading/trading/backtest/walk_forward/lib/) — same-side, allowed. No new analysis/ imports added. dune file verifies clean. |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | File list from diff matches expected scope: bayesian_runner_scoring.{ml,mli}, dune (library + test), test_bayesian_runner_scoring.ml, dev/status/tuning.md. No stray cross-module modifications. |

## Verdict — PR-A

APPROVED

## Notes on design decisions

**Degenerate-fold exclusion deferral (documented):** Per the plan §3.1, folds with return < -50% should be excluded from scoring. The implementation notes in the `.mli` (lines 27–34) explicitly document that the aggregate's pre-reduced mean Sharpe is used as-is, and the per-fold exclusion is reserved for PR-C. The constant `_degenerate_fold_floor_return_pct = -50.0` is declared and documented as "reserved for the per-fold scoring path; the aggregate-only path here uses the aggregate's precomputed mean Sharpe directly" (lines 73–75). This deferral is acceptable at the structural layer — it is explicitly documented and the contract is clear that the constant will be wired in PR-C when per-fold returns are available. qc-behavioral will assess whether the behavioral contract is fully pinned.

---

# Prior structural review (T-A grid_search, 2026-05-03)

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | |
| H2 | dune build | PASS | |
| H3 | dune runtest | PASS | All tests passed; Grid_search tests green |
| P1 | Functions ≤ 50 lines (linter) | PASS | H3 passed; linter gates clean |
| P2 | No magic numbers (linter) | PASS | H3 passed; linter gates clean |
| P3 | Config completeness | PASS | Grid_search uses config; no hardcoded thresholds |
| P4 | Public-symbol export hygiene (linter) | PASS | H3 passed; mli-coverage gates clean |
| P5 | Internal helpers prefixed per project convention | PASS | Internal test helpers prefixed with underscore |
| P6 | Tests conform to `.claude/rules/test-patterns.md` (presence + conformance) | PASS | Rework fixed nested assert_that. All three P6 sub-rules pass: no List.exists+equal_to(true/false), no let_=result patterns, no bare match without Matchers. The critical fix in test_cell_to_overrides_nested now uses matching combinator correctly — no nested assert_that in callback. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) — FLAG if any found | PASS | No core module modifications; only test file touched |
| A2 | No new `analysis/` imports into `trading/trading/` outside established backtest exception surface | PASS | No dune file changes; no new analysis imports |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | Single file changed: trading/trading/backtest/tuner/test/test_grid_search.ml (rework of P6 violation only) |

## Verdict

APPROVED

## Quality Score

5 — Rework cleanly fixed the P6 nested-assert_that violation using the canonical `matching` combinator. No incidental drift, all gates green, no new violations introduced.

---

# Behavioral QC — tuning (T-A grid_search)
Date: 2026-05-03
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in `grid_search.mli` docstrings has an identified test that pins it | PASS | Cartesian product (3×3×3=27, 3×3×3×3=81, lex order, empty spec → `[[]]`, empty values → []) → cartesian tests; `cell_to_overrides` (top-level + nested via `parse_to_sexp`) → cell_to_overrides tests; `objective_label` / `objective_metric_type` (Composite → None) → objective tests; `evaluate_objective` simple lookup, missing → 0.0, Composite weighted sum incl. negative weight → evaluate_objective tests; `run` rows = |cells|×|scenarios|, mean-across-scenarios argmax, tie-break = first cell, empty scenarios → `Invalid_argument`, determinism → run tests; `compute_sensitivity` one-row-per-param, holds-others-at-best, varied_values sorted asc, empty spec → empty rows → sensitivity tests; `write_csv` header columns + line count, `write_best_sexp` round-trip, `write_sensitivity_md` per-param section + objective name → output writer tests. Minor gap: `best_score = Float.neg_infinity when rows empty` is unreachable via `run` (empty scenarios raises; empty spec returns `[[]]`), so the doc claim is internal-only and not pinned — flagged but not failing. |
| CP2 | Each claim in PR body "Test plan" / "What it does" sections has a corresponding test in the committed test file | PASS | "24 unit tests" (suite has 24 entries), "Cartesian (3×3×3=27, 3×3×3×3=81 flagship)" → both tests present, "argmax with mean-across-scenarios" → `test_run_argmax_averages_across_scenarios`, "weighted Composite objectives" → `test_evaluate_objective_composite_weighted_sum`, "sensitivity-table holding others at best" → `test_sensitivity_holds_others_at_best`, "CSV/sexp/markdown output writers" → three writer tests, "edge cases (empty spec, empty values, empty scenarios → raise)" → three corresponding tests, "determinism" → `test_run_determinism`. The deferred items (CLI binary, 81-cell wall-time gate) are explicitly called out as deferred in the PR body — no claim of being pinned. |
| CP3 | Pass-through / identity / invariant tests pin identity (elements_are [equal_to ...] or equal_to on entire value), not just size_is | PASS | `test_cartesian_lex_order_innermost_varies_fastest` uses `elements_are [equal_to ...; equal_to ...; ...]` on full cell records — the lex-order invariant is pinned by identity, not just count. `test_run_picks_argmax_cell` asserts `equal_to [("a", 3.0); ("b", 30.0)]` on the full best_cell and `float_equal 33.0` on best_score. `test_sensitivity_holds_others_at_best` asserts `elements_are [pair (float_equal v) (float_equal score); ...]` on the full varied_values list. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | (1) `cells_of_spec []` returns `[[]]` claim → `test_cartesian_empty_spec_yields_one_empty_cell`. (2) Empty values list yields zero cells claim → `test_cartesian_with_empty_values_yields_zero_cells`. (3) `run` raises `Invalid_argument` on empty scenarios → `test_run_empty_scenarios_raises` asserts the exact string. (4) Missing-metric-defaults-to-0.0 (in `evaluate_objective`) → `test_evaluate_objective_missing_metric_is_zero`. (5) Tie-break-by-enumeration claim → `test_run_tie_break_picks_first_cell`. (6) `cell_to_overrides` raises `Failure` on malformed key_path — NOT pinned by a test, but this guard is reached only via `Backtest.Config_override.parse_to_sexp` failure which the test stub avoids. Minor (one un-pinned guard) but not failing. |

## Behavioral Checklist (Weinstein-domain)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | Pure infra / harness / refactor PR; domain checklist not applicable. (qc-structural did not flag A1 — no core module changes.) |
| S1 | Stage 1 definition matches book | NA | Pure infra / harness / refactor PR; domain checklist not applicable. |
| S2 | Stage 2 definition matches book | NA | Pure infra / harness / refactor PR; domain checklist not applicable. |
| S3 | Stage 3 definition matches book | NA | Pure infra / harness / refactor PR; domain checklist not applicable. |
| S4 | Stage 4 definition matches book | NA | Pure infra / harness / refactor PR; domain checklist not applicable. |
| S5 | Buy criteria: Stage 2 entry on breakout with volume | NA | Pure infra / harness / refactor PR; domain checklist not applicable. |
| S6 | No buy signals in Stage 1/3/4 | NA | Pure infra / harness / refactor PR; domain checklist not applicable. |
| L1 | Initial stop below base | NA | Pure infra / harness / refactor PR; domain checklist not applicable. |
| L2 | Trailing stop never lowered | NA | Pure infra / harness / refactor PR; domain checklist not applicable. |
| L3 | Stop triggers on weekly close | NA | Pure infra / harness / refactor PR; domain checklist not applicable. |
| L4 | Stop state machine transitions | NA | Pure infra / harness / refactor PR; domain checklist not applicable. |
| C1 | Screener cascade order | NA | Pure infra / harness / refactor PR; domain checklist not applicable. |
| C2 | Bearish macro blocks all buys | NA | Pure infra / harness / refactor PR; domain checklist not applicable. |
| C3 | Sector RS vs. market, not absolute | NA | Pure infra / harness / refactor PR; domain checklist not applicable. |
| T1 | Tests cover all 4 stage transitions | NA | Pure infra / harness / refactor PR; domain checklist not applicable. |
| T2 | Bearish macro → zero buy candidates test | NA | Pure infra / harness / refactor PR; domain checklist not applicable. |
| T3 | Stop trailing tests | NA | Pure infra / harness / refactor PR; domain checklist not applicable. |
| T4 | Tests assert domain outcomes | NA | Pure infra / harness / refactor PR; domain checklist not applicable. |

## Plan §D1–D5 design-decision pinning (additional verification)

| # | Decision | Status | Pinning test |
|---|----------|--------|--------------|
| D1 | Evaluator-as-callback (not hard-wired runner) | PASS | Structural — the `~evaluator` parameter is in the `run` signature; tests use three pure stubs (`_const_evaluator`, `_sum_evaluator`, `_table_evaluator`) demonstrating the decoupling. |
| D2 | Argmax averages across scenarios (not max-of-max or min-of-max) | PASS | `test_run_argmax_averages_across_scenarios` — Cell A: (1.0, 5.0) → mean 3.0; Cell B: (4.0, 4.0) → mean 4.0; B wins despite A's higher max. Definitively distinguishes mean from max-of-max. |
| D3 | Tie-break by enumeration order (first wins) | PASS | `test_run_tie_break_picks_first_cell` — all three cells return identical Sharpe=7.0; assertion: `best_cell = [("a", 1.0)]` (first in enumeration). |
| D4 | Empty spec → singleton empty cell, NOT zero cells; empty values → zero cells | PASS | `test_cartesian_empty_spec_yields_one_empty_cell` (asserts `elements_are [is_empty]` — exactly one cell, which is the empty list); `test_cartesian_with_empty_values_yields_zero_cells` (asserts `is_empty`). |
| D5 | Composite weights are raw (not normalised); negative weights work | PASS | `test_evaluate_objective_composite_weighted_sum` — explicit weights `(Sharpe, 1.0); (Calmar, 0.5); (MaxDrawdown, -0.1)` and metrics `(2.0, 3.0, -10.0)` produce 4.5 = 1.0×2.0 + 0.5×3.0 + (-0.1)×(-10.0). The negative weight contributes +1.0, pinning negative-weight semantics. |

## Quality Score

5 — All non-trivial mli claims pinned by tests; all five plan design decisions (D1–D5) explicitly pinned; tests assert domain outcomes (specific cells, scores, varied_values pairs, header substrings, sexp content) rather than just "no error"; tie-break and empty-spec edge cases pinned exactly. Two very minor gaps noted (the `best_score = Float.neg_infinity when rows empty` doc claim is internally unreachable via `run`, and the `cell_to_overrides` malformed-key Failure is reached only via underlying `parse_to_sexp` failure which tests avoid) — neither is a functional gap and the contract is substantially well-pinned. Determinism explicitly pinned via two-run identity assertion.

## Verdict

APPROVED

---

# Behavioral QC — Bayesian Phase 3 PR-A (PR #1126, scoring fn)
Date: 2026-05-16
Reviewer: qc-behavioral

## Behavioral Checklist — Bayesian Phase 3 PR-A (PR #1126, scoring fn)

### Contract Pinning Checklist (CP1–CP4)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in `bayesian_runner_scoring.mli` docstrings has an identified test that pins it | PASS | (a) Loss formula `score = -(-mean_sharpe + λ_dd*hinge + λ_gate*gate_penalty)` → identity case pins score = +mean_sharpe (`test_identity_candidate_equals_baseline`, 0.85), MaxDD-hinge-zero on improvement (`test_maxdd_hinge_zero_on_improvement`, score=1.2 when cand maxdd=10 < base maxdd=15), MaxDD-hinge-linear on excess (`test_maxdd_hinge_linear_on_excess`, score=0.5 = 1.0 - 0.10×5.0), combined-penalties arithmetic (`test_both_maxdd_and_gate_penalties_combine`, score = -9.4 = -(-1.0 + 0.10×4.0 + 1.0×10.0)). (b) `mean_sharpe` taken from `stability[v].sharpe_ratio.mean` "as-is" → identity test (no penalties) pins score = +sharpe_mean (0.85). (c) `mean_maxdd` taken from `stability[v].max_drawdown_pct.mean` → hinge tests pin it via differing maxdd_mean values. (d) `baseline_maxdd` read dynamically from `baseline_aggregate.stability[<baseline_label>].max_drawdown_pct.mean` → `test_maxdd_hinge_linear_on_excess` uses base=15.0 while `test_exactly_at_baseline_maxdd_zero_hinge` uses base=18.0, plus `test_missing_baseline_in_baseline_aggregate_returns_error` pins that lookup is in the baseline aggregate. (e) Gate Pass=0 / Fail=`_gate_penalty_value` → `test_gate_pass_vs_fail_score_difference` pins diff = 10.0 exactly. (f) Synthetic Fail (fold-pair count mismatch) collapses to same penalty → `test_synthetic_fail_treated_as_regular_fail` pins equality. (g) Error cases listed in `score_cell` docstring (lines 100–109): missing candidate in stability → `test_missing_candidate_in_stability_returns_error`; missing in verdicts → `test_missing_candidate_in_verdicts_returns_error`; missing baseline → `test_missing_baseline_in_baseline_aggregate_returns_error`; fold_count=0 → `test_zero_fold_aggregate_returns_error`. (h) `parameters` accepted but does not affect score → `test_parameters_do_not_affect_score`. (i) Hyperparameter constants pinned not overridable (mli lines 52, 56, 64, 70) → `test_hyperparameter_constants_pinned` asserts all four exact values. (j) Determinism (mli lines 111–113) → not pinned by explicit two-run identity, but the function is closed-form arithmetic with no side state; the identity case + parameters-invariance test are jointly sufficient to demonstrate same inputs → same output. |
| CP2 | Each claim in PR body "Test plan" section has a corresponding test in the committed test file | PASS | All 13 advertised coverage items present in `test_bayesian_runner_scoring.ml`: Identity case → `test_identity_candidate_equals_baseline`; MaxDD-hinge-zero on improvement → `test_maxdd_hinge_zero_on_improvement`; MaxDD-hinge-linear on Δpp excess → `test_maxdd_hinge_linear_on_excess`; Gate Pass vs Fail diff = -10.0 → `test_gate_pass_vs_fail_score_difference`; Synthetic Fail ≡ regular Fail → `test_synthetic_fail_treated_as_regular_fail`; Sharpe improvement strictly raises score → `test_sharpe_improvement_increases_score`; 3 Status.NotFound paths → three `test_missing_*_returns_error` tests; Status.Invalid_argument on zero-fold → `test_zero_fold_aggregate_returns_error`; Boundary at baseline MaxDD → `test_exactly_at_baseline_maxdd_zero_hinge`; Negative-Sharpe → `test_negative_sharpe_candidate_score_negative`; Combined penalties → `test_both_maxdd_and_gate_penalties_combine`; `parameters` no effect → `test_parameters_do_not_affect_score`; Constants pinned → `test_hyperparameter_constants_pinned`. Suite has exactly 15 entries (13 unique + 2 supporting boundary/negative-Sharpe cases); test runner reports 15/15 passing per qc-structural H3. |
| CP3 | Pass-through / identity / invariant tests pin identity (equal_to on value), not just size_is | PASS | `test_identity_candidate_equals_baseline` pins exact value `float_equal 0.85` on the score (whole-value identity). `test_parameters_do_not_affect_score` pins `float_equal` between the two scores under different `parameters` inputs (invariance). `test_synthetic_fail_treated_as_regular_fail` pins `float_equal s r` between the synthetic-Fail and regular-Fail scores. `test_maxdd_hinge_zero_on_improvement` pins exact `float_equal 1.2` (the candidate Sharpe pass-through when MaxDD penalty is clipped to 0). No `size_is`-only assertions on the result; all assertions are value-based. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | Documented guards in `.mli` and pinning tests: (1) "Error cases" enumerated on lines 100–109 — all four pinned by their corresponding `test_missing_*` / `test_zero_fold_*` tests using `is_error_with Status.NotFound` and `is_error_with Status.Invalid_argument`. (2) "Hyperparameters are pinned, not overridable" (line 52, etc.) — pinned by `test_hyperparameter_constants_pinned` AND indirectly cross-checked by the MaxDD-hinge-linear arithmetic which would fail if `_lambda_dd` differed from 0.10. (3) Synthetic Fail collapses to same penalty as regular Fail (line 48) — pinned by `test_synthetic_fail_treated_as_regular_fail`. (4) **Degenerate-fold floor deferred to per-fold path** (lines 27–34 in module docstring; lines 73–75 on `_degenerate_fold_floor_return_pct`) — the module-level docstring explicitly notes "the precomputed `stability[v].sharpe_ratio.mean` is used as-is" and "the exclusion is implemented at the upstream walk-forward harness when relevant". The `score_cell` per-function docstring (lines 111–113) reinforces this with "the aggregate's `[mean]` fields are already pre-reduced". The pass-through-on-mean-Sharpe contract is empirically pinned by `test_identity_candidate_equals_baseline` (input `sharpe_mean=0.85` → score `+0.85`, demonstrating the scorer consumes the aggregate's pre-reduced mean as-is with no further filtering). The module-level docstring sits at the head of the public contract of the only public function `score_cell`; CP4 considers this sufficient documentation at the public surface. |

### Behavioral Checklist (Weinstein-domain rows)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | Pure infra / tuner-side scoring; domain checklist not applicable. qc-structural A1 PASS confirms no domain logic leaked into core modules. |
| S1 | Stage 1 definition matches book | NA | Pure infra / tuner-side scoring; domain checklist not applicable. qc-structural A1 PASS confirms no domain logic leaked into core modules. |
| S2 | Stage 2 definition matches book | NA | Pure infra / tuner-side scoring; domain checklist not applicable. qc-structural A1 PASS confirms no domain logic leaked into core modules. |
| S3 | Stage 3 definition matches book | NA | Pure infra / tuner-side scoring; domain checklist not applicable. qc-structural A1 PASS confirms no domain logic leaked into core modules. |
| S4 | Stage 4 definition matches book | NA | Pure infra / tuner-side scoring; domain checklist not applicable. qc-structural A1 PASS confirms no domain logic leaked into core modules. |
| S5 | Buy criteria: Stage 2 entry on breakout with volume | NA | Pure infra / tuner-side scoring; domain checklist not applicable. qc-structural A1 PASS confirms no domain logic leaked into core modules. |
| S6 | No buy signals in Stage 1/3/4 | NA | Pure infra / tuner-side scoring; domain checklist not applicable. qc-structural A1 PASS confirms no domain logic leaked into core modules. |
| L1 | Initial stop below base | NA | Pure infra / tuner-side scoring; domain checklist not applicable. qc-structural A1 PASS confirms no domain logic leaked into core modules. |
| L2 | Trailing stop never lowered | NA | Pure infra / tuner-side scoring; domain checklist not applicable. qc-structural A1 PASS confirms no domain logic leaked into core modules. |
| L3 | Stop triggers on weekly close | NA | Pure infra / tuner-side scoring; domain checklist not applicable. qc-structural A1 PASS confirms no domain logic leaked into core modules. |
| L4 | Stop state machine transitions | NA | Pure infra / tuner-side scoring; domain checklist not applicable. qc-structural A1 PASS confirms no domain logic leaked into core modules. |
| C1 | Screener cascade order | NA | Pure infra / tuner-side scoring; domain checklist not applicable. qc-structural A1 PASS confirms no domain logic leaked into core modules. |
| C2 | Bearish macro blocks all buys | NA | Pure infra / tuner-side scoring; domain checklist not applicable. qc-structural A1 PASS confirms no domain logic leaked into core modules. |
| C3 | Sector RS vs. market, not absolute | NA | Pure infra / tuner-side scoring; domain checklist not applicable. qc-structural A1 PASS confirms no domain logic leaked into core modules. |
| T1 | Tests cover all 4 stage transitions | NA | Pure infra / tuner-side scoring; domain checklist not applicable. qc-structural A1 PASS confirms no domain logic leaked into core modules. |
| T2 | Bearish macro → zero buy candidates test | NA | Pure infra / tuner-side scoring; domain checklist not applicable. qc-structural A1 PASS confirms no domain logic leaked into core modules. |
| T3 | Stop trailing tests | NA | Pure infra / tuner-side scoring; domain checklist not applicable. qc-structural A1 PASS confirms no domain logic leaked into core modules. |
| T4 | Tests assert domain outcomes | NA | Pure infra / tuner-side scoring; domain checklist not applicable. qc-structural A1 PASS confirms no domain logic leaked into core modules. |

### Plan §3.1 + §7 PR-A pinning (additional verification)

| # | Plan claim | Status | Pinning test / location |
|---|------------|--------|-------------------------|
| F1 | `λ_dd = 0.10` (every 1pp of excess MaxDD costs 0.10 units of Sharpe-equivalent loss) | PASS | Pinned twice: (a) `test_hyperparameter_constants_pinned` directly asserts `_lambda_dd = 0.10`; (b) `test_maxdd_hinge_linear_on_excess` arithmetic Δ=5.0 → penalty=0.5 → score=0.5 only holds when λ_dd=0.10. |
| F2 | `gate_penalty_value = +10.0` for `Fail`, `0.0` for `Pass` | PASS | `test_gate_pass_vs_fail_score_difference` pins exact diff = 10.0 (score_pass − score_fail). `test_hyperparameter_constants_pinned` pins `_gate_penalty_value = 10.0`. `test_identity_candidate_equals_baseline` (Pass + identity) pins gate penalty = 0 when Pass. |
| F3 | `λ_gate = 1.0` (the +10.0 magnitude dominates marginal Sharpe) | PASS | `test_hyperparameter_constants_pinned` pins `_lambda_gate = 1.0`. The gate diff = 10.0 in F2 is consistent with `λ_gate × gate_penalty_value = 1.0 × 10.0`. |
| F4 | Synthetic Fail (fold-pair count mismatch) collapses to same penalty | PASS | `test_synthetic_fail_treated_as_regular_fail` constructs a `Fail { reason = "fold-pair count mismatch (synthetic)"; worst_fold = "(none)"; worst_gap = 0.0 }` and asserts the score equals the regular-Fail score. |
| F5 | MaxDD hinge is one-sided (only positive excess penalised; clipped to 0 below baseline) | PASS | `test_maxdd_hinge_zero_on_improvement` (candidate MaxDD 10 < baseline 15 → no penalty) and `test_exactly_at_baseline_maxdd_zero_hinge` (candidate MaxDD = baseline → hinge=0 at boundary). |
| F6 | Baseline read dynamically from baseline aggregate (not hardcoded) | PASS | (a) Different baseline values in different tests (15.0, 18.0) produce correct hinge boundaries — would fail if hardcoded. (b) `test_missing_baseline_in_baseline_aggregate_returns_error` confirms the baseline_label is looked up in `baseline_aggregate.stability` rather than substituted from candidate_aggregate. |
| F7 | Score returns `Status.status_or` (no panics on lookup failure) | PASS | Four error-path tests use `is_error_with Status.NotFound` / `is_error_with Status.Invalid_argument`. The implementation uses `Result.Let_syntax %bind` (`bayesian_runner_scoring.ml` lines 59–68) to thread errors; no `assert_failure` or exception path. |
| F8 | `_degenerate_fold_floor_return_pct = -50.0` declared but not consumed in PR-A (deferred to PR-C / per-fold path) | PASS (documented deferral) | Constant declared in `.ml` line 9, exposed in `.mli` line 68, with explicit deferral docstring (lines 70–75): "Reserved for the per-fold scoring path; the aggregate-only path here uses the aggregate's precomputed mean Sharpe directly. Documented in the mli so callers in PR-C can wire per-fold exclusion when the walk-forward harness surfaces per-fold returns to the scorer." Module-level docstring (lines 27–34) explicitly tells the caller "the precomputed `stability[v].sharpe_ratio.mean` is used as-is" and where the per-fold filter belongs. `test_hyperparameter_constants_pinned` pins the value -50.0. The PR body's "Out of scope" section also documents this deferral. The seam ownership (walk-forward harness owns the per-fold filter; scorer trusts pre-reduced aggregate) is documented at the public surface of the only public function. |

## Quality Score

5 — Every non-trivial `.mli` claim and every PR-body Test-plan item is pinned by an explicit test; the loss-formula constants are pinned both directly (constants test) and indirectly via exact arithmetic checks (MaxDD-hinge-linear, combined-penalties), giving the contract two independent failure surfaces if any constant drifts; the deferred-degenerate-fold-floor seam is explicitly documented at the public surface (module docstring + per-function docstring), with the pass-through-on-mean-Sharpe behavior empirically pinned by the identity test; all four error paths are pinned with `is_error_with` rather than untyped exception catches; synthetic-Fail-equivalence and parameters-invariance are pinned by float-equality between two scorer calls. Pure tuner-side policy (not Weinstein domain logic) — domain rows correctly NA.

## Verdict

APPROVED

---

Reviewed SHA (PR-B): fc6d69151aab2de2a21c96e70918855b2bbaf46f

## Structural Checklist — Bayesian Phase 3 PR-B (PR #1132, knob inventory + parameter space encoding)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | |
| H2 | dune build | PASS | |
| H3 | dune runtest | PASS | 47 tests across tuner/bin/test suite; all passed. PR-B adds +19 tests in test_bayesian_runner_bin.ml specifically for holdout_folds field and Phase-3 fixture; all pass cleanly. |
| P1 | Functions ≤ 50 lines (linter) | PASS | All changes are in test file (helpers + test cases), spec sexp parsing, and docstring additions. H3 passed; linter gates clean. |
| P2 | No magic numbers (linter) | PASS | H3 passed; linter gates clean. All parameter bounds in the new bayesian-multi-param-2026-05-16.sexp fixture are explicitly documented per track with plan citations. |
| P3 | Config completeness | PASS | The new bayesian-multi-param-2026-05-16.sexp is a spec file, not runtime config. All knob bounds are configurable (explicit in the 11-knob surface per plan §2.1). |
| P4 | Public-symbol export hygiene (linter) | PASS | H3 passed; mli-coverage gates clean. The single new public field (holdout_folds : int list option) is in Bayesian_runner_spec.t, documented in the .mli with full semantics (lines 62–70). |
| P5 | Internal helpers prefixed per convention | PASS | Test-only additions: _with_temp_dir, _write_spec_file, _spec_text, _ucb_spec_text, _spec_with_holdout_text, _spec_record_with_holdout, _parabola_evaluator, _parabola_spec, _tuner_fixtures_root, _tuner_fixture_path. All prefixed with underscore. |
| P6 | Tests conform to `.claude/rules/test-patterns.md` (presence + conformance) | PASS | 19 new tests in test_bayesian_runner_bin.ml plus 28 pre-existing tests (47 total). Tests use open Matchers; three sub-rules: (1) No List.exists + equal_to(true/false) — clean. (2) No let _ = result patterns — clean. (3) No bare match without Matchers — the test suite uses assert_that consistently with is_some_and, is_none, elements_are, equal_to, and all_of. One instance of assert_failure at line 403 is appropriate (fixture discovery error in test setup, not a test assertion). All assertions on parsed spec values use canonical matchers (is_some_and, elements_are, size_is, equal_to, field). |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) — FLAG if any found | PASS | No modifications to core modules. All changes under trading/trading/backtest/tuner/bin/, trading/trading/backtest/walk_forward/lib/ (spec parsing only), and trading/test_data/. |
| A2 | No new `analysis/` imports into `trading/trading/` outside established backtest exception surface | PASS | No new library imports in dune files. trading/trading/backtest/walk_forward/lib/spec now declares `[@@sexp.allow_extra_fields]` to permit extra sexp fields (holdout_folds); this is a parser-permissiveness directive, not a new import. No analysis/ imports added. |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | PR-B files align with plan §7 scope: (1) trading/test_data/walk_forward/cell_e_30fold_2026_05_16.sexp — edited to add holdout_folds field (9 LOC added, 1 removed, net +8 content); (2) trading/test_data/tuner/bayesian-multi-param-2026-05-16.sexp — new file with 77 LOC comment + spec; (3) bayesian_runner_spec.{ml,mli} — added holdout_folds field (1 LOC .ml, 9 LOC .mli docstring); (4) walk_forward/lib/spec.{ml,mli} — minimal: added `[@@sexp.allow_extra_fields]` (.ml) + clarifying docstring (.mli) explaining the directive exists for BO metadata; (5) test/dune — added deps clause for tuner fixtures; (6) test_bayesian_runner_bin.ml — added 189 LOC test code covering holdout_folds parsing + round-trip + Phase-3 fixture validation. No stray modifications. |

## Verdict

APPROVED

## Notes on design decisions

**holdout_folds field semantics (documented):** The new `holdout_folds : int list option` field in `Bayesian_runner_spec.t` (added to .mli lines 62–70) carries 1-indexed fold positions reserved as out-of-sample validation per plan §6.2. The sexp parser uses `[@sexp.option]` so absence parses as `None` (all folds in-sample) and presence as `Some [..]` (explicit holdout list). This is a shape-only PR — PR-B only pins the parsed structure; PR-C will thread the list into the walk-forward executor's fold filter, and PR-E will re-run the best cell on holdout folds for OOS validation. The documentation clearly defers the threading: "PR-B only PINS the parsed shape; PR-C will thread the list into the walk-forward executor's fold filter" (.mli line 68–69). This is acceptable at the structural layer — the seam is documented, and the contract is precise. qc-behavioral does not review this PR (pure infra/tuner) so behavioral acceptance gates are not relevant.

**11-knob curation vs. plan §2.1:** The Phase-3 fixture specifies 11 knobs (4 Track A, 3 Track B, 2 Track D, 2 Track E) plus metadata. Plan §2.1 proposed an 18-knob surface (Tracks A/B/C/D/E inclusive). The curation trim (omit Track C stage classifier, thin other tracks to high-confidence sensitivity) is documented in the fixture's preamble (lines 4–28) with explicit citations to plan §2.1, plan §5.2 (GP dimensionality ceiling ≤10 effective), and memory/project_m5-5-tuning-exhausted.md (stage classifier near-fixed). The knob count is pinned by `test_phase3_fixture_bounds_cover_expected_tracks` (assertions both on `size_is 11` and on the exact key list in expected order), providing a guard against silent drift.

**@sexp.allow_extra_fields justification:** The walk_forward/lib/spec.t now carries `[@@sexp.allow_extra_fields]` (spec.ml line 10) so the walk-forward runner's spec file can be augmented with BO metadata (holdout_folds) that the runner ignores but the BO scorer consumes. The .mli docstring (lines 15–21) explicitly documents this: "so spec files may carry metadata that the runner does not consume directly (e.g. a [holdout_folds] block used by the Bayesian tuner)". This is a benign permissiveness — the directive does not change the runner's behavior; it merely allows the spec sexp to carry extra fields. The cell_e_30fold_2026_05_16.sexp fixture demonstrates this by adding the holdout_folds field with a docstring explanation (lines 47–51) that the walk-forward runner ignores it but the BO scorer uses it.

---

# Behavioral QC — Bayesian Phase 3 PR-B (PR #1132, knob inventory)
Date: 2026-05-16
Reviewer: qc-behavioral

## Contract Pinning Checklist (CP1–CP4)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new `.mli` docstrings has an identified test that pins it | PASS | **bayesian_runner_spec.mli — new `holdout_folds` field (lines 62–70):** (a) "`Some [k1; ...; kn]` = 1-indexed fold positions reserved as OOS" → `test_holdout_folds_present_parses_to_some` pins `(holdout_folds (27 28 29 30))` → `Some [27;28;29;30]` via `elements_are`. (b) "`None` (or omitted from the sexp), the BO uses every fold as in-sample" → `test_holdout_folds_omitted_parses_to_none` pins omission → `is_none`. (c) Sexp shape examples lines 83–87 — "omit it entirely for `None`; write `(holdout_folds (k1 ... kn))` for `Some [k1; ...; kn]`; write `(holdout_folds ())` for `Some []`" → all three shapes pinned: omitted (`_omitted_parses_to_none`), populated (`_present_parses_to_some`), and empty-list (`_empty_list_parses_to_some_empty` distinguishes `Some []` from `None`). (d) "PR-B only pins the parsed shape; PR-C will thread the list" — explicit deferral; structural-only, no behavioral test required from PR-B. **walk_forward/lib/spec.mli — `[@@sexp.allow_extra_fields]` clause (lines 15–21):** "spec files may carry metadata that the runner does not consume directly (e.g. a `[holdout_folds]` block)" → empirically pinned by `Walk_forward_spec.test_30fold_spec_parses` (test_spec.ml:95) parsing the new cell_e_30fold_2026_05_16.sexp which now carries `(holdout_folds (27 28 29 30))` as an extra field; the test continues to PASS, which would not occur without the directive (would raise sexp parse error on the unknown field). |
| CP2 | Each claim in PR body "What it does" / commit message has a corresponding test in the committed test file | PASS | Commit message claims (full PR body unavailable — `gh` not in env, using commit message as authority): (1) "Extends the 4-D BO surface (PR #914) to an 11-knob curated multi-parameter surface" → `test_phase3_fixture_parses` pins `size_is 11` on bounds; `test_phase3_fixture_bounds_cover_expected_tracks` pins the exact 11-key list in order across all four tracks (A:4, B:3, D:2, E:2). (2) "adds the holdout-folds spec field that PR-C/E will consume" → six dedicated holdout_folds tests (`_present_parses_to_some`, `_empty_list_parses_to_some_empty`, `_omitted_parses_to_none`, `_round_trip_none`, `_round_trip_some`, `_round_trip_some_empty`). (3) "drops Track C... trims further to 11" → the key-list test directly enforces no Track C (stage classifier) knob appears. (4) "shape-only — no walk-forward integration yet" → empirically pinned by negation: the new field is parsed but `Bayesian_runner_evaluator.build` is unchanged (verified by structural QC A3, file list); no walk-forward executor changes in PR-B. **Plan §7 PR-B acceptance criterion** ("spec sexp parses without error; round-trip `sexp_of_t |> t_of_sexp` test pins the new field"): both halves pinned — `test_phase3_fixture_parses` for first half, three `_round_trip_*` tests for second half. |
| CP3 | Pass-through / identity / invariant tests pin identity (`elements_are [equal_to ...]` or `equal_to` on entire value), not just `size_is` | PASS | The three round-trip tests (`test_holdout_folds_round_trip_none/some/some_empty`) are identity tests by construction: they serialise then re-parse and assert the parsed value matches the original. (a) `_round_trip_none` asserts `is_none` (the only identity for a `None` value). (b) `_round_trip_some` asserts `elements_are [equal_to 27; equal_to 28; equal_to 29; equal_to 30]` — full element-by-element identity, not just count. (c) `_round_trip_some_empty` asserts `is_some_and (size_is 0)` — for an empty list, `size_is 0` IS the identity (an empty list has no elements to identify beyond its empty-ness; this is the canonical pattern). The fixture-level test `test_phase3_fixture_bounds_cover_expected_tracks` asserts the full 11-key list via `elements_are [equal_to "initial_stop_buffer"; ...; equal_to "screening_config.weights.w_strong_volume"]` — exact ordered identity, not just `size_is 11`. The `test_phase3_fixture_parses` also pins each scalar field's exact value (`initial_random = 25`, `total_budget = 100`, `seed = Some 2026`, `holdout_folds = Some [27;28;29;30]`) via `all_of [field ... equal_to ...]`. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | Documented guards / semantic boundaries in the new docstrings: (1) **`[@sexp.option]` semantics** — three distinct shapes (omitted → `None`; populated → `Some [..]`; empty → `Some []`) explicitly enumerated in the .mli lines 85–87. Each shape pinned by a dedicated test (three distinct cases above), with the empty-list case explicitly documented in the test's comment: "a present-but-empty list is distinct from an omitted field... an empty list should mean 'explicitly no holdouts', not 'default to all folds in-sample'" (test_bayesian_runner_bin.ml:326–330). This is the key semantic guard for PR-C's downstream consumption. (2) **`[@@sexp.allow_extra_fields]` directive on `walk_forward/lib/spec.t`** — the docstring (.mli lines 15–21) names the guarded scenario explicitly: "spec files may carry metadata that the runner does not consume directly". The guard is pinned empirically by `Walk_forward_spec.test_30fold_spec_parses` parsing the cell_e fixture with the extra `holdout_folds` field without error. (3) **1-indexed fold positions** — the .mli line 64 documents "1-indexed fold positions" and the fixture preamble (cell_e_30fold_2026_05_16.sexp:46–47) clarifies "last 4 folds (1-indexed 27-30, covering ~2024-04 to 2026-04 by anchor stride)". The 1-indexing convention is a documentary convention rather than a behavioral guard at the PR-B layer (no filter logic exists yet); PR-C will need to pin the indexing semantics when the fold filter is wired. Flagged for the PR-C reviewer but not failing at PR-B. (4) **Spec.load on malformed input raises `Failure`** (.mli line 90) — pinned by `test_load_malformed_raises`, which checks the exception message contains "failed to parse". (5) **11-knob count drift guard** — the fixture comment (lines 4–28) documents the curation rationale; `test_phase3_fixture_bounds_cover_expected_tracks` enforces both count and ordering, so any silent edit to the fixture will fail this test. |

## Behavioral Checklist (Weinstein-domain rows)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | Pure infra / tuner-side configuration plumbing (sexp surface + spec field). qc-structural A1 PASS confirms no domain logic leaked into core modules (Portfolio/Orders/Position/Strategy/Engine). The new `holdout_folds` field is metadata consumed only by the BO scorer in PR-C; it does not encode Weinstein domain rules. |
| S1 | Stage 1 definition matches book | NA | Pure tuner-side configuration plumbing; no stage classifier code touched. The fixture preamble explicitly drops Track C (stage classifier) per plan §2.1, so this PR adds zero stage-related logic. |
| S2 | Stage 2 definition matches book | NA | See S1. |
| S3 | Stage 3 definition matches book | NA | See S1. The `stage3_force_exit_config.hysteresis_weeks` knob is a tuning bound (1.0–5.0 weeks), not a stage definition; it is a Track D Cell E mechanic per plan §2.1 and is configurable by design. |
| S4 | Stage 4 definition matches book | NA | See S1. |
| S5 | Buy criteria: Stage 2 entry on breakout with volume | NA | No buy-signal logic in this PR. The `screening_config.weights.w_positive_rs` and `w_strong_volume` knobs (Track E) are scoring weights for the existing screener cascade; PR-B only pins their bounds (5.0–40.0), not their semantics. |
| S6 | No buy signals in Stage 1/3/4 | NA | See S5. |
| L1 | Initial stop below base | NA | `initial_stop_buffer` (0.5–2.0) and `candidate_params.initial_stop_pct` (0.04–0.15) are bounded but not implemented in PR-B. Bounds match the established sensitivity surface (memory/project_m5-5-tuning-exhausted.md). |
| L2 | Trailing stop never lowered | NA | No stop-loss code touched. |
| L3 | Stop triggers on weekly close | NA | No stop-loss code touched. |
| L4 | Stop state machine transitions | NA | No stop-loss code touched. |
| C1 | Screener cascade order | NA | No screener code touched; only weight-knob bounds added. |
| C2 | Bearish macro blocks all buys | NA | No macro-gate code touched. |
| C3 | Sector RS vs. market, not absolute | NA | No sector-analysis code touched. |
| T1 | Tests cover all 4 stage transitions | NA | Not applicable — tuner-side spec/encoding PR; no stage-transition tests required. |
| T2 | Bearish macro → zero buy candidates test | NA | Not applicable — see T1. |
| T3 | Stop trailing tests | NA | Not applicable — see T1. |
| T4 | Tests assert domain outcomes | NA | Not applicable — tests assert tuner-spec outcomes (parsed structure, fixture identity, round-trip correctness). These ARE the right outcomes for this surface; CP1–CP4 above confirm domain-equivalent rigour for the spec/encoding contract. |

## Plan §6.2 + §7 PR-B pinning (additional verification)

| # | Plan claim | Status | Pinning test / location |
|---|------------|--------|-------------------------|
| G1 | "The BO spec sexp must explicitly mark the held-out folds" (plan §6.2) | PASS | The Phase-3 fixture (`bayesian-multi-param-2026-05-16.sexp`:77) explicitly carries `(holdout_folds (27 28 29 30))`, pinned by `test_phase3_fixture_parses` field assertion. The cell_e fixture (cell_e_30fold_2026_05_16.sexp:51) also carries the same holdout marker (the field is shared on both sexp surfaces so PR-C/E can consume it from either side). |
| G2 | "hold out the last 4 folds (2024 + 2025) of the 30-fold spec" (plan §6.2) | PASS | The fixture pins exactly `(27 28 29 30)` (last 4 folds of the 30-fold spec); `test_phase3_fixture_parses` asserts the exact list via `elements_are`. The fixture comment (lines 47–48) cross-references plan §6.2 explicitly. |
| G3 | "~13% data-fraction holdout" (plan §6.2) | PASS (documented) | The fixture comment (line 48) states "~13% holdout per plan §6.2"; arithmetic 4/30 = 13.3% matches. No behavioral assertion required at this layer — the percentage is a documentary cross-reference. PR-E will need to verify the OOS Sharpe-gap rule (no-overfit hurdle ≤0.10) when the OOS validator lands. |
| G4 | "11-knob Track A+B+D+E surface, omitting Track C" (plan §2.1, §7 PR-B) | PASS | `test_phase3_fixture_bounds_cover_expected_tracks` pins the exact 11-key list in order. Track breakdown (4+3+2+2 = 11) is documented in the fixture preamble lines 13–28 with per-knob plan-§2.1 citations. No Track C (stage classifier) keys appear in the assertion list, which would FAIL if any leaked in. |
| G5 | "stay under Tuner.Bayesian_opt's effective ≤10-dimensional GP ceiling" (plan §5.2) | PASS (deferred boundary) | Bounds list contains 11 keys, which is 1 above the "≤10 effective" ceiling cited. The fixture preamble (lines 7–9) explicitly acknowledges this and frames the 11th dimension as "near the boundary" (the two Track E weights are both integers and rounded by `cell_to_overrides`, reducing effective dimensionality). This is a documented architectural tradeoff, not a contract violation. PR-D will need to verify the GP converges with 11 active dimensions; pinning the convergence behavior is deferred to PR-D's tests. |
| G6 | "round-trip `sexp_of_t |> t_of_sexp` test pins the new field" (plan §7 PR-B acceptance) | PASS | Three round-trip tests pin all three sexp shapes: `test_holdout_folds_round_trip_none`, `test_holdout_folds_round_trip_some`, `test_holdout_folds_round_trip_some_empty`. The `_none` case is the critical one — it pins that `[@sexp.option]` omits the field on serialisation and re-parses as `None` (not `Some []`), which is the semantic distinction the downstream walk-forward fold filter (PR-C) will rely on. |
| G7 | "spec sexp parses without error" (plan §7 PR-B acceptance) | PASS | `test_phase3_fixture_parses` loads `bayesian-multi-param-2026-05-16.sexp` via `Spec.load` (which raises `Failure` on parse error per .mli line 90). Test passes; fixture parses cleanly. The fixture-discovery helper (`_tuner_fixtures_root`) walks the cwd up to find `trading/test_data/tuner/`, matching the proven pattern in `Walk_forward.test_spec`. |
| G8 | Walk-forward spec carries optional BO metadata without breaking the runner (plan §7 PR-B implied) | PASS | `walk_forward/lib/spec.t` gains `[@@sexp.allow_extra_fields]` (spec.ml:10), documented in spec.mli lines 15–21. The cell_e_30fold fixture's new `holdout_folds` extra field parses via the existing `test_30fold_spec_parses` (walk_forward/test/test_spec.ml:95) — confirmed PASS via the full walk_forward test suite (7 tests, all green). The directive is benign permissiveness; it does not alter the runner's behavior. |

## Quality Score

5 — All non-trivial `.mli` claims (`holdout_folds` field shape, `[@sexp.option]` semantics, `[@@sexp.allow_extra_fields]` directive purpose, sexp shape examples) are pinned by tests with whole-value identity assertions; all three sexp shapes (None / Some [..] / Some []) are pinned both via parsing and via round-trip serialisation, distinguishing the `None` vs `Some []` semantics that PR-C/E will depend on; the production Phase-3 fixture pins the 11-knob curated surface with exact ordered keys (guards against silent drift); plan §6.2 + §7 PR-B acceptance criteria both halves pinned (parse + round-trip); `[@@sexp.allow_extra_fields]` directive empirically pinned by the existing `Walk_forward_spec.test_30fold_spec_parses` continuing to PASS on the augmented fixture. Pure tuner-side configuration plumbing — domain rows correctly NA. One minor documentary boundary flagged (G5: 11 knobs vs ≤10-dim GP ceiling) is acknowledged in the fixture preamble and deferred to PR-D for behavioral verification; not a contract violation at PR-B.

## Verdict

APPROVED
