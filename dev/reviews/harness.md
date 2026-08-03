Reviewed SHA: 027ae38a

## Structural QC — PR #2169 `harness/audit-atomic-write` (rework iteration 1, 2026-08-03)

**Context:** PR #2169 was previously APPROVED structurally at SHA `993a1437` (quality 4/5). qc-behavioral then returned NEEDS_REWORK on one item (CP4 FAIL): two load-bearing invariants asserted in `write_audit.sh:320–335` comment block were not tested by the original scenario 19. This rework iteration adds targeted test assertions to pin those invariants.

**Build gates (all run by dispatch):**

| # | Check | Status | Evidence |
|---|-------|--------|----------|
| H1 | dune build @fmt | PASS | Exit 0 (dispatch run) |
| H2 | dune build | PASS | Exit 0 (dispatch run) |
| H3 | dune runtest | PASS | Exit 0; 22 tests passed, 0 failed (dispatch run) |

**Structural checklist (project authority rows H1–H3, P1–P6, A1–A3):**

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | Exit 0 |
| H2 | dune build | PASS | Exit 0 |
| H3 | dune runtest | PASS | 22/22 scenarios pass |
| P1 | Functions ≤ 50 lines | NA | Shell scripts only |
| P2 | No magic numbers | NA | Shell scripts only |
| P3 | Config completeness | NA | Harness infrastructure; test-only env hooks documented in code |
| P4 | .mli coverage | NA | Shell scripts only |
| P5 | Internal helpers prefixed with _ | NA | Shell helpers in established pattern |
| P6 | Tests conform to test-patterns.md | NA | Shell test file, not OCaml |
| A1 | Core module modifications | PASS | No core modules touched |
| A2 | No analysis/ → trading/ imports | PASS | Shell scripts, no imports |
| A3 | No unnecessary existing module modifications | PASS | Exactly 2 files in rework: `trading/devtools/checks/record_qc_audit_test.sh` and `trading/devtools/checks/write_audit.sh`; verified via `gh pr view` |

### Rework changes — structural assessment

**File 1: `write_audit.sh` line 383**
- Added `;  TMP_FILE=$TMP_FILE` to the stderr message when `WRITE_AUDIT_TEST_ABORT_BEFORE_RENAME` test-only abort hook fires
- Test-only code path (guarded by `if [ -n "${WRITE_AUDIT_TEST_ABORT_BEFORE_RENAME:-}" ]`); production behavior unchanged
- ✅ No regression risk

**File 2: `record_qc_audit_test.sh` lines 889–929**
- Added detailed comment block (lines 889–901) documenting two load-bearing invariants:
  1. **Same-directory/same-filesystem:** Temp file MUST be created in `${TMP_REPO}/dev/audit` (not `$TMPDIR`), so later `mv` is a single rename syscall rather than copy+unlink
  2. **Glob-invisible suffix:** Temp filename must NOT end in `.json`, making leftover temps invisible to both `dev/audit/` consumers
- Added parsing of `TMP_FILE` from abort hook stderr via sed (line 902)
  - Robustness: sed pattern `'s/.*TMP_FILE=//'` is appropriately narrow; only the abort hook emits this; `tail -1` is defensive; variable safely quoted in all comparisons
  - ✅ Parsing is sound
- Added three new assertions to the pass condition (lines 913–915):
  - `[[ -n "${TMP_FILE_19}" ]]` — ensures temp path was emitted
  - `[[ "${TMP_FILE_19_DIR}" == "${TMP_REPO}/dev/audit" ]]` — asserts same-directory invariant
  - `[[ "${TMP_FILE_19_BASENAME}" != *.json ]]` — asserts glob-invisible invariant
- ✅ All assertions change-detecting (dispatch verified via two independent mutations)

### Shell conformance
- File is bash script (shebang line 1); `[[ ]]` bash-isms acceptable
- No new patterns introduced; existing bash patterns (e.g., line 121) remain unchanged
- `set -euo pipefail` interaction: new sed pipeline (line 902) already present elsewhere; no new hazard
- ✅ No shell conformance regression

### Change scope
- Exactly 2 files in harness infrastructure
- 29 insertions, 4 deletions (27 net LOC)
- Zero scope creep; no `dev/status/` modifications (orchestrator handles reconciliation)

### Test-only hook in production code
The `TMP_FILE=` emission rides on the existing `WRITE_AUDIT_TEST_ABORT_BEFORE_RENAME` test-only branch. Production code path unaffected. Diagnostic stderr line does not affect exit code or returned value. ✅ No production-side regression risk.

### Verdict

**APPROVED**

All structural gates pass. The rework meaningfully strengthens test coverage by pinning two previously untested load-bearing invariants with clear, independent assertions. Change scope is tightly focused. No regressions detected.

## Quality Score

5 — Exemplary rework. The change identifies and pins two specific invariants critical for atomicity guarantees (same-filesystem and glob-invisible suffix). Added comment block clearly explains the WHY. Dispatch's independent mutation verification confirms both new assertions are change-detecting (not tautologies). Minimal scope, zero scope creep. All gates pass.

---

## Behavioral QC — PR #2169 `harness/audit-atomic-write` (rework iteration 1, 2026-08-03)

