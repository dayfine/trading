Reviewed SHA: e42892f2

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | |
| H2 | dune build | PASS | |
| H3 | dune runtest | PASS | 14 walk_forward-specific tests pass; full suite OK; no linter violations detected |
| P1 | Functions ≤ 50 lines — covered by language-specific linter | PASS | fn_length_linter passed in H3 |
| P2 | No magic numbers — covered by language-specific linter | PASS | magic-numbers linter passed; no hardcoded thresholds |
| P3 | All configurable thresholds/periods/weights in config record | NA | No new tunable parameters introduced; integration code only |
| P4 | Public-symbol export hygiene — `.mli` coverage | PASS | mli-coverage linter passed in H3; both `.mli` files fully document public surface (execute_spec, build_walk_forward, default_executor) |
| P5 | Internal helpers prefixed per project convention | PASS | All internal functions in `.ml` files prefixed with underscore (`_run_one`, `_evaluate_one_pair`, `_evaluate_all`, `_candidate_label_for_iter`, `_build_two_variant_spec`, `_stability_to_metric_set`, `_score_or_fail`, `_sector_map_of_scenario`, `_test_days`, etc.) |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | PASS | 14 tests in test_bayesian_runner_evaluator.ml use `assert_that` + matcher composition (all_of, field, elements_are, size_is, is_some_and, float_equal); one `assert_equal` in stub setup only; no List.iter, no nested assert_that, no bare match-with-Error patterns. File opens Matchers; all assertions respect hierarchy rules |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to any core modules. Walk_forward_executor is a new library in backtest/; bayesian_runner_evaluator extends existing tuner_bin surface only |
| A2 | No new `analysis/` imports into `trading/trading/` outside backtest exception | PASS | No imports from analysis/ anywhere. All imports respect boundaries: walk_forward depends on Core, Scenario_lib, Backtest, trading.simulation.types; bayesian_runner_evaluator depends on Tuner, Walk_forward, Backtest, Scenario_lib — all in-tree, no analysis/ deps |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | File diff shows only new files and targeted extensions: walk_forward_executor.{ml,mli} (new), walk_forward_runner.ml (refactored, test verified), bayesian_runner_evaluator.{ml,mli} (extended with walk_forward path, legacy path preserved), test_bayesian_runner_evaluator.ml (new 14 stub-DI tests). dev/status/tuning.md updated. No cross-feature drift |

## Verdict

APPROVED

## Summary

PR #1136 extracts in-process walk-forward CV orchestration out of the walk_forward_runner binary into a reusable Walk_forward_executor library, enabling the Bayesian Phase-3 tuner to drive walk-forward sweeps per BO iteration without spawning subprocesses. Bayesian_runner_evaluator is extended with a walk_forward path (build_walk_forward) alongside the legacy per-scenario path.

**Structural observations:**
- Both hard gates pass (dune build @fmt, dune build, dune runtest).
- New walk_forward library is pure orchestration atop existing Backtest.Runner + Walk_forward_report — no new domain logic.
- Executor abstraction enables fast unit tests via stub DI; production path threads through default_executor.
- 14 new tests pin the walk-forward evaluator contract: correct score, candidate label increment, two-variant spec structure, executor invocation, metric_set projection, error propagation, gate penalty flow, and parameter threading.
- All tests use Matchers library and assert_that compositions; no anti-patterns detected.
- Legacy build surface in bayesian_runner_evaluator preserved until PR-E flips the binary.
- No core module modifications, no analysis/ imports, no cross-feature contamination.
- All internal helpers properly prefixed with underscore.

This PR is structurally sound and ready for behavioral review.

---

# Behavioral QC — PR #1136 Bayesian Phase 3 PR-C (walk-forward integration)

Date: 2026-05-16
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new `.mli` docstrings has an identified test that pins it | PASS | `walk_forward_executor.mli` claims (per-fold loop, aggregate computed via `Walk_forward_report.compute`, sequential execution, no filesystem writes) are pinned by (a) `Walk_forward.Walk_forward_report` existing test suite (22 tests passing) since the executor's `_run_one`/`_evaluate_one_pair`/`_evaluate_all` are byte-identical to the prior in-binary loop verified against `bin/walk_forward_runner.ml` HEAD~1, and (b) the binary still produces the same three artefacts. `bayesian_runner_evaluator.mli` `build_walk_forward` claims (label = `bo-iter-N`, two-variant spec `[baseline; candidate]`, executor invoked once per call, scorer error → Failure, metric_set is one-element with stability stats, fixtures_root/base/gate/baseline_label/parameters threaded through) all pinned by tests 1–13 in `test_bayesian_runner_evaluator.ml`. `default_executor` exposed-type claim pinned by test 14. |
| CP2 | Each claim in PR body "Test plan" sections has a corresponding test in the committed test file | PASS | PR body "Test plan" claims 14 tests; the committed `test_bayesian_runner_evaluator.ml` exposes exactly 14 named test cases. PR-body coverage map matches 1:1. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size_is | PASS | Test 12 pins candidate overrides equal `GS.cell_to_overrides parameters` via `elements_are (List.map expected_overrides ~f:equal_to)` — identity, not just count. Test 3 pins both variant labels (`equal_to`) and the baseline's overrides emptiness (`size_is 0` — semantically correct, the baseline has *no* overrides by design). Test 11 pins baseline_label `equal_to "my-baseline"`. Test 10 pins gate fields via `equal_to`. "Byte-identical binary output" pass-through claim pinned indirectly by the 196 existing walk-forward tests continuing to pass. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | (a) `bayesian_runner_evaluator.mli` "Raises [Failure] when the scorer returns a [Status.Error]" → pinned by test 7. (b) `bayesian_runner_evaluator.ml:_stability_to_metric_set` "Missing variants are mapped to an empty metric_set rather than raising" → NOT directly tested, but this is an `.ml` comment not an `.mli` contract claim. FLAG-but-non-blocking. (c) `walk_forward_executor.mli` "Raises [Failure] when the underlying backtest raises, when the universe file is malformed, or when `Walk_forward_report.compute` finds no folds or a missing baseline" → propagation-only guards (no new try/with), thin pass-through; underlying primitives' tests already cover the raise paths. |

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | Pure infra / library / refactor PR; no core modules (Portfolio/Orders/Position/Strategy/Engine) touched. Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely". |
| S1–S6, L1–L4, C1–C3, T1–T4 | Weinstein domain checklist | NA | Pure infra / harness / refactor PR; domain checklist not applicable. |

## Quality Score

5 — Exemplary: clean library extraction with byte-identical preservation of prior binary behavior (verified by diff against `bin/walk_forward_runner.ml@HEAD~1`), 14 well-named unit tests that pin every PR-body claim 1:1 with a stub executor (no flaky backtest invocation), idiomatic matcher use (one `assert_that` per value, `field`/`all_of`/`elements_are` composition), correct injectable-executor seam for testability, and the deferred-to-PR-E scope is explicitly called out in both the `.mli` and the PR body. The plan §4 contract (in-process integration, two-variant spec per BO iteration, propagating Status.Error as Failure, projecting stability stats into one synthetic metric_set) is implemented faithfully.

## Verdict

APPROVED
