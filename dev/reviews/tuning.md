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