**Scope:** pure harness / infra PR — no Weinstein domain logic touched. Per
`.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely", the
domain checklist (S1–S6, L1–L4, C1–C3, T1–T4) is **NA in its entirety**; A1 is NA
(structural did not flag it, and there is no domain logic to leak). The review is the
generic Contract Pinning Checklist CP1–CP4.

**Re-review basis.** I returned NEEDS_REWORK at `993a1437` with exactly one item, **N1**
(CP4 FAIL). The only question here is whether `027ae38a` closes it. The rework
implements the "cheapest form" my N1 *Required fix* named, essentially verbatim: the
abort hook emits `TMP_FILE=$TMP_FILE`, and scenario 19 asserts (a) `dirname == $AUDIT_DIR`
and (b) `basename != *.json`.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new `.mli` docstrings has an identified test | NA | No `.mli` in this PR (shell only). Script-header/comment-block contract claims are evaluated under CP4, the applicable row for docstring-named guards. Docstring *accuracy* re-verified below. |
| CP2 | Each claim in the PR body / commit message has a corresponding committed test | PASS | Rework commit claims (a), (b), and mutation results A/B. All three verified: assertions present at `record_qc_audit_test.sh:913–915`; mutation A/B outcomes independently reproduced by the dispatcher (A: dir check fires, `stray_tmp_count` still 0; B: dir check passes, basename check fires). Iteration-0 CP2 claims re-checked and unchanged. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size | PASS | Unchanged from iteration 0 and strengthened. Scenario 19 still asserts `[[ "${CONTENT_AFTER}" == "${CONTENT_A}" ]]` — full byte-identity of the whole record — and now additionally pins the *shape* of the staged path rather than only a count. The N1 defect was precisely a count-proxy (`stray_tmp_count == 0`) standing in for an identity assertion; that gap is now closed by a direct assertion on the path itself. |
| CP4 | Each guard called out explicitly in code comments has a test exercising the guarded-against scenario | **PASS** (was FAIL) | Both halves of the `write_audit.sh:320–335` guard are now exercised. The mutations that reproduce each guarded-against scenario — relocating the temp off `$AUDIT_DIR`, and giving it a `.json` terminus — each turn the suite red (21/1, exit 1), and each is caught by a *different* one of the two new assertions, so they are independently change-detecting rather than one redundant pair. |

**No CP\* FAIL → APPROVED** (mechanical).

### Behavioral Checklist (domain)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | Pure harness / infra PR. Structural did not flag A1. Rework touches only `trading/devtools/checks/`. |
| S1–S6, L1–L4, C1–C3, T1–T4 | Weinstein domain rows | NA | Pure infra / harness PR; domain checklist not applicable. No stage classification, stop, screener, sizing, or macro/sector logic anywhere in the diff. |

### N1 — disposition: **CLOSED**

The mechanical question (does the new assertion actually detect the break?) was settled
by independent mutation testing. Below are the four soundness questions that remained
for judgment.

**1. Does it close N1 *fully*, including folded-in finding 2 (temp invisibility to
consumers)? → Yes, to the scope N1 actually claimed.**

N1 folded finding 2 in on the stated grounds that "one assertion on the temp path's
shape pins both", and the *Required fix* offered the seeded-leftover test as an
"**equally acceptable alternative** for (b)" — either route, not both. The author took
the path-shape route, which is the one N1 named first.

Critically, the **drift vector finding 2 identified was the same single line as N1** —
a "tidier" refactor to `mktemp "${AUDIT_DIR}/tmp.XXXXXX.json"`. That is exactly
mutation B, and it now turns the suite red. The vector is closed.

What the basename assertion does *not* pin is the **consumer-side** half: that
`write_audit.sh:263`'s own scan and `check_06_qc_calibration.sh:101` require a literal
`.json` terminus. If a *consumer's* glob later broadened to `*-<feature>.json*` or `*`,
a leftover temp would become visible again and no test would notice. That vector lives
in a different file, was never part of N1's scope, and I did not raise it as blocking.
The factual claim itself I re-verified at this tip: both consumers still glob
`*-"<feature>".json`, and there are still **exactly two** of them, as the comment
claims. → **follow-up, not a blocker** (F1 below).

**2. Parsing robustness — sound; and specifically it does *not* repeat
H-PREV-VERDICT-PIPEFAIL.**

`TMP_FILE_19="$(echo "${out19_2}" | sed -n 's/.*TMP_FILE=//p' | tail -1)"`, under the
test script's `set -euo pipefail` (line 15):

- **pipefail:** every stage exits 0 on the no-match path. `sed -n '…p'` returns **0**
  when nothing matches — unlike `grep`, which returns 1. H-PREV-VERDICT-PIPEFAIL is the
  `grep -o … | head -1` shape (`write_audit.sh:291`), where a no-match `grep` exits 1,
  `pipefail` propagates it, and `set -e` aborts the assignment. **The new pipeline is a
  different shape and does not reproduce that class.** The no-match case degrades to an
  empty string, which the `-n "${TMP_FILE_19}"` guard then catches as a test failure —
  the correct behaviour.
- **Spaces in paths:** handled. The sed capture runs to end-of-line, and `TMP_FILE=` is
  the last field on the emitted line; `dirname`/`basename` arguments and both
  comparisons quote the variable. (In practice `TMP_REPO` is a `mktemp -d` path, so the
  case is hypothetical.) Only an embedded newline would break it — unreachable from
  `mktemp`.
- **Other `TMP_FILE=` emitters:** none in the tree; `tail -1` is defensive against a
  future second one, and the greedy `.*` takes the last occurrence per line.
- **Residual (minor, degrades loudly):** because the capture runs to end-of-line, anyone
  appending text after `TMP_FILE=$TMP_FILE` on that echo would corrupt the parsed value —
  but the corrupted path then fails the `dirname` check and the test goes red with the
  offending value printed. Loud, not silent. A one-line "keep `TMP_FILE=` last on this
  line" comment at the hook would be a nice-to-have (F2).

**3. Is the guard pinned in the right place? → Yes; every degradation path I could
construct fails loudly, none silently.**

The pin rides a test-only hook, so I traced what happens if that hook is deleted,
renamed, or moved:

| Mutation of the hook | Outcome |
|---|---|
| Hook deleted / renamed / env var renamed | Second invocation succeeds → `rc19_2 == 0` → `(( rc19_2 != 0 ))` fails. Also the `grep -q "simulating interruption before rename"` fails. **Two independent catches. Red.** |
| Hook kept but `TMP_FILE=` dropped from the message | `TMP_FILE_19` empty → `-n` guard fails; `dirname ""` → `.` → dir check also fails. **Two independent catches. Red.** |
| Hook moved above the `mktemp` call | `$TMP_FILE` unbound under `set -u` → abort before the message → grep for the abort text fails. **Red.** |

No silent-degradation path found. The `-n` guard is doing real work here — it is what
converts "hook stopped emitting" from a vacuous pass into a failure, and it is the
reason this pin is robust rather than merely present.

One property worth recording for the next reader: the assertion observes the path the
*hook prints*, not the path `mv` consumes. They are the same `$TMP_FILE` variable three
lines apart, so no divergence is constructible without editing between them — an
acceptable pin, but it is an observation of the variable, not of the syscall.

**4. Docstring accuracy (CP1/CP2) — accurate; one minor under-documentation.**

- `write_audit.sh:320–335` re-verified at this tip and **still accurate, nothing over-
  or under-claimed**. Both consumers confirmed to require a literal `.json` terminus
  (`write_audit.sh:263` — `ls -1 "$AUDIT_DIR"/*-"$FEATURE".json`; and
  `trading/devtools/checks/deep_scan/check_06_qc_calibration.sh:101` — `for audit_file
  in "${REPO_ROOT}"/dev/audit/*-"${feature}".json`), and there are exactly two, as
  claimed. The comment's relative reference `deep_scan/check_06_qc_calibration.sh` is
  correct relative to write_audit.sh's own directory. The rework did not weaken any
  claim; it converted two of them from *asserted* to *enforced*.
- **Under-documented (minor):** the hook's own comment block at `write_audit.sh:375–381`
  still describes the hook solely as "simulate an interruption … `$OUTPUT_FILE` must be
  left byte-identical". It does not mention that the message now carries a `TMP_FILE=`
  field that scenario 19 **parses and asserts on**. A future editor tidying that stderr
  string has no in-place signal that a test depends on it. Per (3) this degrades loudly,
  so it is a documentation nit, not a contract failure (F2).

### Follow-ups (non-blocking — file to `dev/status/harness.md`, do **not** hold this merge)

Neither of these is a CP\* failure; both are strengthenings of a residual I did not
raise as blocking in N1.

- **F1 — consumer-side glob invisibility is still unpinned.** The `basename != *.json`
  assertion pins the *write* side (temp never gains a `.json` terminus). The *read* side —
  that both `dev/audit/` consumers ignore a surviving temp — remains true by glob
  semantics but untested, so a later broadening of either consumer's glob would go
  unnoticed. The N1 *Required fix*'s alternative form is the fix: seed a leftover
  `…-<feature>.json.aBcDeF` containing `"overall_qc": "NEEDS_REWORK"` and assert the
  `consecutive_rework_count` scan ignores it. `harness_gap: LINTER_CANDIDATE`.
- **F2 — hook docstring should name its parsed contract.** Add one line to
  `write_audit.sh:375–381` noting that `record_qc_audit_test.sh` scenario 19 parses
  `TMP_FILE=` from this message and that the field must remain last on the line.
  `harness_gap: ONGOING_REVIEW`.

Iteration-0 residuals recorded then and still open, unchanged by this rework and still
non-blocking: the H-PREV-VERDICT-PIPEFAIL downstream failure remains reachable from
inputs this script does not produce (already-committed records, hand edits, older
script versions) — `harness_gap: ONGOING_REVIEW`; and the undocumented 0644→0600 temp-mode
delta — `harness_gap: NONE`.

## Quality Score

5 — Exemplary rework. It implements the required fix precisely, and then goes past
"make the test pass": the two assertions were shown to be *independently* change-detecting
by two separate mutations rather than assumed, the added comment block explains why the
pre-existing `stray_tmp_count` check was a false-green (the actual defect, not just its
symptom), and every hook-degradation path I could construct fails loudly rather than
silently. Scope is two files, +27/-4, with production behaviour untouched. The two
follow-ups are strengthenings of a residual outside N1's scope, not defects.

## Verdict

APPROVED

---

## Prior review — Iteration 0 (SHA 993a1437)

Reviewed SHA: 993a1437153d5ddb9f9874d14b84a2763871638e

## Structural QC — PR #2169 `harness/audit-atomic-write` (2026-07-30, solo-dispatch run)

**overall_qc: APPROVED** — zero rework required; all gates PASS.

| Gate | Verdict | Quality | Exit Code | Details |
|---|---|---|---|---|
| dune build @fmt | PASS | — | 0 | Format check clean |
| dune build | PASS | — | 0 | Full build clean |
| dune runtest | PASS | — | 0 | All 22 shell test scenarios pass (batch + explicit) |
| record_qc_audit_test.sh | PASS | — | 0 | Scenario 19 (atomic write interruption) & 20 (happy path) confirm atomicity |

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | No format violations |
| H2 | dune build | PASS | Full build succeeds |
| H3 | dune runtest | PASS | 22/22 shell test scenarios pass |
| P1 | Functions ≤ 50 lines — covered by language-specific linter | NA | Shell script (no OCaml functions) |
| P2 | No magic numbers — covered by language-specific linter | NA | Shell script (no OCaml literals) |
| P3 | All configurable thresholds/periods/weights in config record | NA | Shell script; this PR adds test-only env hooks (`WRITE_AUDIT_TEST_ABORT_BEFORE_RENAME`, `WRITE_AUDIT_RECORDED_AT_NS`) which are documented in code and limited to testing |
| P4 | Public-symbol export hygiene — covered by language-specific linter | NA | Shell script (no OCaml public symbols) |
| P5 | Internal helpers prefixed per project convention | NA | Shell script (no OCaml helper modules) |
| P6 | Tests conform to `.claude/rules/test-patterns.md` (presence + conformance) | NA | Shell test file, not OCaml; test-patterns.md is OCaml-specific (Matchers library, assert_that, OUnit2). Shell tests use explicit grep assertions instead |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to core modules; harness tooling only |
| A2 | No new `analysis/` imports into `trading/trading/` | PASS | No dune file changes; harness tooling only |
| A3 | No unnecessary modifications to existing non-feature modules | PASS | Only 3 files touched: `write_audit.sh` (the fix), `record_qc_audit_test.sh` (new test scenarios), `dev/status/harness.md` (backlog update) |

## Atomicity Verification

The PR's core claim is atomic record writes to prevent truncation on interruption. Verified all six atomicity requirements:

1. **Temp file on same filesystem**: ✓ Line 336 uses `mktemp "${OUTPUT_FILE}.XXXXXX"`, creating temp in the SAME directory as target (`$AUDIT_DIR`). Comment (lines 320–325) explicitly states `mv` within same dir is a single rename syscall; cross-filesystem degrades to copy+unlink, reintroducing the truncation window.

2. **Cleanup on failure/signal**: ✓ Line 340: `trap 'rm -f "$TMP_FILE"' EXIT INT TERM` handles exit, SIGINT, SIGTERM. After successful `mv` (line 387), trap is a no-op since the temp path no longer exists.

3. **`mktemp` vs predictable suffix**: ✓ Line 336 uses `mktemp` with `.XXXXXX` template, generating random per-invocation suffixes. Prevents concurrent runs from colliding.

4. **Short-circuit on write failure**: ✓ Line 354 writes to temp via heredoc. Any write failure triggers exit (line 73's `set -euo pipefail`) → trap fires → cleanup → no `mv`. Prevents partial temp from being moved into place.

5. **Quality score validated before write**: ✓ Lines 181–196 validate quality score is integer 1–5 BEFORE any file I/O. Content prepared at lines 348–352, written to temp at lines 354–373. Output file only touched via `mv` after temp completes. Bad score cannot reach output file.

6. **Temp filename invisible to consumers**: ✓ Lines 327–335 explain temp suffix does NOT end in `.json` (mktemp replaces `.XXXXXX` with random chars, e.g., `output.json.aBcDeF`). Both `dev/audit/` glob consumers (`consecutive_rework_count` scan in this script and `deep_scan/check_06_qc_calibration.sh`) search for `*-<feature>.json` (ending in `.json`). Leftover temp files from SIGKILL (bypasses trap) are invisible to globs — only inert disk litter.

## Test Coverage

**22 shell test scenarios pass**, including critical regression tests:

- **Scenario 19** (H-AUDIT-ATOMIC-WRITE core): Writes a real record (content A), then re-invokes for the SAME date/branch/feature with `WRITE_AUDIT_TEST_ABORT_BEFORE_RENAME=1` (test hook that exits 1 right after temp-file write, before `mv`). Asserts target is **byte-identical** to content A (never truncated, never partially overwritten) with **no stray temp file** left. This proves the fix closes the truncation window the PR exists to solve.

- **Scenario 20** (happy path): Normal uninterrupted write produces exactly one file at target location with correct content, no leftover temp. Confirms the temp-file+`mv` plumbing doesn't regress ordinary operation.

- **Scenarios 1–18**: Cover file-mode extraction, PR-mode parsing, quality-score validation (1..5 boundary + out-of-range rejection), consecutive_rework_count ordering, legacy record handling, `gh` binary presence checks. All pass.

## Quality Score

4 — Clean implementation with comprehensive atomicity + test coverage. One minor note: scenarios 1–18 were pre-existing (added by prior PRs); this PR adds scenarios 19–20 specifically to test the atomic-write fix. The implementation is mechanically sound; the test design is rigorous (negative control + positive case + boundary).

## Verdict

APPROVED

Audit record: `dev/audit/2026-07-30-harness-audit-atomic-write-harness.json` (pending write_audit.sh post-merge).

---

## Behavioral QC — PR #2169 `harness/audit-atomic-write` (H-AUDIT-ATOMIC-WRITE)

**Scope:** pure harness / infra PR — no Weinstein domain logic touched. Per
`.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely", the
domain checklist (S1–S6, L1–L4, C1–C3, T1–T4) is **NA in its entirety**; the review is
the generic Contract Pinning Checklist CP1–CP4. Structural QC APPROVED (4/5) at this
SHA verified the mechanism is *correct today*; this review asks whether each claimed
contract is *pinned by a test*.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new `.mli` docstrings has an identified test | NA | No `.mli` in this PR (shell only). The script-header contract claims are evaluated under CP4 below, which is the applicable row for docstring-named guards. |
| CP2 | Each PR-body / status-file claim has a corresponding committed test or verifiable fact | PASS | 8/8 claims substantiated; two reproduced independently (see below). |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size | PASS | Scenario 19 asserts `[[ "${CONTENT_AFTER}" == "${CONTENT_A}" ]]` — full byte-identity of the whole record, exactly the CP3-correct form (not `size_is`/line-count/"file still exists" proxy). Content B is deliberately distinguishable (`--quality-score 1`, `--notes "content B - must never land"`) so a clobber cannot pass silently. |
| CP4 | Each guard called out explicitly in code comments has a test exercising the guarded-against scenario | **FAIL** | The **same-directory/temp-name invariant** (write_audit.sh:320–335) is the load-bearing precondition for atomicity and is **not pinned by any test** — I broke it and the suite stayed 22/22 green. See NEEDS_REWORK item N1. The *other* two docstring guards ARE pinned or accurately hedged (see per-contract findings 3 and 4). |

**Any CP\* FAIL → NEEDS_REWORK** (mechanical).

### Behavioral Checklist (domain)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | Pure harness / infra PR; no domain logic. Structural did not flag A1. Only `trading/devtools/checks/` + `dev/status/` touched. |
| S1–S6, L1–L4, C1–C3, T1–T4 | Weinstein domain rows | NA | Pure infra / harness PR; domain checklist not applicable. No stage classification, stop, screener, or sizing logic in the diff. |

### Independent verification (the load-bearing evidence)

Both experiments were run in scratch dirs outside the repo tree; no repo state mutated.

**A. Would scenario 19 go RED if the fix were reverted? → YES. Reproduced.**
Copied the *new* test file + `record_qc_audit.sh` alongside the **pre-fix**
`write_audit.sh` (`git show HEAD~1:…/write_audit.sh`, confirmed to still contain
`cat > "$OUTPUT_FILE" <<ENDJSON` at line 319 and no `mktemp`):

```
record_qc_audit_test: 21 passed, 1 failed
  FAIL: scenario 19 — expected rc2!=0, target unchanged (content A) … got rc2=0
        content after: … "quality_score": 1, "notes": "content B - must never land"
```

The pre-fix script has no abort hook, so the "interrupted" second call *succeeds* and
content B silently replaces content A — the test fails on **two independent
assertions** (`rc19_2 != 0` and byte-identity). At this SHA the same suite is 22/22.
So scenario 19 is a genuine change-detecting regression test, not a happy-path proxy,
and the PR body's "reverting only write_audit.sh turns scenario 19 red; re-applying
goes green (22/22)" claim is **verified, not merely asserted**. Scenario 20 passed
under the revert too — correctly so, it is documented as a happy-path non-regression
guard, not the change detector.

Hook placement is also the strongest available single point: the abort sits *after*
the heredoc closes and immediately before `mv`, and the only write between the two is
to `$TMP_FILE` — so "target byte-identical at the last instant before rename" logically
implies "target untouched throughout the heredoc", which is the window the bug lived in.

**B. Is the same-directory invariant pinned? → NO. Reproduced.**
Changed *only* line 336, `mktemp "${OUTPUT_FILE}.XXXXXX"` → `mktemp` (temp lands in
`$TMPDIR`, i.e. potentially a different filesystem — precisely the degradation the
comment at 320–325 says "would silently reintroduce the exact truncation window this
fix exists to remove"):

```
  PASS: scenario 19 — interrupted write leaves pre-existing target byte-identical …
  PASS: scenario 20 — uninterrupted write still produces exactly the target record …
record_qc_audit_test: 22 passed, 0 failed
```

Fully green with the invariant broken. Scenario 19's stray-temp assertion
(`find … -name "*-${FEATURE19}.json.??????"` == 0) cannot distinguish
"temp was created in `dev/audit/` and cleaned up" from "temp was never in `dev/audit/`
at all" — both yield 0. This is item **N1**.

### Per-contract verdicts (the five items in scope)

**1. The atomicity claim itself — PASS (CONFIRMED by experiment A).** Scenario 19
genuinely fails against the old truncating implementation. Byte-identity, not a proxy.

**2. Temp-file invisibility to consumers — PASS on the factual claim, untested.**
Consumers confirmed by grep, and there are exactly two, as claimed: `write_audit.sh`'s
own scan (`ls -1 "$AUDIT_DIR"/*-"$FEATURE".json`, line 263) and
`deep_scan/check_06_qc_calibration.sh:101`
(`for audit_file in "${REPO_ROOT}"/dev/audit/*-"${feature}".json`). Both require the
name to end literally in `.json`; `mktemp` appends random chars *after* `.json`, so a
leftover temp cannot match. True by glob semantics — but **not pinned**: no scenario
seeds a surviving temp file and asserts the consumer scan ignores it. The drift vector
is the same single line as N1 (a "tidier" refactor to
`mktemp "${AUDIT_DIR}/tmp.XXXXXX.json"` would make leftovers *match* the glob and be
read as prior records — reviving H-PREV-VERDICT-PIPEFAIL). Folded into N1 because one
assertion on the temp path's shape pins both.

**3. Cleanup-on-signal — PASS, and honestly scoped (no overclaim).** Scenario 19 pins
the EXIT path: after the abort, `stray_tmp_count == 0`. The comments do **not**
overclaim — write_audit.sh:338–339 says "if anything below fails or the process is
terminated by a **caught** signal", and 332–335 explicitly concedes "if the process was
SIGKILLed, which bypasses the EXIT trap". That is accurate; no docstring-accuracy
finding. INT/TERM are not separately tested, but they route through the identical
handler as EXIT. Noted for completeness: `trap … INT` does not itself terminate the
script, so on SIGINT the temp is unlinked and execution continues to `mv`, which then
fails on the missing source under `set -e` → nonzero exit, **target still intact**. The
safe outcome holds on that path too.

**4. `--quality-score` validation ordering — PASS.** Validation is at lines 190–196;
`mktemp` is at 336 and `mv` at 387, so a bad score exits before any temp file exists
and before `$OUTPUT_FILE` is touched at all. Pinned by **scenario 13** (direct
`write_audit.sh --quality-score 0` → `rc == 1`, `audit_count_after == 0`, message names
the value) and **scenario 12** (file-mode, score 7). The atomic-write change preserves
the ordering — it strictly *widens* the safety margin, since the pre-fix script's
redirect was the first thing to touch the target. Minor: scenario 13's count glob
(`*-${FEATURE13}.json`) would not notice temp litter, but none can exist on that path.

**5. Relationship to H-PREV-VERDICT-PIPEFAIL — PASS, correctly scoped, not
overclaimed.** The claim is narrow and true as written: "a truncated record with
`recorded_at_ns` but no `overall_qc` can no longer be produced **by this script**"
(write_audit.sh:317–318). H-PREV-VERDICT-PIPEFAIL is **left open** (`- [ ]`) in
`dev/status/harness.md`, and both the status entry and the commit message state
explicitly that the streak-break-vs-skip direction decision is untouched here. So the
item is *not* being silently inherited as proven — the residual is stated, not hidden.
**Recorded for the next reader** (not rework): the downstream failure remains reachable
from inputs this script doesn't produce — records already committed to `dev/audit/`,
hand edits, or records written by an older script version — and that residual is still
untested. `harness_gap: ONGOING_REVIEW`.

### Other CP2 claims checked

| Claim | Verdict |
|---|---|
| Scenarios 19–20 added to the existing test file, no new file, no `dune` edit | PASS — diff is 3 files; `trading/devtools/checks/dune:479–481` (`(deps record_qc_audit.sh write_audit.sh)` / `(run bash %{dep:record_qc_audit_test.sh})`) is unmodified, so both scenarios are wired into `dune runtest` |
| `WRITE_AUDIT_TEST_ABORT_BEFORE_RENAME` mirrors the existing `WRITE_AUDIT_RECORDED_AT_NS` test-only override pattern | PASS — same shape (env-gated, documented in-place, fails loudly) |
| "Confirmed no other script in the tree globs `dev/audit/`" | PASS — grepped; only the two consumers above plus `record_qc_audit.sh`'s header comments |
| H-WRITE-AUDIT-SHEBANG-MISMATCH "still open" half was a substring-trap misreading; line 1404 already reads `bash …` | PASS — verified directly: `.claude/agents/lead-orchestrator.md:1404` is `bash trading/devtools/checks/write_audit.sh \`. The substring-trap explanation is also correct (`bash …/write_audit.sh` contains `sh …/write_audit.sh`). Closing that item is justified. |
| 22 scenarios green | PASS — reproduced at this SHA: `22 passed, 0 failed` |

### Observation (no rework required)

`mktemp` creates the temp file mode **0600**, where the pre-fix `cat >` redirect created
the record at **0644** under the default `umask 0022`. Verified empirically (pre-fix
`644`, post-fix `600`). Impact is low and almost certainly benign: git records
non-executable files as `100644` regardless, so **committed** records and fresh
checkouts are unaffected, and writer/reader are the same user in CI. Flagging only
because it is an undocumented behavioural delta of the fix that a future
different-user consumer of `dev/audit/` would trip over. `harness_gap: NONE`.

## Quality Score

2 — Below standard on contract pinning: the fix's load-bearing same-directory
invariant is unverified by any test (I broke it and the suite stayed 22/22 green), so
the delivered atomicity can silently regress. The implementation itself is sound and
scenario 19 is a genuine change detector; the required fix is ~2 lines.

## Verdict

NEEDS_REWORK

## NEEDS_REWORK Items

### N1: The same-directory (same-filesystem) temp invariant is untested — atomicity can regress silently
- **Finding:** `write_audit.sh:320–335` names this guard emphatically — the temp file
  "**MUST** be created in `$AUDIT_DIR` … `mv` across filesystems silently degrades to
  copy+unlink, which reintroduces the exact truncation window this fix exists to
  remove" — and the temp suffix "deliberately does NOT end in `.json`" so leftovers
  stay invisible to both `dev/audit/` glob consumers. **Neither half is pinned by any
  test.** Verified empirically: changing only line 336 to `mktemp` (temp in `$TMPDIR`)
  leaves the suite at **22 passed, 0 failed**. Scenario 19's stray-temp check asserts
  `count == 0`, which is satisfied both when the temp was created in `dev/audit/` and
  cleaned up *and* when it was never in `dev/audit/` at all — so it cannot detect the
  violation. Consequence: a later refactor of that one line (`mktemp`, `mktemp -t`, a
  `TMPDIR`-based variant, or a "tidier" `mktemp "${AUDIT_DIR}/tmp.XXXXXX.json"`)
  reintroduces either the truncation window or glob-visible temp litter, with full CI
  green and no reviewer signal. This is CP4 exactly: a docstring names the edge case,
  no test covers it.
- **Location:** `trading/devtools/checks/write_audit.sh:320–336` (the guard + the
  `mktemp` call); `trading/devtools/checks/record_qc_audit_test.sh:887–893` (scenario
  19's stray-temp assertion at 887 and its composite `if` at 889, the natural place for
  the fix).
- **Authority:** the script's own comments at `write_audit.sh:320–325` and `327–335`;
  restated in the `dev/status/harness.md` H-AUDIT-ATOMIC-WRITE entry ("same directory
  as `$OUTPUT_FILE`, hence guaranteed same filesystem" / "never ends in `.json` — it is
  invisible to both globs"). Both are contracts the PR advertises as delivered.
- **Required fix:** make the temp path observable and assert its shape. Cheapest form —
  have the existing abort hook print the path it staged
  (`echo "FAIL: WRITE_AUDIT_TEST_ABORT_BEFORE_RENAME set; … TMP_FILE=$TMP_FILE" >&2`),
  then in scenario 19 assert both properties from the captured `out19_2`:
  (a) the temp path's directory is `${TMP_REPO}/dev/audit` (pins same-filesystem), and
  (b) the temp basename does **not** end in `.json` (pins glob-invisibility).
  Confirm the new assertions fail under the `mktemp`-relocation mutation above.
  An equally acceptable alternative for (b): seed a leftover
  `…-<feature>.json.aBcDeF` file containing `"overall_qc": "NEEDS_REWORK"` and assert
  the `consecutive_rework_count` scan ignores it.
- **harness_gap:** `LINTER_CANDIDATE` — both properties are deterministic string
  assertions on a path emitted by an existing test-only hook; no inferential judgment
  needed, and they belong in the shell suite that already runs under `dune runtest`.

---

## Prior reviews

Reviewed SHA: f37379e0bc0d6d7a31c79d5de5dab7bf47b5a035

## Combined QC — PR #2155 `harness/check-universe-deps-residuals` (2026-07-28, orchestrator run 4)

**overall_qc: APPROVED** — merged as `14e14b24`. Zero rework iterations.

| Gate | Verdict | Quality | Review id | Posted at SHA |
|---|---|---|---|---|
| qc-structural | APPROVED | 5 | 4802689287 | `d74a49525ae4c4052f5c6e3876c68411bc9b280d` |
| qc-behavioral | APPROVED | 5 | 4802708124 | `d74a49525ae4c4052f5c6e3876c68411bc9b280d` |
| CI | green | — | — | re-verified on `40ba056419` immediately before merge |

Scope: closes the three FLAG residuals qc-behavioral raised on #2148 —
FLAG-1 (`universe_deps_exceptions.conf` unconstrained → `review_at` now required,
hard-FAIL per-PR in the guard plus weekly expiry via `deep_scan/check_11_linter_expiry.sh`),
FLAG-2 (candidate scan non-recursive → now `find`-based; `deep_scan/_lib.sh` and
`deep_scan/main.sh` resolved via exceptions with evidence checked against the real
`dune`), FLAG-3 (comment mis-credited assertion 5 instead of assertion 1).

**Merge-gate note.** Both reviews were posted at `d74a4952`. Main moved during the
run (#2156 landed), so the branch was `update-branch`d to `40ba056419` — a merge of
main; `git diff main...40ba0564` remained the identical 5 files / +304 −56, so the
QC verdicts carry — and CI was re-verified green on that new tip before merging.

**Behavioral method worth keeping.** 12 mutations, all executed live rather than
taken from the PR body. The decisive one was a **negative control**: the reviewer
restored the pre-#2155 non-recursive scan verbatim from `main`, confirmed a
subdirectory probe was invisible to it, then confirmed the new scan FAILs on the
same probe. That proves the FLAG-2 gap was real *before* accepting that it is
closed. It also re-verified the highest-risk change — the `_scan_exceptions_conf()`
extraction inside the already-wired weekly `check_11_linter_expiry.sh` — by running
old and new side by side and confirming the pre-existing `[EXPIRED]` finding for
`segmentation.ml` still fires byte-identically.

**One surviving mutation, non-blocking (FLAG).** `review_at: 2026-13-45` is accepted:
the date check is shape-only (`[0-9]{4}-[0-9]{2}-[0-9]{2}`), not calendar-validating.
This mirrors pre-existing laxity in the sibling `linter_exceptions.conf` and cannot
produce a false green for the guarded class — a bogus date can only affect *when*
something is re-reviewed, never whether a missing `(universe)` is detected.

**Residual filed** (`H-CHECK-RUNTARGET-PATHQUAL`, `dev/status/harness.md`): the awk
run-target regex `%\{dep:[A-Za-z0-9_.]+\}` excludes `/`, so a future path-qualified
`%{dep:subdir/foo.sh}` run-target would not match that branch. Inert today — no rule
uses that form.

Audit record: `dev/audit/2026-07-28-harness-check-universe-deps-residuals-harness.json`.

---

_Prior entry (superseded head line was: `Reviewed SHA: 1b3f809b04d184d1b335def771a3e1a1dca022b1`)_

## Structural Checklist — harness POSIX shell portability linter (PR #493, 2026-04-22)

Reviewed SHA: 1bb26c522a89fe82b6170f72939e9a2da4dd77e5 (tip of harness/posix-sh-linter)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | Exit 0; no format violations |
| H2 | dune build | PASS | Exit 0; clean build |
| H3 | dune runtest | PASS | Exit 0; new `posix_sh_check` and `posix_sh_check_test` alias stanzas both pass |
| P1 | Functions ≤ 50 lines | NA | Shell scripts only, no OCaml |
| P2 | No magic numbers | NA | No OCaml files |
| P3 | Config completeness | NA | No domain logic |
| P4 | .mli coverage | NA | No OCaml modules touched |
| P5 | Internal helpers prefixed with _ | NA | Shell helpers; linter scope does not introduce new OCaml |
| P6 | Tests conform to test-patterns.md | NA | Shell-based smoke test, not OCaml tests |
| A1 | Core module modifications | PASS | No Portfolio/Orders/Position/Strategy/Engine touched |
| A2 | No analysis/ → trading/ imports | PASS | Shell scripts, no imports |
| A3 | No unnecessary existing module modifications | PASS | `trading/devtools/checks/dune` extended with two alias runtest stanzas; no other existing files changed |

### Scope verification

| Concern | Evidence |
|---------|----------|
| dash -n over all #!/bin/sh scripts | `posix_sh_check.sh` walks `trading/devtools/checks/`, `trading/devtools/checks/deep_scan/`, `dev/lib/` and skips `#!/usr/bin/env bash` shebangs |
| Bad-fixture catches parse-time bash-isms | 3-assertion smoke test: bad fixture FAIL, clean fixture OK, bash-exempt OK — verified locally |
| Wired into `dune runtest` | `trading/devtools/checks/dune` — both stanzas run in `(alias runtest)` |
| 40 scripts covered at tip | Verified by running the linter against the repo: 0 violations |

### Verdict

**APPROVED** — POSIX-sh linter correctly gates the parse-time bash-ism class that caused the PR #483 rework cycle. Scope is contained to `trading/devtools/checks/`; no core module impact. Behavioral QC not required (harness utility, no domain logic).

### Quality Score

**4 — strong structural quality**

Focused single-concern change, new test provides evidence, catches the specific failure mode that motivated the work (bash array / heredoc parse-time errors). The linter correctly handles bash-exempt shebangs so pre-existing bash scripts aren't flagged.

---

## Structural Checklist — harness gha-cost-tracking (PR #483, re-review after POSIX-sh rework)

Reviewed SHA: 792b5b0901c963a021526e53223f6adaef65dcdf (re-review of PR #483 at tip after 2026-04-21 POSIX-sh rework applied by harness-maintainer)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | Exit 0; no format violations |
| H2 | dune build | PASS | Exit 0; clean build |
| H3 | dune runtest | PASS | Exit 0; **FIXED** — prior failure (`set: Illegal option -o pipefail` when dune invoked via `/bin/sh`) resolved by POSIX-sh rework. All dune tests pass including the new `budget_rollup_check.sh` smoke test (8/8 assertions) |
| P1 | Functions ≤ 50 lines | NA | No OCaml files changed; shell scripts only |
| P2 | No magic numbers | NA | No OCaml files changed |
| P3 | Config completeness | NA | No domain logic |
| P4 | .mli coverage | NA | No OCaml modules touched |
| P5 | Internal helpers prefixed with _ | NA | No OCaml internal functions; shell helpers `_repo_root`, `_extract_verdict` etc. correctly prefixed |
| P6 | Tests conform to test-patterns.md | NA | No OCaml tests |
| A1 | Core module modifications | NA | No Portfolio/Orders/Position/Strategy/Engine touched |
| A2 | No analysis/ → trading/ imports | NA | Shell scripts, no imports |
| A3 | No unnecessary existing module modifications | PASS | Only `trading/devtools/checks/budget_rollup_check.sh` + `dev/lib/budget_rollup.sh` changed in this commit (`git diff --name-only HEAD~1 HEAD` confirms — exactly two files) |

## POSIX-sh conformance verification

| # | Check | Status | Notes |
|---|-------|--------|-------|
| SH-SHEBANG | `#!/bin/sh` on both scripts | PASS | Shebang updated from `#!/usr/bin/env bash` to `#!/bin/sh` on both files |
| SH-SET | POSIX `set -eu` (no `pipefail`) | PASS | `set -eu` replaces prior `set -euo pipefail`; matches sibling `dev/lib/consolidate_day.sh` pattern |
| SH-BASHN | `bash -n` clean | PASS | `bash -n trading/devtools/checks/budget_rollup_check.sh` → exit 0; `bash -n dev/lib/budget_rollup.sh` → exit 0 |
| SH-DASHN | `dash -n` clean | PASS | `dash -n ...` on both scripts → exit 0 (dash available at `/usr/bin/dash`) |
| SH-SH-DIRECT | `sh budget_rollup_check.sh` passes | PASS | Direct invocation: all 8 smoke-test assertions pass |
| SH-HERE-STRING | `<<< ""` replaced | PASS | Replaced with `< /dev/null` for POSIX stdin redirection |
| SH-ARRAYS | bash arrays replaced | PASS | `MATCHED_FILES=()` / `MATCHED_FILES+=()` / `"${MATCHED_FILES[@]}"` replaced with tmpfile approach: matched paths written one-per-line to `$MATCHED_TMPFILE`, then `xargs python3 "$PYEOF_SCRIPT" < "$MATCHED_TMPFILE"` injects them as positional arguments. Semantically equivalent; handles filenames without spaces correctly (as did the prior array). The Python heredoc was extracted to a separate tempfile so `xargs` can combine script + file list cleanly |
| SH-BASH-SOURCE | `${BASH_SOURCE[0]}` replaced | PASS | Replaced with sourced `_check_lib.sh`'s `repo_root()` helper — the established pattern in this directory, handles both direct-run and dune-sandboxed invocation |
| SH-CONDITIONALS | `[[ ]]` replaced | PASS | No `[[ ]]` remaining; POSIX `[ ]` used throughout |
| SH-LOGIC-PRESERVED | Rollup semantics identical | PASS | All changes are syntactic (shell compatibility); no change to which JSON files are read, how totals are summed, or output schema. Verified by diff review |

## Diff scope

- `trading/devtools/checks/budget_rollup_check.sh`: +10 −5 (shebang, set, repo_root refactor, here-string → /dev/null)
- `dev/lib/budget_rollup.sh`: +22 −8 (shebang, set, array → tmpfile+xargs, extracted PYEOF tempfile)
- Total: 32 LOC across 2 files; within the 40 LOC rework budget. No scope creep (`git diff --name-only HEAD~1 HEAD` returns exactly those 2 paths).

## FYIs (non-blocking)

- **mergeable_state: "dirty"** — GitHub reports the PR as unmergeable-by-fast-forward. This is a docs-file conflict with PR #485 (run-1 daily summary, merged during run-2): both PRs touched `dev/status/_index.md` and `dev/status/harness.md`. Resolve at merge time with a trivial manual merge (#485's rows are stale relative to this PR's updates; use this PR's rows). Not a QC failure.
- **harness_gap reiterated:** a POSIX-sh portability lint (`dash -n` or `shellcheck` wired into `dune runtest` for scripts under `trading/devtools/checks/` and `dev/lib/`) would have caught the original bug at commit time. Carried into `dev/audit/2026-04-21-harness.json` as a `harness_gap` candidate-linter the prior run; cleared this run but still worth a future harness dispatch.

## Verdict

APPROVED

Behavioral review: N/A — harness/utility-script PR; no domain logic. Prior NEEDS_REWORK verdict at SHA d1ba14a3 (below in archive) is superseded.

## Quality Score

4 — The rework was cleanly scoped (exactly the required files, exactly the required changes), semantics-preserving (tmpfile+xargs idiom is the canonical POSIX substitute for the bash-array+expansion pattern), and verified with the fuller test battery this time (`bash -n` + `dash -n` + direct `sh` invocation, not just `dune runtest`). Docked one point because the original PR should have passed POSIX-sh checks in the first pass — the established codebase pattern (`dev/lib/consolidate_day.sh`, sibling check scripts) is explicit about `#!/bin/sh` + `set -eu`, so the original bash-only syntax represents an avoidable oversight.

---

## Structural Checklist (prior review — NEEDS_REWORK at d1ba14a3, 2026-04-21 run-1)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | No format violations |
| H2 | dune build | PASS | Clean build |
| H3 | dune runtest | FAIL | budget_rollup_check.sh fails: shell incompatibility (see NEEDS_REWORK) |
| P1 | Functions ≤ 50 lines (linter) | NA | No OCaml source functions in feature code paths |
| P2 | No magic numbers (linter) | NA | Harness track; no domain logic |
| P3 | Config completeness | NA | Harness track; no trading configuration |
| P4 | .mli coverage (linter) | NA | No OCaml modules in feature code paths |
| P5 | Internal helpers prefixed with _ | NA | No OCaml internal functions in feature code paths |
| P6 | Tests conform to test-patterns.md | NA | No OCaml tests in feature code paths |
| A1 | Core module modifications | NA | No Portfolio/Orders/Position/Strategy/Engine touched |
| A2 | No analysis/ → trading/ imports | NA | Harness track; no such imports |
| A3 | No unnecessary existing module modifications | PASS | Only devtools/checks/ (harness infrastructure) modified |

## Observations on Shell Scripts and Workflow YAML

### CRITICAL: H3 Test Failure — Shell Compatibility

The new test script `trading/devtools/checks/budget_rollup_check.sh` (153 lines) is wired into dune runtest on line 224–228 of `trading/devtools/checks/dune`:
```
(rule
 (alias runtest)
 (deps _check_lib.sh)
 (action
  (run sh %{dep:budget_rollup_check.sh})))
```

The script runs with `sh`, but line 15 uses `set -euo pipefail` (a bash-specific option):
```
set -euo pipefail
```

When dune executes `sh budget_rollup_check.sh`, the shell rejects the `-o` flag with: `set: Illegal option -o pipefail`. This causes `dune runtest` to fail.

All other check scripts in the same file (`rule_promotion_check.sh`, `rule_promotion_self_test.sh`) follow the established pattern:
- Shebang: `#!/bin/sh` (not `#!/usr/bin/env bash`)
- Use: `set -e` (POSIX standard, not bash-specific `set -euo pipefail`)
- Array syntax: not used (bash-ism)
- Conditional syntax: `[ ... ]` not `[[ ... ]]` (bash-ism)

### GHA Workflow "Capture run cost" Step

The new step in `.github/workflows/orchestrator.yml` (lines 155–251):
- ✅ Correct `if: always()` placement — runs even if orchestrator fails, capturing partial-run cost
- ✅ Correct step ID reference: `steps.run-orchestrator.outputs.execution_file`
- ✅ JSON parsing logic (Python) looks safe — guards against missing/malformed files with fallback to `null`
- ✅ No hardcoded secrets exposed; uses standard GitHub context variables

### Configuration and Documentation

- ✅ `dev/config/merge-policy.json`: valid JSON; model_prices block well-structured with three models (opus, sonnet, haiku) and pricing in per-million-token format
- ✅ `dev/status/cost-tracking.md`: clear status file; conforms to schema (Status: IN_PROGRESS, Interface stable: NO); documents limitations (per-subagent breakdown not available from action)
- ✅ `lead-orchestrator.md` Step 3.75b: removed hardcoded `~$2–4` estimate; now references model_prices block for cost calculation
- ✅ `lead-orchestrator.md` Step 7 "Budget" section: extended to read budget JSON if present, falls back to estimates; documentation is clear and self-consistent

### Sample Budget File

The file `dev/budget/2026-04-20-run1.json` is a valid example record with correct schema: `run_id`, `timestamp`, `commit_sha`, `measurement_source`, `fallback_branch`, `notes`, `subagents` array, and `totals` object with `total_cost_usd`.

### Stale-branch preflight

Branch is 2 commits behind `origin/main` — within acceptable range. No FLAG needed.

## Verdict

NEEDS_REWORK

## NEEDS_REWORK Items

### H3: Shell incompatibility in budget_rollup_check.sh

- Finding: The test script `trading/devtools/checks/budget_rollup_check.sh` uses bash-specific syntax but is invoked with `sh` by dune (line 228 of `trading/devtools/checks/dune`). Specific violations detected:
  1. Line 15: `set -euo pipefail` — the `-o pipefail` option is bash-only; POSIX sh rejects it with `set: Illegal option -o pipefail`
  2. Line 51: `<<< ""` (here-string) — bash-only syntax; causes `Syntax error: redirection unexpected` in POSIX sh
- Location: `trading/devtools/checks/budget_rollup_check.sh` (lines 15, 51); `trading/devtools/checks/dune` (line 228)
- Required fix: Rewrite `budget_rollup_check.sh` to conform to POSIX sh standards, matching the established pattern in the codebase:
  1. Change shebang from `#!/usr/bin/env bash` to `#!/bin/sh`
  2. Replace `set -euo pipefail` with `set -e` (POSIX standard)
  3. Replace here-string `bash "$ROLLUP" <<< ""` (line 51) with a POSIX alternative: either `echo "" | bash "$ROLLUP"` or `bash "$ROLLUP" < /dev/null`
  4. Verify all other bash-isms are removed
  5. Test locally: `sh trading/devtools/checks/budget_rollup_check.sh` should pass without errors
- harness_gap: LINTER_CANDIDATE — This could be caught by a pre-commit hook that runs `shellcheck -x -S warning` on all `*.sh` files under `trading/devtools/checks/` and `dev/lib/`, or by a dune rule that verifies shebang matches invocation method. However, the fix is deterministic and required for this PR.

---

## Quality Score: 2/5

**Rationale:**
- Architecture and design are sound: the workflow capture step is well-structured, the configuration is clean, the documentation is thorough.
- The cost-tracking design correctly identifies its limitations (per-subagent breakdown not available from action output; documented in dev/status/cost-tracking.md).
- However, the test script has a critical blocker: it does not conform to the established shell pattern used throughout the harness infrastructure. This causes `dune runtest` to fail immediately, making the PR unsuitable for merge until the shell compatibility issue is fixed.
- No behavioral review needed for this harness PR (shell scripts and YAML configuration only — no domain logic).

**Recommendation:** Fix the shell compatibility issue in budget_rollup_check.sh and re-run tests. Once H3 passes, this PR is structurally sound and ready for merge.

---

## Prior reviews (archive — deep-scan-drift-coverage + consolidate_day; both merged)


## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | Exit 0; no formatting diff |
| H2 | dune build | PASS | Exit 0; no compilation errors |
| H3 | dune runtest | PASS | Exit 0; all tests passed. No OCaml files changed in this PR. |
| P1 | Functions ≤ 50 lines (fn_length_linter) | NA | No OCaml files changed; shell script only |
| P2 | No magic numbers (linter_magic_numbers.sh) | NA | No OCaml files changed; shell script only |
| P3 | All configurable thresholds in config record | NA | No domain logic; harness plumbing script with no tunable parameters |
| P4 | .mli files cover all public symbols (linter_mli_coverage.sh) | NA | No OCaml files changed |
| P5 | Internal helpers prefixed with _ | PASS | Two shell functions: `_repo_root` and `_extract_verdict` — both correctly prefixed with _ |
| P6 | Tests use the matchers library | NA | No new test files; harness/shell PR |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | NA | No OCaml files touched; changes are limited to shell script, agent definition .md files, and dev/status/ |
| A2 | No imports from analysis/ into trading/trading/ | NA | Shell script with no library imports |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | `.claude/agents/lead-orchestrator.md` (Stage 4 addition to Step 5), `.claude/agents/qc-behavioral.md` (output contract note), and `dev/status/harness.md` (T3-G checkbox flip) are all in-scope for this T3-G task. No unrelated modules touched. |

## Harness-specific checks

| # | Check | Status | Notes |
|---|-------|--------|-------|
| SH1 | `set -euo pipefail` present | PASS | Line 1 of script body after shebang |
| SH2 | All variables quoted on error paths | PASS | All $VAR references in command positions are double-quoted; SCORE_ARG intentionally unquoted for word-split optional-arg idiom, covered by `# shellcheck disable=SC2086` comment |
| SH3 | Date validation anchored | PASS | `grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'` — correctly anchored with ^ and $ |
| SH4 | Primary verdict grep anchored at line start | PASS | `grep -oE "^$1: (APPROVED|NEEDS_REWORK)"` — anchored with ^; prevents false matches from embedded text |
| SH5 | Fallback overall_qc grep (line 110) unanchored | FYI | `grep -oE "overall_qc: (APPROVED|NEEDS_REWORK)"` lacks ^ anchor. In practice harmless: no existing review file has a false-match pattern (verified by grep audit of dev/reviews/). Non-blocking; future reviews with embedded prose containing that substring would produce a false extraction. |
| SH6 | Bold overall_qc format (`overall_qc: **APPROVED**`) not matched by either extraction path | FYI | Neither the primary (anchored) nor the fallback unanchored grep captures the bold variant. In practice this does not cause failures: all affected review files also contain a bare `overall_qc: APPROVED` line on a prior run. Behavioral awk fallback captures it correctly from `## Verdict` blocks anyway. Non-blocking. |
| SH7 | Exit codes on all error paths | PASS | All error paths call `exit 1`; `set -euo pipefail` ensures unexpected failures propagate |
| SH8 | Quality score awk handles bare and bold formats | PASS | `gsub(/^\*\*/, "", line)` strips leading `**` before digit check; tested manually: both `5 — rationale` and `**5 — rationale` return `5` |
| SH9 | Quality score uses LAST section (behavioral precedence) | PASS | awk accumulates `last_score` across all Quality Score sections; `END` block prints last value |
| SH10 | Stage 4 cleanly integrates into lead-orchestrator Step 5 | PASS | Stage 4 added after Stage 3 (PR draft-to-ready flip) and before Step 5.5 (status reconciliation); no conflicts with Stages 1/2/3 |
| SH11 | qc-behavioral output contract note | FYI | Documents canonical format for new reviews (`## Quality Score` + bare digit line). Unenforced convention — no lint gate or CI check validates this. Existing reviews with `### Quality Score` or bold-digit format are handled by multi-format extraction in record_qc_audit.sh. Non-blocking. |
| SH12 | Smoke test reproducibility | PASS | `bash trading/devtools/checks/record_qc_audit.sh backtest-scale feat/backtest-scale 2026-04-20` — writes `dev/audit/2026-04-20-backtest-scale.json` with `quality_score: 5` (not null), confirmed by direct execution |

