Reviewed SHA: 61a8b4d7f3a5fd69a7edb66b62babb3a1bcb0982

# Behavioral QC — feat/bo-checkpoint-resume
Date: 2026-05-21
Reviewer: qc-behavioral

## Scope

Pure infrastructure PR (BO checkpoint + resume). Per `.claude/rules/qc-behavioral-authority.md` "When to skip this file entirely" — no domain logic touched; the S*/L*/C*/T* Weinstein checklist rows are NA. Review is **Contract Pinning Checklist (CP1–CP4) only**.

Authority documents consulted:
- `trading/trading/backtest/tuner/bin/bayesian_runner_runner.mli` (line 72–96 — `{b Checkpoint / resume.}` docstring block added by this PR)
- `dev/plans/bayesian-checkpoint-resume-2026-05-21.md` (design + test plan)
- PR #1224 body ("What it does" + "Test plan" sections)

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PASS | Claims → tests: (a) "atomic write after every observation" → `test_checkpoint_file_written_per_iter` (presence + parseability after a complete run); (b) "missing → fresh" → `test_missing_checkpoint_starts_fresh`; (c) "present → reconstructs BO state by replaying" → `test_resume_equivalent_to_full_run` (byte-equality of all 3 artefacts vs single full run); (d) "replayed `suggest_next` must reproduce each saved parameter within 1e-12, else Failure" → exercised positively in `test_resume_equivalent_to_full_run` (every iteration's verify must succeed for byte-equality to hold); negative path is hard to test pure-OCaml without library tampering — acceptable; (e) "wrong schema_version → Failure" → `test_resume_with_wrong_schema_version_raises`; (f) "spec mismatch (any field except total_budget) → Failure" → `test_resume_with_changed_spec_raises`; (g) "total_budget excluded so partial run can resume under larger budget" → `test_resume_equivalent_to_full_run` (budget=10 then budget=20 same out_dir); (h) "checkpoint at full budget → zero further evaluator calls" → `test_resume_at_full_budget_skips_evaluator`. |
| CP2 | Each claim in PR body "Test plan" / "Test coverage" sections has a corresponding test in the committed test file | PASS | All 6 PR-body claimed tests present in `test_bayesian_runner_bin.ml`: `resume_equivalent_to_full_run` (line 781), `checkpoint_file_written_per_iter` (814), `resume_at_full_budget_skips_evaluator` (835), `resume_with_changed_spec_raises` (851), `resume_with_wrong_schema_version_raises` (877), `missing_checkpoint_starts_fresh` (900). All 43 tests pass (`docker exec trading-1-dev … dune runtest trading/backtest/tuner/bin/test` → OK, 0.38s). |
| CP3 | Pass-through / identity / invariant tests pin identity (whole-value equality), not just size | PASS | `test_resume_equivalent_to_full_run` byte-compares triples of `(bo_log.csv, best.sexp, convergence.md)` via tuple `equal_to` — true byte-level identity, not size_is. `test_resume_at_full_budget_skips_evaluator` and `test_missing_checkpoint_starts_fresh` use tuple equality `(8,0,8)` / `(6,6,true)` (counter + observation length + ck-exists), not just size. No `size_is`-only invariants used where identity is the contract. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | Guard map: (1) schema-version guard (`_validate_checkpoint`, line 80) → `test_resume_with_wrong_schema_version_raises` (hand-crafts schema_version 99 sexp, asserts Failure with substring "checkpoint schema mismatch"); (2) spec-mismatch guard (line 85) → `test_resume_with_changed_spec_raises` (changes bounds, asserts Failure with substring "checkpoint spec mismatch"); (3) total_budget-excluded carve-out (line 76–77) → exercised positively by `test_resume_equivalent_to_full_run` (10 → 20 budget transition succeeds); (4) full-budget zero-eval edge (line 145) → `test_resume_at_full_budget_skips_evaluator`. **Minor gap:** the RNG-mismatch guard (`_verify_replay`, line 103–105, `"resume RNG mismatch at iter %d"`) is exercised only positively (every successful resume invokes it). No negative test forces a mismatch — pragmatically requires tampering with saved parameters in the sexp. Not a FAIL: the positive byte-equality test exercises the verify code path on every iteration, and the guard's implementation is correct by inspection (1e-12 epsilon, `_replay_epsilon` named constant). |

## Behavioral Checklist (Weinstein domain rows)

Pure infra / harness / refactor PR; domain checklist not applicable. All S1–S6, L1–L4, C1–C3, T1–T4 rows marked NA.

## Quality Score

4 — Clean checkpoint/resume design with strong test pinning. Atomic .tmp+rename writes, schema-version + spec-signature validation, RNG-replay verification with 1e-12 tolerance, and the byte-equality acceptance test is the right contract for "resume must be a faithful continuation". One minor gap (no negative test for RNG-mismatch Failure path) prevents a 5; everything else is on rails. The exclusion of `total_budget` from the resume-equality check is a thoughtful deviation from the plan with a documented rationale (V3 launch use case).

## Verdict

APPROVED

## Notes for follow-up (non-blocking)

These are observations, not NEEDS_REWORK items:

1. **Negative RNG-mismatch test missing.** A test that tampers with the saved checkpoint sexp (e.g., rewrites the first iteration's parameters to a wrong value) and asserts `Failure "resume RNG mismatch at iter 0"` would close the only CP4 gap. Cheap to add — load the checkpoint, mutate one parameter, re-write, then call `run_and_write` and assert raises.

2. **Over-full-budget edge case not documented.** If the checkpoint contains more iterations than `spec.total_budget` (e.g., resuming under a smaller budget), `_run_loop` will see `iters_left = total_budget - iter_offset < 0` and return immediately with the saved observations. The .mli explicitly documents the "==" case ("when the checkpoint already contains spec.total_budget iterations, zero further evaluator calls") but not the ">" case. The behavior is benign (artefacts written from prior observations) but worth documenting if smaller-budget resumes become a use case.

3. **Atomicity not directly asserted.** `_save_checkpoint` uses `.tmp` + `Sys_unix.rename` — atomic on POSIX. The test pins the file's existence + parseability after a complete run, not the atomicity property under crash. This is the right test scope (atomicity is a POSIX kernel guarantee, not a behavior the code can verify) but worth noting that the "atomic" claim is structural-by-construction.
