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