## Verdict

APPROVED

Behavioral review: N/A — harness/orchestrator-plumbing PR; no domain logic.

---

## Structural Checklist — harness gha-cost-tracking re-review (PR #483 at tip a3075010d3a0a1e8ea89d2cc983965320bd1415b, post-rebase)

**Context:** This PR was previously APPROVED at SHA `792b5b09` (2026-04-21 run-2) after a POSIX-sh rework. The branch has since been rebased — the new tip is `a3075010d3a0` (2026-04-21 run-4), and it is 8 commits ahead and 3 behind the prior Reviewed SHA (force-push + main advanced during the window). This re-review confirms that all POSIX-sh fixes from the prior APPROVED review have survived the rebase and all hard gates remain passing.

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | Exit 0; no format violations |
| H2 | dune build | PASS | Exit 0; clean build |
| H3 | dune runtest | PASS | Exit 0; all tests pass including smoke test `budget_rollup_check.sh` (8/8 assertions) |
| P1 | Functions ≤ 50 lines | NA | No OCaml files changed; shell scripts only |
| P2 | No magic numbers | NA | No OCaml files changed |
| P3 | Config completeness | NA | No domain logic |
| P4 | .mli coverage | NA | No OCaml modules touched |
| P5 | Internal helpers prefixed with _ | NA | No OCaml internal functions; shell helpers correctly prefixed |
| P6 | Tests conform to test-patterns.md | NA | No OCaml tests |
| A1 | Core module modifications | NA | No Portfolio/Orders/Position/Strategy/Engine touched |
| A2 | No analysis/ → trading/ imports | NA | Shell scripts, no imports |
| A3 | No unnecessary existing module modifications | PASS | Only expected files changed; no scope creep |

