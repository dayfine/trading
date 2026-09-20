Reviewed SHA: 11f79ab6a548cf6333bb11007048cf644c540409

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | No format violations |
| H2 | dune build (full build) | PASS | Successful OCaml + shell build |
| H3 | dune runtest (all tests) | PASS | 76 test scenarios passed (record_qc_audit_test: 76 passed, 0 failed) |
| P1 | Functions ≤ 50 lines (linter) | PASS | Shell scripts; H3 linter suite passed |
| P2 | No magic numbers (linter) | PASS | Shell test file; H3 linter suite passed |
| P3 | Config completeness | NA | Shell test harness, not strategy config |
| P4 | Public-symbol export hygiene (linter) | NA | Not applicable to shell scripts |
| P5 | Internal helpers prefixed per convention | PASS | All shell function names follow project convention (_-prefixed internals) |
| P6 | Tests conform to project test-patterns | NA | Shell test suite; OCaml test-pattern rules (Matchers, assert_that) not applicable |
| A1 | Core module modifications | NA | Only shell test file and status doc; no core modules touched |
| A2 | analysis/→ trading/trading/ dependencies | NA | No dune files changed; no library dependencies introduced |
| A3 | No unnecessary existing module modifications | PASS | Only touching own feature files: dev/status/harness.md, trading/devtools/checks/record_qc_audit_test.sh |

### Claim Verification Summary

**Item 1 (H-AUDIT-27B-CUMULATIVE-COUNT):** ✓ VERIFIED
- Delta snapshot taken immediately before write_audit.sh (line 2007)
- Computed after call completes (lines 2016-2017)
- Immune to future scenarios writing into WALKUP_ROOT

**Item 2 (H-AUDIT-27B-LEAKS-UNDER-PWD-REGRESSION):** ✓ VERIFIED
- Scratch dir scoped to subshell (line 2010)
- Detection preserved (still hard-errors under $PWD regression)
- Cleanup before "after" snapshot (line 2014)

**Test Status:** ✓ All 76 scenarios pass, zero regressions

## Quality Score

5 — Surgical, well-motivated test-hygiene fixes with clear mutation-testing evidence and zero impact on production code.

## Verdict

APPROVED


---

## Behavioral QC — harness/audit-27b-residuals (PR #2874)

Reviewed SHA: 11f79ab6a548cf6333bb11007048cf644c540409

Environment: GHA runner (`$TRADING_IN_CONTAINER=1`), own detached worktree
`/__w/trading/wt-qc2874`. No docker. Book unreachable (macOS-local path) — not
needed, no `BOOK-CHECK-NEEDED` items arose.

Every claim below was **re-derived independently**, not accepted from the PR
body. All mutations were applied to **copies** under `/tmp`; the real
`write_audit.sh` / `record_qc_audit.sh` were never edited (`git status
--porcelain` on them clean throughout), and the live `dev/audit/` was restored
to its starting 195 files after each probe.

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new `.mli` docstrings has an identified test that pins it | NA | Shell-only PR (`record_qc_audit_test.sh` + `dev/status/harness.md`). No `.mli` added or touched. |
| CP2 | Each claim in the PR body / status-file closing notes has a corresponding committed test or re-derivable evidence | PASS | All six substantive claims re-derived below (item-1 hazard, item-2 preserved-RED, leak-eliminated, counts, suite-green, production-untouched). The PR body is unusually honest — it **proactively discloses** that sibling scenarios leak under the same mutation rather than presenting 27b's clean result as a whole-suite result. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size | NA | No pass-through semantics. (Observation, not a finding: the delta form counts files in `WALKUP_ROOT/dev/audit` and so would read 1 for a *differently-named* record too — but placement, not filename, is 27b's contract, and `rc=0` + `^OK: wrote` + scenario 27's `target_count27`/`walkup_count27` assertions bound it. Same exposure as the pre-fix absolute count; not a regression.) |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | Both new guard claims in the 27b comment block are real and hold — I exercised each (probes P1/P2 below). Neither is pinned by a *committed* test, only by PR-body prose; see residual R2874-B. Not a FAIL: 27b itself is the committed pin for the walk-up branch, and the delta-immunity is true by construction. |

## Behavioral Checklist (Weinstein domain)

