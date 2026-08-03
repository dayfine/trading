Reviewed SHA: c5e06533809855f794b2b62995bb0b003f339600

# QC review — harness track

PR #2184 `harness/prev-verdict-pipefail` (H-PREV-VERDICT-PIPEFAIL). MERGED `94343ea0`.

> **Recovered from GitHub.** The on-disk copies of these three reviews were destroyed
> mid-run by shared-working-tree churn (concurrent agents branch-switching in the single
> GHA checkout). They survived only because the orchestrator posted each one to the PR via
> the REST API immediately after the reviewing agent returned. Restored here verbatim from
> `GET /pulls/2184/reviews`. See the 2026-08-03 run-2 daily summary §Escalations.

---

<!-- github review id 4844920871, state COMMENTED -->

Reviewed SHA: 1bfbb38e54b37e4a5237ba1efb05fc7a4d57ec10

## Structural QC — harness/prev-verdict-pipefail (PR #2184)

### Context

Closes H-PREV-VERDICT-PIPEFAIL. Pure shell/harness PR — 3 files, +161/-3
(`trading/devtools/checks/write_audit.sh`, `trading/devtools/checks/record_qc_audit_test.sh`,
`dev/status/harness.md`). No OCaml touched. Reviewed by ref only
(`git fetch` + `git diff`/`git show` against `origin/main...1bfbb38e`) —
no `jj edit`/`git checkout` performed, per the shared-tree read-only constraint.

Build-gate baseline (main @ merge-base `b4b7a3d0`) reported green by the
dispatcher (`dune build` 0, `dune runtest` 0, `status_file_integrity.sh` 0) —
not repeated here. Independently re-verified the PR's own test claim by
extracting `write_audit.sh` + `record_qc_audit_test.sh` (PR tip) plus the
unmodified `record_qc_audit.sh` (main) into an isolated temp directory
(no shared-tree writes) and running the suite directly:

```
record_qc_audit_test: 24 passed, 0 failed   (PR tip — scenarios 1-22 incl. new 21/22)
```

Then reproduced the author's change-detection claim independently (reverted
only `write_audit.sh` to `origin/main`'s pre-fix shape, kept the new test
file):

```
record_qc_audit_test: 22 passed, 2 failed   (pre-fix write_audit.sh)
  FAIL: scenario 21 — got rc=0/1, consecutive_rework_count=1 (not 2)
  FAIL: scenario 22 — got rc=0/2, consecutive_rework_count=1 (not 2)
```

This matches the PR body's reported 22/2 → 24/0 transition exactly. Scenarios
21/22 are real, non-vacuous assertions — they fail hard against the pre-fix
code and pass against the fix.

### Guard-logic trace (write_audit.sh, NEEDS_REWORK escalation path)

```
prev_grep_status=0
prev_verdict=$(grep -o '...' "$f" 2>/dev/null | head -1 | sed '...') || prev_grep_status=$?
case "$prev_grep_status" in
  0) [ -n "$prev_verdict" ] || continue ;;   # matched-but-empty defensive skip
  1) continue ;;                             # no match — truncated/malformed record
  *) echo "WARNING: ..." >&2; continue ;;    # grep exit >1 — unreadable target
esac
if [ "$prev_verdict" = "NEEDS_REWORK" ]; then CONSECUTIVE=$((CONSECUTIVE + 1)); else break; fi
```

- Under `set -o pipefail`, a pipeline's exit status is the last command to
  exit non-zero (here always `grep`, since `head`/`sed` cannot fail on this
  input) — so `$prev_grep_status` faithfully reflects grep's own exit code.
  Verified directly: `grep -o '...' <directory>` on this container's GNU
  grep 3.7 exits 2 ("Is a directory"), confirming scenario 22's fixture
  (a directory at the `*-<feature>.json` glob path) is a sound, portable,
  root-safe way to force the "unreadable" branch without relying on chmod
  (which root would bypass, as the PR notes).
- Cases `1)` and `*)` both `continue` before the loop reaches the
  `if`/`CONSECUTIVE` logic, so a skipped record neither increments nor
  breaks the streak — exactly the documented "treat as absent from history"
  behavior. Traced by hand and confirmed via the scenario 21/22 assertions
  (`consecutive_rework_count=2`, i.e. current + the older valid record
  *beyond* the truncated/unreadable one — proving the bad record was
  skipped, not counted as a break).