## POSIX-sh Conformance Verification (Post-Rebase)

All POSIX-sh fixes from the prior APPROVED review are **confirmed intact**:

| # | Check | Status | Notes |
|---|-------|--------|-------|
| SH-SHEBANG | `#!/bin/sh` on both scripts | PASS | Both scripts retain shebang `#!/bin/sh` (not bash) |
| SH-SET | POSIX `set -eu` (no `pipefail`) | PASS | Both scripts use `set -eu`; `pipefail` not present |
| SH-BASHN | `bash -n` clean | PASS | Both scripts pass `bash -n` syntax check without errors |
| SH-DASHN | `dash -n` clean | PASS | Both scripts pass `dash -n` syntax check without errors |
| SH-HERE-STRING | `<<< ""` replaced | PASS | No bash here-strings present; POSIX stdin redirection used |
| SH-ARRAYS | bash arrays replaced | PASS | Tmpfile+xargs idiom intact; no bash array syntax |
| SH-BASH-SOURCE | `${BASH_SOURCE[0]}` replaced | PASS | Uses `$(dirname "$0")` and sourced `_check_lib.sh` helpers |
| SH-CONDITIONALS | `[[ ]]` replaced | PASS | Only POSIX `[ ]` conditionals present |

## Diff Scope (Post-Rebase)

