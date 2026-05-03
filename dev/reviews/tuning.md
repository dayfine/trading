Reviewed SHA: bdaaec17fda7e991d99d3be53faf7386f8deca06

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
