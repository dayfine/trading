Reviewed SHA: e98fb69b3a7f1e49653538ae9492670981d4dbfa

# Behavioral QC — fix-segmentation-epsilon (PR #1265)
Date: 2026-05-23
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | NA | No .mli touched. Diff is a 1-line tolerance bump + 2-line explanatory comment in a `_test.ml` helper. |
| CP2 | Each claim in PR body "Test plan" / "Test coverage" has a corresponding test | PASS | PR body Test plan claims `dune build && dune runtest analysis/technical/trend/` green in container. No new test claimed (the PR is itself a test-infra fix). The 4 existing call sites of `segment_equal` (lines 86, 95, 115, 230 of segmentation_test.ml) all continue to exercise the comparator against hardcoded expected slopes/r_squared/channel_widths (O(1) magnitudes — see lines 49-78, 101-103, 121-123, 193). |
| CP3 | Pass-through / identity / invariant tests pin identity (elements_are [equal_to ...]), not just size_is | NA | No pass-through semantics in this diff; existing comparator continues to assert whole-record equality via `List.equal segment_equal` (verified at the 4 call sites). |
| CP4 | Each guard called out in docstrings has a test exercising the guarded scenario | NA | Diff is itself a test-infra fix, not a new guard. The comment on lines 6-7 documents *why* epsilon was bumped (CI float-sum non-determinism observed at ~1e-8 on r_squared/channel_width — flake confirmed below); the existing 4 tests with hardcoded floats remain the coverage. |

### Flake-history verification

Confirmed via `gh run list --branch main --limit 10`:
- d31503fc — CI run 26325120891: **failure** (the one float-drift flake)
- d31503fc — perf-tier1, golden-runs-*, Main Watchdog: success
- 62f1d98 (next commit, same path touched): CI run 26325242921: **success**

One red sandwiched between green on the same source path matches the PR-body claim. Non-determinism, not a regression.

### Tolerance-bound verification

Expected values in `segmentation_test.ml`:
- `slope`: -1.0, 0.0, 1.0 (O(1))
- `r_squared`: 0.0, 1.0, 0.990269418573 (O(1), [0,1])
- `channel_width`: 0.0 ... O(1)

New epsilon 1e-6 is ~6 orders below typical magnitudes (~1.0). Observed drift was ~1.4e-8 / ~6.8e-8 — well inside the new bound, well above 1e-10. The claim "tolerates the observed drift by ~2 orders, still tight enough to catch real numeric bugs" holds: a real ~1% slope error (e.g. 1.0 vs 0.99) is 4 orders above the new epsilon and would still fail.

## Behavioral Checklist

Pure test-infra fix; Weinstein domain checklist not applicable per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely". All S*/L*/C*/T* rows: NA.

## Quality Score

4 — Correct diagnosis (CI vs host float-sum non-determinism), tight new bound, explanatory comment in-source. Minor nit: a follow-up to make `Regression` accumulation order-stable would eliminate the flake at root rather than papering over it, but that's appropriately scoped out of this PR.

## Verdict

APPROVED