- The `WARNING:` line is written with `>&2` (stderr) and prefixed
  `WARNING:` (not `FAIL:`), so it cannot be mistaken for a `FAIL:` line by
  `pr-merge-gates.md`'s `grep -E 'FAIL:'` CI-log check.
- No remaining unguarded pipeline under `set -euo pipefail` was found in
  the diff — the only other pre-existing extraction of this shape
  (`recorded_at_ns`) was already guarded before this PR (`|| true`) and is
  untouched here.

### Shell portability

Both `write_audit.sh` and `record_qc_audit_test.sh` carry explicit
`#!/usr/bin/env bash` shebangs, which places them in `posix_sh_check.sh`'s
documented EXCLUDED set ("Scripts with explicit bash shebang ... are out
of scope"). Confirmed by reading `posix_sh_check.sh` directly — no
POSIX-sh violation possible here. The new `case`/`$((...))` bash
constructs are fine under this shebang.

### dune wiring

`trading/devtools/checks/dune` already declares
`(deps record_qc_audit.sh write_audit.sh)` for the `record_qc_audit_test.sh`
alias-runtest rule (pre-existing, unmodified by this PR) — the new
scenarios 21/22 ride the existing rule with no dune-file edit needed,
matching the PR's claim ("wired into dune runtest via the existing rule,
unmodified").

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | Baseline green on merge base; PR touches no OCaml, no formatting surface changed |
| H2 | dune build | PASS | Same — no OCaml files in diff |
| H3 | dune runtest | PASS | Independently re-ran the targeted suite in an isolated temp dir (not the shared tree): 24 passed, 0 failed at PR tip; reproduced 22 passed/2 failed against pre-fix write_audit.sh, confirming non-vacuous change-detection |
| P1 | Functions ≤ 50 lines (linter) | NA | `fn_length_linter` scopes `.ml` files only; this PR is pure shell |
| P2 | No magic numbers (linter) | NA | `linter_magic_numbers.sh` header states scope is "lib .ml files"; confirmed by reading the script — not applicable to `.sh` |
| P3 | Config completeness | NA | No new tunable threshold/period/weight introduced — this is error-handling/control-flow logic (skip-vs-abort-vs-break decision), not a numeric knob |
| P4 | Public-symbol export hygiene (mli coverage) | NA | No `.mli` files in diff (shell scripts have no interface-file convention) |
| P5 | Internal helpers prefixed per convention | NA | `_`-prefix convention (`ocaml-patterns.md`) is OCaml-specific; shell scripts here use plain descriptive names (`prev_grep_status`, `prev_verdict`), consistent with the rest of this file |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | NA | test-patterns.md governs OUnit2 + the OCaml Matchers library (`assert_that`/`field`/`all_of`); this is a bash smoke-test harness using its own `pass`/`fail` helpers, pre-existing convention for this file, unaffected by this PR |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | NA | No core-module files touched |
| A2 | No new `analysis/` imports into `trading/trading/` outside backtest exception | NA | No OCaml/dune files touched, no imports of any kind |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | `git diff --name-only origin/main...1bfbb38e` shows exactly the 3 files the PR claims (`write_audit.sh`, `record_qc_audit_test.sh`, `dev/status/harness.md`) — no cross-feature drift |

## Quality Score

5 — All gates pass (independently re-verified, not just re-stated), the guard logic was hand-traced and matches both grep's documented exit-code semantics and the scenario assertions, the new tests are non-vacuous (reproduced red pre-fix / green post-fix), and the fix stays inside the file's existing shell conventions with no scope creep.

## Verdict

APPROVED

## NEEDS_REWORK Items

(None — verdict is APPROVED.)

---
_Posted by the lead-orchestrator on behalf of `qc-structural` (GHA run 30817481526). `gh` is absent in this runtime, so the agent could not post it itself._

---

<!-- github review id 4845010892, state COMMENTED -->

## Behavioral QC — harness/prev-verdict-pipefail (PR #2184)

### Scope note

Pure infra/harness PR (shell script + fixture test + status-file note); no
Weinstein domain logic touched. Per `.claude/rules/qc-behavioral-authority.md`
§"When to skip this file entirely", the entire domain checklist (S*/L*/C*/T*)
is marked NA below. Review focused on the generic Contract Pinning Checklist
(CP1–CP4), per this track's explicit false-green history (#2169: 22/22 passed
with the invariant broken).

