Reviewed SHA: b65a9e463f0af10a6d403211a42c292a166ddd6b

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | |
| H2 | dune build | PASS | |
| H3 | dune runtest | PASS | 253 tuner tests pass (32 new: 18 lib + 14 runner) |
| P1 | Functions ≤ 50 lines — covered by dune runtest linter | PASS | fn_length_linter passed; all new functions well within limits |
| P2 | No magic numbers — covered by dune runtest linter | PASS | magic_numbers linter passed |
| P3 | All configurable thresholds/periods/weights in config record | PASS | `acceptance_threshold = 0.7` exposed as named constant in .mli; no hardcoded magic values in code |
| P4 | Public-symbol export hygiene (mli coverage) — covered by dune runtest linter | PASS | mli_coverage linter passed |
| P5 | Internal helpers prefixed per convention | PASS | All private helpers prefixed with underscore: `_ranks`, `_mean`, `_pearson_sums`, `_pearson_from_sums`, `_metric_of`, `_filter_variant`, `_make_fold_name_table`, `_try_make_pair`, `_usage_msg`, `_min_matched_folds` |
| P6 | Tests conform to `.claude/rules/test-patterns.md` (matcher composition + no nested asserts) | PASS | Both test files (18 + 14 new tests) use `assert_that` + matcher composition correctly; no `List.exists equal_to (true\|false)`, no `let _ = ...\.run`, no bare `match` with `assert_failure` on Ok; some `assert_bool` on string properties (allowed) |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) — FLAG if any found | PASS | No modifications to core modules; work is entirely within `trading/trading/backtest/tuner/` |
| A2 | No new `analysis/` imports into `trading/trading/` outside backtest exceptions | PASS | No `analysis/` imports; work is self-contained within tuner lib |
| A3 | No unnecessary modifications to existing non-feature modules | PASS | File list bounded to: `trading/trading/backtest/tuner/{lib,bin,test,bin/test}/*` for new modules + dune edits, `dev/notes/t1-4-calibration-procedure-2026-05-26.md`, `dev/status/tuning.md`. No other files touched. `compile_commands.json` modified in working tree only (not in PR diff) as expected build side-effect. |

## Verdict

APPROVED

All structural gates pass. Code is well-organized, test patterns conform to project conventions, and the PR scope is clean with no cross-cutting changes. Refactor commit (nesting-linter compliance) brings matched_pairs and _pearson within limits. Ready for behavioral review.

---

# Behavioral QC — tuning/m1-t1-4-proxy-calibration
Date: 2026-05-26
Reviewer: qc-behavioral

Infrastructure/tuner PR — S*/L*/C*/T* domain checklist marked NA per
`.claude/rules/qc-behavioral-authority.md` §"When to skip this file
entirely". Generic Contract Pinning Checklist (CP1–CP4) is the full
review surface.

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PASS | 17 claim → test pairs verified across `proxy_calibration_lib.mli` and `proxy_calibration_runner.mli` — see PR-review comment for the full mapping (Spearman ρ formula, mid-rank ties, range, edge cases, length-mismatch raise, matched_pairs fold-name join, silent-drop, variant-filter, metric dispatch, classify boundary `>=`, NaN→Fail, load_fold_actuals shape + missing-file raise, run_calibration < 2 raise, parse_args defaults, metric_arg_of_string case-insensitivity). |
| CP2 | Each claim in PR body "Test plan" sections has a corresponding test | PASS | PR body advertises 18 lib + 14 runner tests; both numbers match the committed suites. Each sub-bullet claim was verified by test name. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size_is | PASS | `spearman_identical` asserts ρ=1.0 via float_equal; `matched_pairs_subset` + `matched_pairs_metric_dispatch` + `matched_pairs_variant_filter` use `elements_are [equal_to ({...} : fold_pair); ...]` — full-record identity for every element, not size only. |
| CP4 | Each guard called out in docstrings has a test exercising the guarded scenario | PASS | 6 guard claims, all pinned: (a) length-mismatch raise → `test_spearman_length_mismatch`; (b) zero-variance → 0.0 → `test_spearman_zero_variance`; (c) NaN→Fail → `test_classify_nan`; (d) run_calibration <2 matched → `test_run_calibration_disjoint_raises`; (e) missing-file raise → `test_load_fold_actuals_missing`; (f) variant-filter against last-writer-wins on duplicate fold_names → `test_matched_pairs_variant_filter` + `test_run_calibration_multi_variant_filtered`. |

## Design call evaluation — fold_actuals.sexp vs aggregate.sexp

Acceptable. Switching from `aggregate.sexp` (cross-fold summary stats) to
`fold_actuals.sexp` (raw per-fold rows) is the technically correct fix —
Spearman ρ requires per-fold samples, not aggregate means. The producer
adapter already exists on main: `walk_forward/bin/walk_forward_runner.ml:111`
writes `fold_actuals.sexp` as a sibling of `aggregate.sexp` via
`_write_fold_actuals ~out_dir`. Both the `.mli` docstrings
(`proxy_calibration_runner.mli` lines 10–16) and the procedure note
(`dev/notes/t1-4-calibration-procedure-2026-05-26.md` §"Why fold_actuals.sexp,
not aggregate.sexp") spell out the rationale + the exact producer.
`harness_gap`: none — no adapter is missing.

## Quality Score

5 — Exceptional contract pinning. Every non-trivial `.mli` claim, every
PR-body test claim, every guard, and every edge case is pinned by a
dedicated test. Hand-computed Spearman values (0.5 / 0.3 / ~0.9487) all
re-verified. Boundary semantics (`Pass` on `>=`) verified — opposite to
T1.5's `>` semantics per each plan. Design call (fold_actuals.sexp) is
the correct fix and well-documented.

## Verdict

APPROVED

PR review: https://github.com/dayfine/trading/pull/1329#pullrequestreview-4365121121