10 files changed: `.claude/agents/lead-orchestrator.md`, `.github/workflows/orchestrator.yml`, `dev/budget/2026-04-20-run1.json`, `dev/config/merge-policy.json`, `dev/lib/budget_rollup.sh`, `dev/status/_index.md`, `dev/status/cost-tracking.md`, `dev/status/harness.md`, `trading/devtools/checks/budget_rollup_check.sh`, `trading/devtools/checks/dune` — consistent with prior review scope.

## Verdict

APPROVED

No structural regressions detected post-rebase. All POSIX-sh fixes are intact. Hard gates all pass (H1/H2/H3). Scope unchanged from prior review.

---

## Structural Checklist — consolidate_day (PR #467)

Reviewed SHA (consolidate_day): 6f2255639cb326745aad06f755de1839a9fe3847

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | Exit 0; no formatting diff |
| H2 | dune build | PASS | Exit 0; no compilation errors |
| H3 | dune runtest | PASS | Exit 0; all tests passed. No OCaml files changed in this PR. |
| P1 | Functions ≤ 50 lines (fn_length_linter) | NA | No OCaml files changed; shell script only |
| P2 | No magic numbers (linter_magic_numbers.sh) | NA | No OCaml files changed; shell script only |
| P3 | All configurable thresholds in config record | NA | No domain logic; consolidation script with no tunable parameters |
| P4 | .mli files cover all public symbols (linter_mli_coverage.sh) | NA | No OCaml files changed |
| P5 | Internal helpers prefixed with _ | PASS | Shell helper functions `extract_section` and `run_label` are not prefixed with _ but are local helpers defined inside the script body; no exported symbols. No violation — the _ prefix convention applies to OCaml module-level helpers. |
| P6 | Tests use the matchers library | NA | No OCaml test files; shell smoke test only |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | NA | No OCaml files touched |
| A2 | No imports from analysis/ into trading/trading/ | NA | Shell script with no library imports |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | `.claude/agents/lead-orchestrator.md` (Step 8b addition), `dev/status/harness.md` (follow-up bullet flip + Completed entry) are both in-scope for this task. No unrelated modules touched. |