### Independent verification performed

Extracted `write_audit.sh` + `record_qc_audit_test.sh` (PR tip) plus
unmodified `record_qc_audit.sh` (main) into an isolated `/tmp` dir (no
shared-tree writes) and ran the suite directly — reproduced qc-structural's
24/0 (post-fix) and 22/2 (pre-fix, `write_audit.sh` reverted to
`origin/main`) results exactly.

Went one step further than presence-of-test verification, per this track's
explicit false-green mandate: **mutation-tested each specific sub-claim** in
the code docstring / PR body / status-file note to see whether the test
suite would actually catch a regression in that specific claim, not just in
the headline "does it abort" behavior.

**Mutation 1 — skip vs. break (claims 1–2, "the direction decision").**
Changed the `1)` case's `continue` to `break` (i.e., a truncated record
*breaks* the streak instead of being skipped, the "unsafe direction" the
harness item itself names). Result: **scenario 21 goes red**
(`consecutive_rework_count=1`, not the expected `2`) while 22 stays green.
This is real, non-vacuous coverage — the test would catch a regression to
the unsafe direction. PASS.

**Mutation 2 — "silently" (claim 3).** Injected a spurious
`echo "WARNING: ..." >&2` into the exit-1 (`No overall_qc field found`)
branch, i.e. made the "silent" skip also emit a warning. Result: **all 24
scenarios still pass.** Scenario 21 never asserts the *absence* of a
`WARNING:` line on this path, only that `consecutive_rework_count=2` and
rc=0. A regression that made the "silent" path noisy (or, conversely, code
that accidentally routed real unreadable-file failures through the silent
branch) would not be caught. This is exactly the CP4 gap this checklist
exists to find: the docstring makes an explicit, granular claim
("tolerated silently") that the test does not pin.

**Mutation 3 — "naming the file" (claim 4).** Removed `$f` from the
`WARNING: could not read prior audit record for consecutive_rework_count
scan: $f (grep exit $prev_grep_status)` message. Result: **all 24 scenarios
still pass.** Scenario 22 only asserts the substring
`'WARNING: could not read prior audit record'`, not that the offending
filename actually appears in the message. A regression that dropped the
file identity from the warning (defeating its stated purpose — "visible in
orchestrator run logs," where the whole point is knowing *which* file is
bad) would not be caught.

Both mutations 2 and 3 are test-completeness gaps only — the shipped
implementation is correct in both cases (verified by direct reading of
`write_audit.sh` lines 341–346); nothing here indicates the code itself
misbehaves. But per this track's own standard (a test is not evidence
unless it can fail), these two specific claims are currently unpinned.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new `.mli` docstrings has an identified test that pins it | NA | No new `.mli` — pure shell PR. |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" sections has a corresponding test in the committed test file | FAIL | PR body: "grep exit 1 (no match) is skipped silently; grep exit >1 ... is skipped but also emits a stderr WARNING naming the file. Adds scenarios 21-22 ... pinning both cases." The count/no-abort/warning-presence sub-claims are pinned (scenarios 21, 22). The "silently" (no warning on the exit-1 path) and "naming the file" (filename present in the exit->1 warning) sub-claims are asserted in prose but not pinned by any assertion — see Mutations 2 and 3 above. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size_is | NA | No pass-through/identity semantics in this feature. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | FAIL | `write_audit.sh` lines ~326–345 docstring explicitly claims: "grep exit 1 ... is tolerated silently" and grep exit >1 "is surfaced as a stderr WARNING ... naming the file". The guarded-against *scenarios* (exit 1, exit >1) are each exercised (scenarios 21/22), but the specific claimed *properties* of each ("silently" = no warning; warning names the specific file) are not asserted — see Mutations 2 and 3. |

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | No core module touched; not flagged by qc-structural. |
| S1–S6, L1–L4, C1–C3, T1–T4 | Weinstein domain rows | NA | Pure infra/harness/refactor PR; domain checklist not applicable (per qc-behavioral-authority.md "When to skip this file entirely"). |

## Quality Score

