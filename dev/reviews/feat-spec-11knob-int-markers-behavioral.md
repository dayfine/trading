Reviewed SHA: 4d950c53d0cd07f21a84503885e261b35bba5f6f

---

# Behavioral QC — feat-spec-11knob-int-markers
Date: 2026-05-23
Reviewer: qc-behavioral

## Classification

Pure experiment-spec / config PR. No source code, no domain logic, no .mli changes. Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely", the Weinstein S*/L*/C*/T* checklist is NA. Only the generic CP1–CP4 Contract Pinning Checklist applies.

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | NA | No .mli added in this PR. Spec file is data, not contract surface; the `Bayesian_runner_spec.t` schema lives in #1261 and is tested there. |
| CP2 | Each claim in PR body "Test plan" / "Test coverage" has a corresponding test | PASS | PR body Test plan has only two items: (a) `dune build` clean — qc-structural confirmed H2 PASS at this SHA; (b) sweep launch smoke-verifies int-knob plumbing — explicitly marked unchecked in PR body as the live verification step. No falsely-advertised tests. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size_is | NA | No tests; no pass-through semantics in scope. |
| CP4 | Each guard called out in code docstrings has a test exercising the guarded scenario | NA | No code docstrings. The (int) marker guard against `int_of_sexp` crash is documented in the spec's `;;` comment and pinned by the live sweep (running cleanly at parallel=4 — operational verification of #1258 + #1261 plumbing). |

## Spec content verification (informational)

Verified at SHA `4d950c53`:
- **Budget arithmetic**: PR body claims budget=60 / initial_random=15 — file matches (`(initial_random 15) (total_budget 60)`).
- **11 bounds**: PR claims 11 knobs — file has exactly 11 entries (4 Track A + 3 Track B + 2 Track D + 2 Track E).
- **4 (int) markers**: PR claims 4 int-typed knobs — file has exactly 4 `(int)` annotations on `stage3_force_exit_config.hysteresis_weeks`, `laggard_rotation_config.hysteresis_weeks`, `screening_config.weights.w_positive_rs`, `screening_config.weights.w_strong_volume`. Matches PR body list 1:1.
- **Holdout folds**: V3 comparability claim — `(holdout_folds (27 28 29 30))` matches.
- **Composite objective**: weights `SharpeRatio 0.40 + CalmarRatio 0.30 + MaxDrawdown -0.10` per spec; matches V3 / promote_config gate as claimed.
- **Wall-time estimate**: comment claims ~15h at parallel=4 (15 min/iter × 60 iters); arithmetic consistent with priorities-doc 12-15h estimate.
- **.gitignore**: single line `dev/experiments/bayesian-production-sweep-*/output-11knob*-parallel*/` added — pattern consistent with existing v*-parallel entries.

## Quality Score

5 — Pure experiment-spec PR with full traceability: every PR-body claim (budget, knob count, int markers, holdout folds, objective) maps exactly to file content. Spec header comments self-document hypothesis, stopping rule, and arithmetic. Operational verification (live sweep running without `int_of_sexp` crash) confirms int-knob plumbing path end-to-end.

## Verdict

APPROVED