## Harness-specific checks

| # | Check | Status | Notes |
|---|-------|--------|-------|
| SH1 | `set -euo pipefail` near top of script body | PASS | `set -eu` on line 15 of `dev/lib/consolidate_day.sh`. Note: `pipefail` is absent — the script uses `#!/bin/sh` (POSIX, not bash) and `pipefail` is a bash extension. `set -eu` is the correct POSIX equivalent. Smoke test uses `set -e` consistent with all sibling check scripts. |
| SH2 | Variables quoted on error paths | PASS | All `$DATE`, `$OUTPUT`, `$DAILY_DIR`, `$f`, `$LAST_FILE` references on error paths are double-quoted. No unquoted expansions in command positions on error branches. |
| SH3 | Date validation anchored with ^ and $ | PASS | `grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'` — anchored at both ends on line 24 |
| SH5 | No `overall_qc` grep used | NA | This script does not reference `overall_qc` — not applicable |
| SH6 | No `overall_qc` grep used | NA | This script does not reference `overall_qc` — not applicable |
| SH7 | Explicit exit codes on all error paths | PASS | Four `exit 1` calls: missing date arg (line 21), malformed date (line 26), missing .git root (line 41), no input files (line 76). `set -eu` catches unexpected failures. |
| SH-PORTABILITY | bash -n and dash -n both pass | PASS | `bash -n dev/lib/consolidate_day.sh` → OK; `dash -n dev/lib/consolidate_day.sh` → OK. Same for `trading/devtools/checks/consolidate_day_check.sh`. Script uses `#!/bin/sh` and is POSIX-clean. |
| SH-SMOKE-WIRING | Smoke test wired into dune runtest | PASS | `trading/devtools/checks/dune` has a new `(rule (alias runtest) (deps _check_lib.sh) (action (run sh %{dep:consolidate_day_check.sh})))` entry at line 190–198, consistent with sibling smoke tests. `consolidate_day.sh` itself is reached via `repo_root` (escaping dune sandbox), which is the same pattern used by `orchestrator_plan_check.sh` and other checks that read files outside the dune dependency graph. |
| SH-STEP8B | Step 8b wiring in lead-orchestrator.md | PASS | New `### Step 8b` section added after existing Step 8 merge-policy block; does not alter Step 8 PR-creation flow. Guard `[ "$_N" -ge 3 ]` is clear. git-mode branch (`TRADING_IN_CONTAINER`) amend path is explicit and includes fallback `git commit` if amend fails on an empty state. |
| SH-IDEMPOTENT | Output file is overwritten, not appended | PASS | Final write on line 381: `} > "$OUTPUT"` — redirection truncates and overwrites. Re-run test (assertion 6 in smoke test) explicitly verifies identical output on second run. |
| SH-SORT-V | sort -V used for numeric suffix ordering | PASS | Line 65: `done \| sort -V >> "$TMP_INPUTS"` — version-sort ensures `run10` > `run9` rather than lexicographic order. The run-1 base file is pre-pended before the sort loop, so ordering is: `${DATE}.md` first, then `-run2`, `-run3`, ..., `-runN` in numeric order. |
| SH-CONFLICT-DEDUP | Conflicting Outcomes for same (Track, Agent) get (run-N) suffix | PASS | awk dedup logic (lines ~155–185): when `key_ta` is already in `ta_seen` with a different outcome, `needs_suffix[key_ta]` is set and the Notes field of the new row gets `(run-N)` appended. The END block back-patches the first occurrence of that pair to also carry its run label. Covered by smoke test assertion 3 (NEEDS_REWORK row from run-2 and APPROVED row from run-3 for `feat-alpha / qc-structural` both appear in output). |

## Observations (non-blocking FYIs)

- **FYI — Line count vs spec target**: `dev/lib/consolidate_day.sh` is 384 lines; `trading/devtools/checks/consolidate_day_check.sh` is 208 lines; combined 592 lines exceeds the "≤ 250 combined if possible" guideline. However, the extra lines are substantively justified: the main script implements 7 distinct section handlers (Pending, Dispatched dedup, QC latest-per-track, Budget summed, Escalations dedup, Integration Queue, Per-run links) each with their own awk programs; the smoke test covers 9 assertions including idempotency and 3 error cases. No padding or dead code observed. Verdict: over-budget on line count but proportional to feature scope; not a FAIL.