2 — Below standard but fixable: the direction-decision claim (skip vs. break, the actual point of the harness item) is soundly pinned and mutation-verified. But two granular claims stated explicitly in the code docstring and PR body — "silently" (no warning) on the exit-1 path, and the warning "naming the file" on the exit->1 path — are not pinned by any assertion that would catch their regression. Per this track's own explicit false-green standard (the reason this review was scoped so pointedly), presence of a passing test is not sufficient evidence; these two claims currently have none. The underlying implementation is correct (verified by direct code reading) — this is a test-completeness gap, not a domain-logic defect, so it should be a quick fix.

## Verdict

NEEDS_REWORK

## NEEDS_REWORK Items

### CP2/CP4: "Silently" and "naming the file" sub-claims unpinned in scenarios 21/22
- Finding: Two specific behavioral claims made in `write_audit.sh`'s docstring (lines ~326–345) and restated in the PR body / `dev/status/harness.md` are not exercised by any assertion that would fail if they regressed:
  1. Claim: grep exit 1 (truncated record) is skipped **silently** (no stderr output). Mutation test: injecting a spurious `WARNING:` echo into that branch left scenario 21 (and the whole suite) green.
  2. Claim: grep exit >1 (unreadable record) emits a WARNING **naming the file**. Mutation test: stripping `$f` from the warning string left scenario 22 (and the whole suite) green.
