Reviewed SHA: 6fa9778d3bd7a5fa605db003db9b67780ffc8db5

# Behavioral QC — tuning/v3-smoke-and-reviews (PR #1226)
Date: 2026-05-21
Reviewer: qc-behavioral

PR classification: pure-data PR (sexp spec + 3 review-doc files; no OCaml
source). qc-behavioral's role here reduces to verifying that the sexp
header docstring matches both (a) the on-disk sexp body and (b) the
runner code it references.

## Re-review — 2026-05-21 (post review-feedback commit 6fa9778d)

### Context

Prior review (16478472) verdict: NEEDS_REWORK / Quality 2.
CP1 finding: docstring claimed a "smoke → resume into V3 production"
workflow that the runner's checkpoint guard would reject — smoke
sets `initial_random=2`, V3 sets `initial_random=10`, and
`_spec_for_resume_check` in `bayesian_runner_runner.ml` only excludes
`total_budget` from the spec-equality comparison.

The second commit 6fa9778d rewrites the header to drop the resume
claim entirely. Diff vs prior reviewed SHA is header-only; sexp body
unchanged.

### Contract Pinning Checklist (re-evaluation)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Header claims match on-disk implementation | PASS | New header makes 5 verifiable claims; all confirmed. See evidence below. |
| CP2 | PR body claims vs committed artifacts | PASS (carry-over) | Carried from prior review — PR body Test plan unchanged; sexp still parses; body still identical to V3 except budget+initial_random. |
| CP3 | Pass-through / identity invariants | NA | No pass-through semantics in this PR. |
| CP4 | Guard-claim test coverage | NA | The header now *invokes* an existing guard rather than claiming new behavior; the guard itself (checkpoint-spec mismatch) is already covered by `test_bayesian_runner_bin.ml:873` ("checkpoint spec mismatch" assertion). No new guard to cover. |

### CP1 evidence

Claim 1 — "Smoke differs from V3 on total_budget (2 vs 60)":
- Smoke `spec_prod_v3_smoke.sexp:32` → `(total_budget 2)`.
- V3 `spec_prod_v3.sexp:46` (on origin/main) → `(total_budget 60)`.
- PASS.

Claim 2 — "Smoke differs from V3 on initial_random (2 vs 10)":
- Smoke `spec_prod_v3_smoke.sexp:31` → `(initial_random 2)`.
- V3 `spec_prod_v3.sexp:45` → `(initial_random 10)`.
- PASS.

Claim 3 — "Bounds, objective, acquisition, seed, holdout_folds byte-identical to V3":
- Verified by inspection — both files declare identical bounds list, identical
  `(acquisition Expected_improvement)`, identical `(seed (2026))`,
  identical `(objective (Composite ((SharpeRatio 0.40) (CalmarRatio 0.30)
  (MaxDrawdown -0.10))))`, identical `(holdout_folds (27 28 29 30))`.
- PASS.

Claim 4 — "`_spec_for_resume_check` only excludes `total_budget`":
- `trading/trading/backtest/tuner/bin/bayesian_runner_runner.ml:76-77`:
  `let _spec_for_resume_check (spec : Bayesian_runner_spec.t) =
   { spec with total_budget = 0 }`
- The function zeros only the `total_budget` field; every other field
  (including `initial_random`) participates in the `Sexp.equal` check at
  line 85. PASS.

Claim 5 — "Resuming a smoke checkpoint with the V3 spec would raise
`Failure \"checkpoint spec mismatch\"`":
- Same file, line 86-87: `failwith "checkpoint spec mismatch — delete
  bo_checkpoint.sexp to start over"`. `failwith s` raises `Failure s`,
  so the exception payload literally begins with `"checkpoint spec
  mismatch"`. The docstring's quoted error string is a substring of
  the actual message (the runtime appends ` — delete bo_checkpoint.sexp
  to start over`); docstring's use of "would raise Failure \"checkpoint
  spec mismatch\"" is accurate as an identifying prefix.
- PASS.

### Behavioral Checklist

Pure data/docs PR; domain checklist not applicable. Marking all NA
with the standard explanatory note.

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification strategy-agnostic | NA | No core-module change. |
| S1–S6 | Stage definitions / buy criteria | NA | Pure tuning-spec data; no Weinstein logic. |
| L1–L4 | Stop-loss / state machine | NA | Same. |
| C1–C3 | Screener cascade | NA | Same. |
| T1–T4 | Domain-outcome tests | NA | Same. |

## Quality Score

4 — Fix is precise and minimal: header now self-consistent with the
runner's resume-guard contract, body untouched, and the docstring
explicitly names the function (`_spec_for_resume_check`) and the
hazard error string so future readers can verify the claim without
re-deriving it. Loses one point only because the originally-claimed
"smoke-then-resume" workflow would have been a real operator
convenience — the safer standalone path is correct but slightly less
ergonomic. That is a design trade-off, not a quality defect.

## Verdict

APPROVED

(Both CP1 and CP2 PASS; CP3/CP4 NA; behavioral checklist NA for
non-Weinstein data PR. The single FAIL from the prior review (CP1)
is resolved by the new docstring.)