- **FYI — Smoke test deps declaration**: the dune rule for `consolidate_day_check.sh` declares only `_check_lib.sh` as a `%{dep:...}`, not `consolidate_day.sh` itself. This is intentional and consistent with the established pattern — `repo_root` escapes the sandbox to reach `dev/lib/` directly. The implication is that dune will not automatically re-run the smoke test if only `consolidate_day.sh` changes without `consolidate_day_check.sh` also changing. This is the same trade-off accepted for `orchestrator_plan_check.sh`. Non-blocking; already an accepted harness convention.

## Verdict

APPROVED

Behavioral review: N/A — harness/orchestrator-plumbing PR; no domain logic.

---

## PR #2123 — `harness/audit-filename-collision` (H-AUDIT-COLLISION)

Reviewed at `fd41ed6a`. Orchestrator run 30262098532 (2026-07-27 run 3).

Fixes real, recurring data loss: `dev/audit/<date>-<feature>.json` silently clobbered a
same-day second QC of the same track (on 2026-07-27, run 2's record for
`feat/picks-phase-c-v2` overwrote run 1's for `feat/picks-phase-c`). New scheme:
`<date>-<branch-sanitized>-<feature>.json`, branch `/` → `-`, falling back to the old form
when `--branch` is empty. Implemented in `write_audit.sh` (where `OUTPUT_FILE` is actually
constructed; `record_qc_audit.sh` only extracts verdicts and delegates).

structural_qc: APPROVED
behavioral_qc: NEEDS_REWORK
overall_qc: NEEDS_REWORK (behavioral)

Rework iterations: 1 (dispatched this run).

### Structural — APPROVED (4/5)

Independently re-enumerated **every** `dev/audit/` reader rather than accepting the author's
claim:

1. `write_audit.sh:171` — `consecutive_rework_count` scan: `ls -1 "$AUDIT_DIR"/*-"$FEATURE".json`
2. `deep_scan/check_06_qc_calibration.sh:101` — `for audit_file in …/dev/audit/*-"${feature}".json`

Both glob by **suffix**, so inserting the branch segment *between* date and feature (rather
than appending it) leaves both patterns matching. Claim holds. Sanitization checked against
every documented branch convention (`feat/screener`, `feat/screener/sma`, `harness/…`,
`cleanup/…`) — all use only alphanumerics, hyphens and `/`, so `/` → `-` is sufficient.
POSIX clean (57 scripts). 8/8 scenarios pass. Scope exactly 3 files.

File list from the REST API per the A3 provenance requirement: `dev/status/harness.md`,
`trading/devtools/checks/record_qc_audit_test.sh`, `trading/devtools/checks/write_audit.sh`.

### Behavioral — NEEDS_REWORK (2/5)

**This is the case that justifies running both gates.** Structural correctly verified the
glob claim; behavioral found the fix introduced a *different* regression the glob analysis
could not surface.

**F1 — `consecutive_rework_count` ordering is now broken.** The glob is fine; the **ordering**
is not. Pre-fix, one date produced exactly one file, so `ls -1 … | sort -r` was a *total
chronological* order. Post-fix, multiple same-date records coexist and sort by **branch name
descending**, unrelated to write order. The scan `break`s on the first non-`NEEDS_REWORK` it
meets, so same-day records are consulted out of chronological order. Reproduced **in both
directions** on scratch `REPO_ROOT`s, one date, three records:

- `zzz=NEEDS_REWORK → aaa=APPROVED → mmm=NEEDS_REWORK` — correct 1, got **2** (over-count)
- `zzz=APPROVED → aaa=NEEDS_REWORK → mmm=NEEDS_REWORK` — correct 2, got **1** (under-count)

This lands on a live signal: the escalation policy fires at `>= 3` (`write_audit.sh:29-30`).
It is **not** a regression against pre-fix behaviour (pre-fix the record was destroyed
outright, which is worse), but it contradicts the PR body's "consumers preserved … unchanged"
framing.

**F2 (CP4) — the empty-`--branch` fallback has no test**, and it is the only remaining path
that can still clobber. Reachable three ways, including `record_qc_audit.sh <feature> "" <date>`
— three positional args satisfy the arity check, so an unset `$BRANCH` in the orchestrator's
own documented fallback invocation silently takes it.

**F3 (CP1) — three stale docstrings.** `write_audit.sh:4` and `record_qc_audit.sh:6` still
state the old filename; `record_qc_audit.sh:42` says idempotency is keyed on "same
date+feature" — **that sentence now describes the bug**.

### What the reviewer verified positively

- **Pre-existing old-format records are still discovered** — a seeded `2026-07-20-myfeat.json`
  (NEEDS_REWORK) before a new-format write yields `consecutive_rework_count=2`.
- **Scenario 7b asserts file *count***, not just content: `find … | wc -l` == 2, with A
  rewritten to `q=2` and sibling B untouched at `q=5`. A duplicate would fail it.
- **The new tests are genuine pins, not tautologies** — run against the pre-fix
  `write_audit.sh` (`fd41ed6a~1`), 7a and 7b both FAIL (`audit_count=0`).

### Orchestrator-owned follow-up

`.claude/agents/lead-orchestrator.md:1361,1415` also document the old filename path. The
author's edit there was blocked by the harness as "sensitive", correctly — the orchestrator
owns that file and updates it once the scheme lands.

### Rework iteration 1 — `fd41ed6a..7a6e9c34` — still NEEDS_REWORK (2/5)

**F2 CLOSED, F3 CLOSED, F1 OPEN.** The rework cap (2/run) is now reached; **#2123 is not merged**
and carries to the next run. Main is unaffected — the defect lives only on the branch.

**The F1 fix was a better design than the one suggested, and the reviewer endorsed the
rejection.** The orchestrator brief proposed `ls -1t` (mtime). The author declined, on the
grounds that `dev/audit/*.json` are **committed to git**, so a fresh CI checkout stamps every
file with checkout time — mtime carries zero write-order information across exactly the boundary
every orchestrator run crosses. (The same mtime assumption broke the orchestrator's own
"most recent daily summary" lookup in run 2.) It instead embeds `recorded_at_ns` at write time
and sorts on that. The reviewer independently confirmed this reasoning is right.

**But the implementation introduced a defect worse than the one it fixed.** `write_audit.sh:209`,
under `set -euo pipefail`:

```sh
f_recorded_at=$(grep -o '"recorded_at_ns": *[0-9]*' "$f" 2>/dev/null | head -1 | sed 's/.*: *//')
[ -z "$f_recorded_at" ] && f_recorded_at=0      # dead code — never reached
```

`grep` exits 1 on a legacy record → `pipefail` → `set -e` kills the script, so the intended
default-to-zero **can never execute**. Reproduced against the branch's own `dev/audit/`:
**0 of 76 committed records carry the field**; `record_qc_audit.sh portfolio-stops feat/bar
2026-07-27` → `rc=1`, **no record written and no error message**. It fires *only* on the
`NEEDS_REWORK` path (APPROVED skips the block), so it silently destroys precisely the records
feeding the `>= 3` escalation signal that F1 existed to protect. `write_audit.sh:63` asserts the
opposite of the observed behaviour (CP1 FAIL). **One-line fix (`|| true`) verified working.**

**The design underneath is sound.** With the crash patched, legacy records tie at `0` and GNU
`sort -rn` falls back to a reversed whole-line comparison → filename-descending = date-descending,
so legacy-only histories keep correct ordering (verified: 4 legacy records with a mid-sequence
APPROVED → correct count of 2). Legacy always sorts after new, which is chronologically right.
So this is a one-line defect, not a design flaw.

**Scenario 8 is a genuine pin, verified not assumed.** The reviewer extracted `write_audit.sh`
at both SHAs and ran the identical three-write sequence: `fd41ed6a` → `consecutive_rework_count: 2`
(the over-count from its own prior repro); `7a6e9c34` → `1` (correct).

Two further non-blocking findings:

- **N2** — `WRITE_AUDIT_RECORDED_AT_NS` is unvalidated and interpolated **unquoted**:
  `WRITE_AUDIT_RECORDED_AT_NS=oops` yields `"recorded_at_ns": oops,` — malformed JSON in a
  committed artefact. **It can leak into production writes.**
- **N3 (nit)** — `date -u +%s%N` is GNU-only; BSD/macOS emits a literal `N`, reaching the same
  invalid-JSON path.

**Format blast radius clean:** `check_06_qc_calibration.sh:101` globs by filename only with no
field-wise parse; the only field-wise reader is `write_audit.sh` itself, which is where the
defect lives.

**On F2 the reviewer explicitly endorsed pinning-not-fixing:** the scope boundary is real
(disambiguating an empty branch is new design), the gap is now named in three places, and
scenario 7c is a genuine change-detector. A test documenting a known-broken path is acceptable
when the contract names the gap.

structural_qc: APPROVED
behavioral_qc: NEEDS_REWORK
overall_qc: NEEDS_REWORK (behavioral)

Rework iterations: 1 of 2 used; **cap reached, not re-dispatched**. Next run resumes from here —
the remaining work is the one-line `|| true`, plus N2/N3 hardening.

## Quality Score

2

## Verdict

NEEDS_REWORK

### Rework iteration 2 — `7a6e9c34..4d1efcae` — APPROVED (both gates)

Orchestrator run 30273061906 (2026-07-27 run 4). Reviewed SHA `4d1efcae`, carried to
`bf07b639` after a branch update (all four reviewed files verified **byte-identical**;
the update brought only main's commits).

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

Rework iterations: 1 this run (2 cumulative across runs 3-4).

**F1 CLOSED, N2 CLOSED, N3 CLOSED.** The fix distinguishes two error classes rather than
treating them alike: an invalid `WRITE_AUDIT_RECORDED_AT_NS` is a *caller* bug and
hard-fails with a named message, while a BSD/macOS `date` lacking `%N` is a *platform*
quirk and degrades to `seconds * 10^9`. Both paths are validated by one
`_is_nonneg_int()` before anything reaches the JSON body.

**I reproduced the two defects myself before dispatching**, so the brief carried measured
evidence rather than a restated review: on a scratch `REPO_ROOT` with one legacy record,
the NEEDS_REWORK path exited **1 with no record and no error message**; with `|| true`
appended it exited **0** and wrote `consecutive_rework_count=2`. `WRITE_AUDIT_RECORDED_AT_NS=oops`
produced `"recorded_at_ns": oops,` — confirmed invalid by `json.load`.

**Structural — APPROVED (5/5).** Quoted the REST-derived file list per the A3 provenance
rule. Independently ran all three new scenarios against `7a6e9c34` and confirmed each
FAILS there and passes at head — so 9/10/11 are genuine change-detectors, not tautologies.
Verified `_is_nonneg_int()`'s `*[!0-9]*` case glob is POSIX and that the script passes both
`bash -n` and `sh -n`.

**Behavioral — APPROVED (4/5), with a new pre-existing finding.** This is the reviewer that
produced the decisive finding on both prior iterations, and it did the ordering work rather
than accepting the script's own comment:

- **Ties.** Three legacy records tying at `0` sort filename-descending = date-descending.
  It established this is *documented* behaviour (POSIX mandates whole-line last-resort
  comparison absent `-s`; GNU coreutils documents it) rather than an implementation
  accident — the distinction the script's comment was asserting without support.
- **The adversarial interleave.** One legacy plus three new records written
  `zzz`(NR) → `aaa`(APPROVED) → `mmm`(NR), chosen so alphabetical order *contradicts*
  write order. Correct answer 2; a filename sort yields 3; head produced **2**.
- **BSD fallback magnitude** orders correctly against real-ns and legacy `0`.

**N4 — new, real, pre-existing, non-blocking.** The author excluded the `prev_verdict`
extraction from scope, arguing `overall_qc` is required on every record (I confirmed
**81/81** current records carry it). The reviewer found the hole: `cat > "$OUTPUT_FILE" <<ENDJSON`
**truncates before filling**, so a run interrupted mid-write (SIGTERM on a cancelled CI job,
or the ENOSPC that `sweep-hygiene.md` documents as recurring here) leaves a record with
`recorded_at_ns` but no `overall_qc`. Seeded with one, the NEEDS_REWORK path exits 1 with
empty output and writes nothing — *the identical asymmetric shape as F1, eight lines below
it*. One such record permanently and silently disables audit writes for that feature on the
escalation path.

It then verified the same unguarded line exists on `main` at `fd41ed6a~1:write_audit.sh:155`,
so this is **not a regression** — this PR only marginally widens exposure. Held to
follow-up rather than forcing a fourth iteration, and for a stated reason beyond
proportionality: the one-line `|| true` is easy, but the *direction* is not obvious. An
empty `prev_verdict` breaks the streak, which **under**-counts and suppresses escalation —
the unsafe direction. That is a decision, not a patch, and it should not be bolted on under
time pressure. Same call it made on F2 last iteration, same reasoning, and right both times.

Also folded in: `|| true` swallows grep exit **2** (unreadable target) as well as no-match —
blast radius strictly smaller than N4's, filed with it.

**Method note worth carrying forward.** `_repo_root()` prefers `$0`'s `.git`/`.claude`
ancestor over `$REPO_ROOT`, so probing `write_audit.sh` from inside a repo worktree silently
exercises *that worktree's* `dev/audit/`, not the scratch one. The reviewer hit this on its
first pass and redid the harness from a neutral `/tmp` path. Anyone re-verifying this PR
should do the same. (My own repro was unaffected — `/tmp/f1repro` has no repo ancestor — and
its numbers match the reviewer's independently.)

## Quality Score

4

## Verdict

APPROVED

## PR #2148 — `harness/check-universe-deps` (MERGED `751de67d`)

Closes `H-CHECK-CACHE-BLIND`, the systemic form of PR #2143's qc-behavioral N1 finding.
A dune `(deps ...)` entry cannot name a path above the workspace root, so a check script
reading one via `repo_root()` has an incomplete dependency set: a warm `_build` skips the
rule and `dune runtest` returns green while the guarded file regressed.

Measured scope before dispatch: **25** scripts call `repo_root()`; the directory's `dune`
had 35 rules of which **3** declared `(universe)`; **23** scripts were exposed — including
`status_file_integrity.sh`, `index_size_linter.sh`, `no_python_check.sh` and
`posix_sh_check.sh`, all load-bearing CI gates.

Delivered: `(universe)` added to 20 rules, 3 proven exempt with evidence recorded in both
inline `dune` comments and `universe_deps_exceptions.conf`, plus a mechanical guard
(`check_universe_deps.sh`) and a fixture-isolated self-test (5/5). The guard declares
`(universe)` for itself.

**The warm-build pair was independently reproduced by the reviewer with a negative
control** — the evidence that distinguishes a real fix from a decorative one:

| direction | setup | result |
|---|---|---|
| negative control | `(universe)` stripped; warm build cached a clean PASS; then a real outside-workspace `.py` created with nothing dune-tracked touched | **zero invocation lines** for `no_python_check.sh`; `dune` exit **0** with a live violation on disk — the #2143 bug class, live |
| positive | `(universe)` present, same warm `_build`, same file | rule **re-executed**; `FAIL: no-python check -- unexpected *.py files found`; exit 1 |

Mutation ledger: M1 (strip `(universe)` from `status_file_integrity.sh`'s rule) → KILLED,
exit 1, names the script. M3 (strip it from the **guard's own** rule) → KILLED by the guard
itself, confirming self-coverage is pinned rather than merely present. M2 and M4 survived
by design and are recorded as FLAGs below.

Three non-blocking FLAGs, both survivors being prospective gaps with **zero live
instances**:

1. **`universe_deps_exceptions.conf` is unconstrained** — one bare filename disables the
   guard for any script, permanently, and the format has no `review_at` field even though
   the conf's own header cites `.claude/rules/code-health-discipline.md`, which requires
   one. The repo already expiry-checks the analogous `linter_exceptions.conf`. The filed
   residual `H-CHECK-EXEMPTION-DRIFT` covers the three *existing* entries going stale but
   not unbounded future additions.
2. **The candidate scan is non-recursive** (`./*.sh`), so `deep_scan/*.sh` is uncovered.
   Two live callers exist (`deep_scan/_lib.sh:28`, `deep_scan/main.sh:23`); neither is
   mis-covered today — one is an explicit dep of the exempted rule, the other is not
   dune-wired at all. Undisclosed by the PR; one-line fix.
3. Doc nit: the awk `RS`-ordering comment credits assertion 5; assertion 1 is what
   actually fails under that mutation.

Status quo was 23 exposed rules; this leaves **0 exposed among currently-wired top-level
rules**.

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

Rework iterations: 0.

Full verdicts are PR review comments on #2148 (the authoritative channel per PR-D'a):
structural `4801707730` (quality 4), behavioral `4801827392` (quality 4). Both were posted
at tip `1b3f809b`; the branch was then `update-branch`d to `47151062` (a merge of main, PR
content unchanged) and CI re-verified green there immediately before merging.

Note the structural reviewer **withheld its verdict** rather than approving while
`build-and-test` was still running, and recorded all structural gates as PASS. That is the
behaviour the standing `[medium]` escalation asks for.

## Quality Score

4 — Well-evidenced infra work whose load-bearing warm-build claim reproduced exactly in
both directions, with a self-covering guard; two prospective coverage gaps keep it off 5.

Reviewed SHA: 1b3f809b04d184d1b335def771a3e1a1dca022b1


## Combined QC — PR #2163 `harness/sete-diagnostics-audit` (2026-07-29, orchestrator run 30458563291)

**overall_qc: APPROVED** — **one rework iteration**, and the rework is the story.

| Gate | Iteration 0 (`eacbfb01`) | Iteration 1 (`be62f248`) |
|---|---|---|
| qc-structural | APPROVED, q5 (4809514994) | APPROVED, q5 (4809876066) |
| qc-behavioral | **NEEDS_REWORK, q2** (4809600822) | APPROVED, q4 (4809889502) |
| CI | — | re-verified green on the post-`update-branch` tip before merge |

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

Rework iterations: 1.

Scope: closes **H-CHECK-SETE-DIAGNOSTICS** (under `set -e`, `VAR=$(cmd); CODE=$?`
aborts before `CODE=$?`, so a real failure emits *no* diagnostic — the exact
signature `pr-merge-gates.md` lists as an admissible infra-flake exception, so
the hazard is a genuine regression being misfiled as a sandbox race). 22
candidates classified, 3 genuine defects fixed
(`jj_workspace_smoke.sh`, `linter_file_length.sh`, `linter_magic_numbers.sh`),
new `sete_diagnostics_check.sh` guard wired into `dune runtest`. Also folds in
the **H-WRITE-AUDIT-SHEBANG-MISMATCH** usage-comment half.

### Why iteration 0 was rejected — the fix introduced a worse bug than the one it fixed

The first pass guarded the two linters' reads with `|| continue`, which collapses
*vanished* and *unreadable-but-present* into one silent skip. qc-behavioral built
the discriminating case — a 350-line **violating** `lib/*.ml` made unreadable —
and measured:

- pre-fix: **exit 2** (loud, correct, unhelpfully shaped)
- post-fix: `OK: all lib/*.ml files within limits`, **exit 0**

That is a **false green in a merge-gating linter**, and it falsified the PR's own
claim that no existing file's pass/fail verdict changed. Note the asymmetry that
made this a blocker rather than a FLAG: the original bug produced a *correct
failure with a bad shape*; the regression produced a *silent wrong pass*. It also
proved the new guard pinned only **1 of 3** fixes — reverting both linter fixes
left it green 2/2.

### Why iteration 1 was accepted

Both blockers were re-tested under the **same mutations that found them**, by the
same reviewer:

- **Unreadable-but-present** → both linters exit 1 with a diagnostic naming the
  file. The decision is a *second* `[ -e ]` evaluated **after** the read fails,
  not the racy bare pre-check; `linter_magic_numbers.sh` probes with `cat` rather
  than trusting the `while … done < "$f"` compound's exit status.
- **Vanished file still tolerated** → fake `find` reporting a nonexistent
  `ghost.ml`: both linters exit 0 and skip quietly, and a ghost *followed by* a
  real violation still reports the violation. No flaky gate was traded for the
  false green — that second direction is what distinguishes a fix from an
  over-correction.
- **Guard coverage 3 of 3** → reverting each fix *alone* turns the guard red
  every time (7 assertions; 6-passed-1-failed in each case).

### Worth keeping — the fixture is better than the one that found the bug

The author's reproduction uses a **directory masquerading as a `.ml` file**
rather than the reviewer's `chmod 000`. The reviewer flagged this upward itself:
`chmod 000` only reproduces under an unprivileged user and would have **silently
passed under a root-running CI job**, which is exactly how this container runs.
Rationale is recorded in-tree citing `access(2)`.

### Open FLAG (non-blocking)

`write_audit.sh`'s bash-only choice is now pinned by an assertion (verified
load-bearing: replacing `set -euo pipefail` with `set -eu` turns it red), but
*why not* POSIX-clean is still unwritten, given the affected pipelines already
carry `|| true`. One clause would close it. The orchestrator-spec half of
**H-WRITE-AUDIT-SHEBANG-MISMATCH** — Step 5 Stage 4's `sh write_audit.sh`
invocation in `.claude/agents/lead-orchestrator.md` — remains correctly open and
escalated; that file is behind the agent write block.

Cosmetic residuals noted and correctly not reworked: `FIX3_*`/`FIX4_*` absent
from the `trap`; `cp`-vs-`die` asymmetry on missing deps;
`linter_magic_numbers.sh` now reads each file twice (correct, small I/O cost).

## Quality Score

4 — exemplary rework method; the digit reflects that iteration 0 shipped a
false-green regression into review, not the quality of the recovery.