- Location: `trading/devtools/checks/write_audit.sh` lines 341–346 (the `case "$prev_grep_status"` block); `trading/devtools/checks/record_qc_audit_test.sh` scenario 21 (~line 1003) and scenario 22 (~line 1040).
- Authority: PR body — "grep exit 1 (no match) is skipped silently; grep exit >1 (e.g. 2, unreadable target) is skipped but also emits a stderr WARNING naming the file." Same language repeated in `dev/status/harness.md`'s H-PREV-VERDICT-PIPEFAIL entry and in the code's own inline comment ("grep exit 1 ... is tolerated silently ... grep exit >1 ... is surfaced as a stderr WARNING (visible in orchestrator run logs)").
- Required fix: In scenario 21, additionally assert that `out21_3` (or a captured stderr-only stream) does **not** contain `WARNING`. In scenario 22, additionally assert that the WARNING line contains the actual offending file's basename (e.g. `2026-07-30-feat-unreadable-${FEATURE22}.json`), not just the fixed substring `WARNING: could not read prior audit record`.
- harness_gap: LINTER_CANDIDATE — both fixes are mechanical (grep for absence of a substring; grep for the fixture's own filename in the warning), not judgment calls; a future test-writer could add both in under 10 lines total.

---
_Posted by the lead-orchestrator on behalf of `qc-behavioral` (GHA run 30817481526). `gh` is absent in this runtime, so the agent could not post it itself._

---

<!-- github review id 4845279653, state COMMENTED -->

## Behavioral QC re-review — rework iteration 1 (tip `c5e06533`)

Reviewed SHA: c5e06533809855f794b2b62995bb0b003f339600

## Behavioral QC — PR #2184 `harness/prev-verdict-pipefail` (rework iteration 1 re-review)

**Context:** at `1bfbb38e` this reviewer returned NEEDS_REWORK (quality 2/5): the code's
own docstring named two distinct sub-claims for `write_audit.sh`'s handling of an
unparseable/unreadable prior `overall_qc` record — (1) grep exit 1 ("no match", the
truncated-record shape) is skipped **silently**, no warning; (2) grep exit >1 (e.g. 2,
genuinely unreadable) is skipped but emits a `WARNING:` line **naming the offending
file**. Both had zero assertion coverage: injecting a spurious `WARNING:` echo into the
exit-1 branch, and stripping `$f` from the exit->1 warning message, each left all 24
scenarios green. The direction decision itself (skip, don't break the streak) was already
soundly pinned and not in question.

Rework `c5e06533` (2 files, +11/-8, `write_audit.sh` untouched) adds exactly two new
conjuncts: scenario 21 gained `&& ! echo "${out21_3}" | grep -q 'WARNING'`; scenario 22
gained `&& echo "${out22_3}" | grep -qF "${UNREADABLE_PATH_22}"` (capturing the seeded
directory path into a named variable first).

### Independent re-verification (mutation-tested from a clean `/tmp` copy of the committed scripts, not taken on trust)

Baseline: 24/0 clean, matching the committed SHA byte-for-byte.

| Mutation | Result | Cross-pattern claim | Confirmed? |
|---|---|---|---|
| Inject spurious `echo "WARNING: ..." >&2` into the exit-1 (silent-skip) branch | 23/1 | scenario 21 reddens, scenario 22 stays green | **Yes** — exact match |
| Strip `$f` from the exit->1 warning message | 23/1 | scenario 22 reddens, scenario 21 stays green | **Yes** — exact match |
| Both reverted independently | 24/0, byte-identical to `write_audit.sh.orig` | — | Yes |

The reported one-to-one mapping holds exactly: each new assertion pins its own distinct
claim, neither trips on the other's side effect.

**Extra adversarial mutation (not in the author's report, run to stress the "over-fitted"
question):** replaced the correct `$f` with a *different, non-empty, wrong* path
(`/some/other/wrong/path.json`) rather than deleting it outright. Result: scenario 22
alone reddens (23/1), scenario 21 stays green; reverting restores 24/0. This confirms
`grep -qF "${UNREADABLE_PATH_22}"` pins "names *this specific* file," not merely "some
non-empty text is present" — a materially stronger guarantee than the single
deletion-mutation the author reported.

### Answering the specific risk questions

- **Over-fitting to message wording?** No. `grep -qF "${UNREADABLE_PATH_22}"` matches the
  path as a substring anywhere in the combined stdout+stderr capture — it does not anchor
  on the surrounding sentence ("could not read prior audit record...", etc.). A legitimate
  future rewording of the warning sentence survives this assertion as long as the path is
  still emitted somewhere in it. This is the right level of coupling — precise on the
  load-bearing fact (which file), loose on prose.
- **Can scenario 21's negative assertion (`! grep -q 'WARNING'`) pass vacuously (e.g. on
  empty output)?** No. It is ANDed with `rc21_1==0`, `rc21_3==0`, `[[ -f "${JSON21}" ]]`,
  and `grep -q '"consecutive_rework_count": *2'` on both the JSON file and the success
  message in `out21_3`. A crashed or silent run fails those first; the negative check only
  matters once the positive path is already proven to have executed and produced the
  correct count. Not a weak guard.
- **CP2/CP4 — fully pinned now?** Yes. The two previously-FAIL claims are now PASS. No new
  implementation claims were introduced this rework (the diff excludes `write_audit.sh`
  entirely — it's a test-only + status-doc rework, correctly narrow in scope). No other
  documented sub-claim in the `write_audit.sh:296-357` comment block lacks coverage: the
  exit-0-but-empty-value branch is explicitly marked defensive/believed-unreachable in the
  comment itself and was not part of either review's findings.

## Contract Pinning Checklist (re-review)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | New `.mli` docstring claims pinned by tests | NA | No `.mli` in this diff (bash-only change) |
| CP2 | PR/status-note "what changed" claims have corresponding committed tests | PASS | Status-note claims (scenario 21 gains a no-warning assertion; scenario 22 gains a names-the-file assertion; both independently re-verified via mutation) all match `record_qc_audit_test.sh` at `c5e06533` |
| CP3 | Pass-through/identity tests pin full equality, not just size | NA | No pass-through semantics in this change |
| CP4 | Every guard named in the code docstring has a test exercising it | PASS | Both previously-FAIL rows (silent-skip on exit 1; names-the-file on exit >1) now independently confirmed test-covered and change-detecting |

## Behavioral Checklist

Pure harness/infra PR — domain S*/L*/C*/T* rows not applicable.

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | N/A | NA | No core-module (Portfolio/Orders/Position/Strategy/Engine) touch |
| S1-S6, L1-L4, C1-C3, T1-T4 | N/A | NA | Pure infra/harness PR; domain checklist not applicable |

## Quality Score

4 — both previously-identified assertion gaps are now genuinely closed and independently
re-verified (not merely re-reported); the extra adversarial mutation this pass ran shows
the fix is robust beyond the author's own minimal reproduction. Held at 4 rather than 5
because this is a narrow, mechanical closure of a prior finding rather than a novel
exemplary design — a solid, unremarkable rework.

## Verdict

APPROVED

---
_Posted by the lead-orchestrator on behalf of `qc-behavioral` (GHA run 30817481526). `gh` is absent in this runtime._