Pure infra / harness / refactor PR; domain checklist not applicable. All
A1 / S1–S6 / L1–L4 / C1–C3 / T1–T4 rows **NA** per
`.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely".
qc-structural did not flag A1; no core module or domain logic is touched.

## Verification log

**Baseline** (`bash trading/devtools/checks/record_qc_audit_test.sh`, from the
PR worktree): `rc=0`, `76 passed, 0 failed`; live `dev/audit/` 195 → 195,
`git status --porcelain dev/audit` empty. `dune runtest devtools/checks`
exit **0**.

### P1 — Item 2, the preserved-RED re-derivation (the one that matters)

K4 mutation applied to a `/tmp` **copy** of the checks tree:

```
-  dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
+  dir="$(pwd)"
```

Suite invoked with cwd = the real checkout (the normal case), so a
`$PWD`-resolving walk-up reaches the live repo root via `.claude`.

| | scenario 27b result | live `dev/audit/` |
|---|---|---|
| **PRE-fix** (`origin/main` test script, same mutated `write_audit.sh`) | `FAIL ... got rc=0, walkup_count=0` | 195 → 198, **including `2026-08-06-harness-repo-root-repo-root-walkup.json` (27b's own leak)** |
| **POST-fix** (PR tip, identical mutation) | `FAIL ... (before=0, after=0, delta=0); got rc=1` + `FAIL: could not locate repo root` | 195 → 197, **27b's record absent** |

**Detection is preserved, not silenced** — 27b is still RED under K4, now via
`rc=1` + the hard `could not locate repo root` error instead of a
wrong-placement count, and its stray record no longer appears in the live
`dev/audit/`. This is the failure mode the dispatch brief flagged (a fix that
removes the leak by removing the detection), and it is **not** present here.

### P2 — the delta cannot be gamed to a false green

Mutated a copy so the record is removed immediately before the `OK: wrote`
line (preserving `rc=0` and the `OK:` line, so only the count assertion can
catch it):

```
FAIL: scenario 27b — expected rc=0 + 'OK: wrote' + exactly 1 NEW record under
WALKUP_ROOT (before=0, after=0, delta=0); got rc=0
```

A no-write mutation still reddens the scenario. The `before` snapshot is taken
after all fixture setup and immediately before 27b's own invocation, so
`delta == 1` remains a genuine assertion that 27b itself produced exactly one
record.

### P3 — Item 1, the future-scenario hazard

Injected an extra write into `WALKUP_ROOT/dev/audit` immediately before 27b, on
both the pre- and post-fix scripts:

- PRE-fix (cumulative): `FAIL ... got rc=0, walkup_count=2` — mis-FAILs though
  27b's own behaviour is correct.
- POST-fix (delta): **PASS** under the identical hazard.

Reproduces the author's quoted evidence exactly, including the `walkup_count=2`
value.

### P4 — the `cd` cannot leak

Instrumented a copy to print `$PWD` around the scenario:

```
PWDPROBE before-27b:    /__w/trading/wt-qc2874
PWDPROBE after-27b:     /__w/trading/wt-qc2874
PWDPROBE post-cleanup:  /__w/trading/wt-qc2874
```

The `cd` is confined to the `$(...)` subshell — observed, not merely inferred
from the parens. Independently, running the real suite from an unrelated cwd
(`/tmp`) still yields `76 passed, 0 failed`, so no scenario after 27b depends
on the suite's cwd. `SCRATCH27B` is cleaned up (`rm -rf`); no
`/tmp/write_audit_27b_scratch.*` directories survive a run.

### P5 — counts, spot-checked mechanically

Derived counts (from the suite's own `_derived_scenario_report`, not
hand-transcribed) are **identical** pre and post: 76 assertions / 76 labels /
63 `# Scenario` headers / 64 distinct scenario numbers. Matches the PR body's
table exactly. Production `write_audit.sh` / `record_qc_audit.sh`: zero diff
vs `origin/main`, re-confirmed.

### P6 — status-file honesty

`dev/status/harness.md` flips both items to `- [x]`, each with a closing note
that accurately describes what shipped, and refreshes `## Last updated:`
2026-08-21 → 2026-09-20 (wanted — today's track pacer flagged that field as 30
days stale). Both notes are explicitly **27b-scoped** ("Against the POST-fix
scenario..."), which is the correct scope: the sibling leaks below are other
scenarios, not this item. No overstatement found.

## Non-blocking residuals (filed, not blocking)

### R2874-A: the `$PWD`-walk-up leak class is closed for 27b but still open for 28b and 30c
- Finding: under the same K4 mutation, the post-fix suite still leaks **two**
  records into the live `dev/audit/` (195 → 197) from scenarios **28b**
  (`record_qc_audit_test.sh:2153`, `env -u REPO_ROOT` with no scratch cwd) and
  **30c** (`:2247`, `REPO_ROOT=""`, which `_repo_root()` treats as unset and
  therefore also reaches the walk-up). 27b's own record is gone, so this PR's
  item is genuinely closed.
- Not a defect in this PR: the dispatch brief scoped it to 27b, the item text
  is 27b-scoped, and **the PR body already discloses this** ("a handful of
  *other*, out-of-scope scenarios (28b, 29-31) ... leaked under the same
  mutation"). My measurement confirms the disclosure and narrows it to 28b/30c.
- One small inaccuracy: the body calls them "separate `H-AUDIT-*`
  residuals/tracks", but no such residual currently exists in
  `dev/status/harness.md`. This entry is that residual.
- Fix shape: apply the identical scratch-cwd treatment to 28b and 30c (a
  two-line change each, mirroring 27b), or hoist it into a small shared helper.
- `harness_gap: LINTER_CANDIDATE` — "every `env -u REPO_ROOT` / `REPO_ROOT=\"\"`
  invocation of an in-tree `write_audit.sh` must run from a scratch cwd" is a
  greppable invariant over this one file.

### R2874-B: 27b's two guard claims are pinned by PR-body prose, not by a committed test
- Finding: the new comment block asserts (a) delta-immunity to a future
  `WALKUP_ROOT` writer and (b) preserved detection under a `$PWD` walk-up
  regression. Both are true — I verified each — but the evidence lives in the
  PR body and in this review, and evaporates. This same file already carries a
  **committed mutation harness** for `pr_gate_status` ("19 mutation(s) match
  pin — 14 killed / 4 live survivor / 1 equivalent mutant"), so the precedent
  and the machinery both exist in-repo.
- Fix shape: add the K4 and no-write mutations to a committed mutation harness
  in the `pr_gate_status` style, so "27b stays RED under a `$PWD` regression"
  is pinned mechanically rather than re-derived by each reviewer.
- `harness_gap: LINTER_CANDIDATE` — deterministic mutation-kill assertions.

## Quality Score

5

Exemplary. The fix does exactly what it claims, closes both residuals at their
stated scope without weakening detection, carries mutation evidence that
reproduces verbatim under independent re-derivation, leaves production code at
zero diff, and the PR body volunteers the limits of its own result (the
sibling-scenario leaks) instead of letting a 27b-scoped clean number read as a
whole-suite one. That disclosure is the behaviour this review most wants to see.

## Verdict

APPROVED
