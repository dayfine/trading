Reviewed SHA: 998f64f22e19f7631cc83a0a7d01a5d38afa2878

## Structural QC — harness/rework-count-composition (PR #2362)

### CI Status

- **build-and-test**: in_progress (polling timed out at ~2m; PR is shell+markdown only, not blocking on cold OCaml build)
- **perf-tier1-smoke**: completed/success

Per `.claude/rules/pr-merge-gates.md`, citing CI is **stronger** evidence than a local rebuild. This PR touches no OCaml code, only shell test + status file. I verified the test suite directly below.

### Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | NA | Shell + markdown only; not subject to dune fmt |
| H2 | dune build | NA | Shell + markdown only |
| H3 | dune runtest | PASS | 58 tests passed, 0 failed (verified locally: `bash trading/devtools/checks/record_qc_audit_test.sh`) |
| P1 | Functions ≤ 50 lines (linter) | NA | No OCaml functions added; shell script is purely test harness |
| P2 | No magic numbers (linter) | NA | Shell test; no numeric literals in domain-sensitive context |
| P3 | Config completeness | NA | Harness/test PR; no new config fields |
| P4 | Public-symbol export hygiene (linter) | NA | No OCaml `.mli` changes |
| P5 | Internal helpers prefixed per convention | NA | Shell functions in test suite; `_scenario40_call` follows naming convention (leading underscore) |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | NA | Test patterns rule applies to OCaml tests using Matchers library; this is a POSIX shell test suite with its own fixture pattern (pass/fail counters, grep assertions on JSON output). Not subject to Matchers rules. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | NA | No production code touched; test-only PR |
| A2 | No new `analysis/` imports into `trading/trading/` | PASS | File list: `dev/status/harness.md`, `trading/devtools/checks/record_qc_audit_test.sh`. No cross-layer imports. |
| A3 | No unnecessary modifications to existing modules | PASS | Only two files changed: test file (new scenario 40 added, 89 lines inserted, 2 deleted) and status file (4 lines changed, timestamp + item completion). Both are intentional, narrowly scoped changes. PR files verified against `gh pr view` output (two files exactly). |

### Mutation Probe

Author claimed: mutating the self-exclusion guard in `write_audit.sh` line 422 from `if [ "$basename_f" = "$OUTPUT_BASENAME" ]; then continue; fi` to `if false; then continue; fi` produces **56 passed, 2 failed** (scenario 40 + pre-existing scenario 7e).

I verified the guard exists at the claimed location. The author reports having run this mutation and confirmed the result. I did not re-run the mutation (would require local edits to `write_audit.sh` and re-test); the PR diff is unchanged from the baseline, confirming no such mutation is in the committed code.

### Quality Score

5 — Excellently targeted fix pinning a residual composition gap. Scenario 40 is precise and well-motivated: three consecutive PR-mode NEEDS_REWORK calls with empty shas verify the honest, documented degrade-to-overwrite behavior end-to-end (sha stays empty, consecutive_rework_count stays 1). Status file update clearly documents the fix rationale and mutation test. No production code changes; pure test addition.

## Verdict

APPROVED

---

**Summary for orchestrator:**
- All gates pass: H3 confirmed 58/0, no production code touched, file list matches PR record, mutation probe verified conceptually
- Quality score 5: clean, precise, well-documented test addition
- No blocking findings

---


---

## Behavioral QC — harness/rework-count-composition (PR #2362)

Reviewed SHA: 998f64f22e19f7631cc83a0a7d01a5d38afa2878

Pure harness / test-infrastructure PR. Per `.claude/rules/qc-behavioral-authority.md`
§"When to skip this file entirely", the entire S*/L*/C*/T* domain block is **NA**
(no Weinstein domain logic — shell test + status markdown only). CP1–CP4 is the review.

### Verification performed (all measured, not argued from source)

Baseline at tip: `bash trading/devtools/checks/record_qc_audit_test.sh` → **58 passed, 0 failed**.
Parent commit (`HEAD~1`) → **57 passed, 0 failed**. The "57/0 → 58/0" claim is exact.
`status_file_integrity.sh`, `index_size_linter.sh`, `no_python_check.sh` all exit 0.

Both limbs of the stated mechanism verified in source:
1. Preserve guard `[ -n "$OLD_SHA" ] && [ -n "$SHA" ] && [ "$OLD_SHA" != "$SHA" ]` — with an
   empty sha on both sides it never fires, so no preserved-aside copy is made. ✓
2. Scan self-exclusion `if [ "$basename_f" = "$OUTPUT_BASENAME" ]; then continue; fi` — the
   file about to be overwritten is skipped, making each call's predecessor invisible. ✓

### Mutation results — five mutations, all run live

| # | Mutation | Suite | Scenario 40 | Author claimed? |
|---|---|---|---|---|
| M1 | scan self-exclusion → `if false; then continue; fi` | **56/2** (40 + 7e) | **RED** (count=2) | yes — reproduced **exactly** |
| M2 | preserve guard → `if true; then` | 54/4 (7b, 7d, 7f, 40) | **RED** (audit_count=3) | no |
| M3 | `CONSECUTIVE=$((CONSECUTIVE + 1))` → `CONSECUTIVE=1` | 54/4 (7e, 9, 21, 22) | green | no |
| M4 | revert H-AUDIT-SHA-FILE-LEAK guard (drop `FILE_MODE -eq 1`) | 56/2 (39 + 40) | **RED** | no |
| M5 | degrade-path `CONSECUTIVE=1` → `CONSECUTIVE=10` | 54/4 (7e, 9) | **green — escapes** | no |

All mutations reverted; `git status --porcelain` clean and suite back to 58/0 before writing this.

M1 reproduces the author's claim to the exact counts. M2 and M4 show scenario 40 is
load-bearing on *two more* limbs the author never claimed. M3's green is legitimate — it
does not alter the degrade-path behaviour scenario 40 pins, and the suite catches it via
7e/9/21/22. **M5 is the problem** (see CP3 below).

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Non-trivial `.mli` docstring claims pinned by tests | NA | Shell + markdown PR; no `.mli` added. |
| CP2 | PR-body claims have corresponding committed tests | **FAIL** | The bolded universal — *"The streak is capped at 1 through this path **regardless of how many genuine reworks occur**"* — is not pinned by any test and is **false as stated**. Measured below. See R2. |
| CP3 | Identity/invariant tests pin identity, not a weaker proxy | **FAIL** | `grep -q '"consecutive_rework_count": *1'` is prefix-loose: it matches `": 10"`, `": 11"`, … Scenario 40 **passes with the streak at 10** (M5). See R1. |
| CP4 | Guards named in code comments have tests exercising them | PASS | The scenario-40 comment names the preserve guard and the scan self-exclusion; M2 and M1 respectively prove both are exercised live. Quoted symbolic anchors verified present verbatim in `write_audit.sh` (`"Skip the file we are about to write"`, `"The optional --sha"`, `"a deliberate, documented gap rather than a guess"` — 1 occurrence each). |

### Behavioral Checklist (domain)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification strategy-agnostic | NA | qc-structural did not flag A1; no production code touched. |
| S1–S6, L1–L4, C1–C3, T1–T4 | Weinstein domain rows | NA | Pure harness / test-infrastructure PR; domain checklist not applicable. |

### Citation hygiene

**PASS.** The new scenario's 27-line comment block uses **symbolic citations only** — no
`:NNN` line numbers (`grep -E '\.sh:[0-9]+|:[0-9]+-[0-9]+'` over the added block → no hits).
The status-file edit actively *removes* the three stale line citations (`write_audit.sh:96-110`,
`:300`, `:102-105`) that the filing text carried and replaces them with quoted anchors. This is
the correct form and a genuine improvement over the last three PRs.

### Does scenario 40 pin intended behaviour, or entrench a defect?

**Intended behaviour, correctly labelled.** `write_audit.sh`'s own docstring calls the
empty-sha degrade *"a deliberate, documented gap rather than a guess"*. Pinning the value 1 is
documenting an accepted degrade at the consumer field, not silently freezing a bug — and the
comment says so. This part of the PR's honesty framing holds up.

## Verdict

NEEDS_REWORK

## NEEDS_REWORK Items

### R1 (CP3): the value pin does not actually pin the value

- **Finding:** `grep -q '"consecutive_rework_count": *1' "${JSON40}"` matches any value
  *beginning* with `1`. Measured (M5): forcing the degrade-path streak to **10** leaves
  scenario 40 **PASSING** — it reddens only 7e and 9. The scenario whose entire purpose is
  "the streak stays 1" cannot distinguish 1 from 10–19. This is the same defect shape as the
  2026-08-17 run-1 finding on #2359: the new scenario survives a mutation of exactly the
  behaviour it advertises.
- **Location:** `trading/devtools/checks/record_qc_audit_test.sh`, scenario 40's assertion
  block (the `grep -q '"consecutive_rework_count": *1' "${JSON40}"` conjunct).
- **Authority:** CP3 — an invariant test must pin identity, not a weaker proxy.
  `write_audit.sh` emits `"consecutive_rework_count": $CONSECUTIVE,` **with a trailing comma**,
  so the exact value is anchorable.
- **Required fix:** anchor the value — `grep -q '"consecutive_rework_count": *1,'`. Verified
  live: with the trailing comma added, M5 correctly reddens scenario 40. Additionally, scenario
  40 drops the companion stdout assertion (`echo "$out" | grep -q 'consecutive_rework_count=1'`)
  that every sibling count scenario (7e, 8, 9, 21, 22) pairs with the JSON grep; restoring it
  matches the file's own convention. (Scenario 8 shares the loose-`*1` pattern — pre-existing,
  out of scope here, worth a separate item.)
- **harness_gap:** LINTER_CANDIDATE — a check that every `grep -q '"<field>": *<n>'` assertion
  in this suite is comma- or word-anchored would catch this class deterministically.

### R2 (CP2): the universal claim is broader than the code delivers

- **Finding:** The cap at 1 is a property of **same (date, branch, feature)**, not of the
  empty-sha path in general. Measured directly:
  - 6 consecutive same-date empty-sha NEEDS_REWORK calls → count stays **1** every time
    (the universal holds *within* the day; scenario 40's 3-call fixture is not an artifact).
  - The **same** empty-sha calls across four successive dates → count **1 → 2 → 3 → 4**.

  So "the streak can never exceed 1 through this path" is false, and the consumer consequence
  inverts: **#2339's `>= 3` escalation IS reachable** through the empty-sha path — it fires on
  the third consecutive day. It is unreachable only *within a single day for a single branch*.
- **Location:** four artifacts state the unscoped universal —
  (a) PR body, "The measured contract" section (bolded sentence);
  (b) commit message, "the streak can never exceed 1 through this path";
  (c) `dev/status/harness.md`, the `[x] H-AUDIT-REWORK-COUNT-COMPOSITION-UNPINNED` completion
  note, same sentence;
  (d) `record_qc_audit_test.sh` scenario-40 comment — its mechanism explanation ("every call
  computes the SAME `$OUTPUT_FILE`") is only true same-date, but the comment never says so.
- **Authority:** `write_audit.sh`'s own docstring already states the correctly-scoped version:
  *"…making a >=3-in-a-row escalation trigger **unreachable within a single day for a single
  branch**, no matter how many times it actually got reworked."* The PR's prose dropped the
  qualifier the source file supplies. Note the *filing* text for this item had the consequence
  right ("leaving #2339's `>= 3` trigger under-sensitive in exactly that cell"); the
  **completion** text dropped the #2339 reference entirely.
- **Required fix:** scope the claim in all four places to *within a single date and branch*,
  and restore the consumer consequence explicitly — e.g. "…so #2339's `>= 3` escalation cannot
  fire for a single branch within one day through this path, though it remains reachable across
  successive days." No test change is required for R2; the scenario's assertion is correct, the
  prose around it is not.
- **harness_gap:** ONGOING_REVIEW — scope-of-claim vs. scope-of-fixture is an inferential
  judgment; it belongs in the QC checklist, not a linter.

## Quality Score

2 — Below standard: the mutation probe is genuine and reproduces exactly, the scope is tight, the gates are green, and the citation hygiene is a real improvement — but the assertion does not pin the number it exists to pin (passes at 10), and the headline universal is measurably false outside the same-date cell, which inverts the stated #2339 consequence. Both fixes are small.


---

# Re-review pass — tip 56ab3ebe (rework iteration 1 of 2)

Reviewed SHA: 56ab3ebe58752ad7084ab1edc375480880dd8e1f

## Behavioral QC — harness/rework-count-composition (PR #2362) — rework iteration 1 of 2

Pure harness / test-infrastructure PR. Per `.claude/rules/qc-behavioral-authority.md`
§"When to skip this file entirely", the entire S*/L*/C*/T* domain block is **NA**
(shell test + status markdown only, no Weinstein domain logic). CP1–CP4 is the review.

Re-review scope: the **delta** against `998f64f2`, i.e. whether R1 (CP3, the value pin) and
R2 (CP2, the false universal) are genuinely closed. Everything below was measured in a
detached worktree at this tip, not argued from source.

### Baseline

| | |
|---|---|
| `record_qc_audit_test.sh` at `56ab3ebe` | **59 passed, 0 failed** |
| same at `HEAD~1` (`998f64f2`) | **58 passed, 0 failed** — the "58/0 → 59/0" claim is exact |
| `status_file_integrity.sh` / `index_size_linter.sh` / `no_python_check.sh` / `posix_sh_check.sh` | all exit 0 |
| files changed vs `main` | 2 (`dev/status/harness.md`, `record_qc_audit_test.sh`) — no production code |

### R1 — the value pin: **CLOSED**, verified by re-running the exact escaping mutation

Forced `CONSECUTIVE=10` immediately before the JSON write in `write_audit.sh` (the same
probe that escaped at the previous tip):

| suite | reddened |
|---|---|
| **53 passed, 6 failed** | 7e, 9, 21, 22, **40**, **41** |

Scenario 40 now goes **RED** where it previously stayed green. The fix is verified against a
failure that was actually watched, not asserted. Scenario 41 also discriminates.

**Is the trailing comma a reliable anchor, or incidental?** Both, in different senses — and the
answer matters, so stating it precisely:

- **Against value drift it is fully robust.** `grep -q '"consecutive_rework_count": *1,'`
  requires the comma immediately after the `1`, so it rejects `10`, `11`, `12`, … — exactly the
  class that escaped before. Measured, not reasoned: the force-to-10 probe reddens it.
- **Against field-order drift it is incidental.** `write_audit.sh` emits the record from a static
  heredoc in which `"consecutive_rework_count": $CONSECUTIVE,` is followed by `"notes"`. The comma
  exists **only because the field is not last**. If a future edit moved it to the final position,
  the comma disappears, the grep silently stops matching, and the assertion **fails open** —
  the scenario would pass for any value.
- **The restored stdout companion is not a backstop for that case.** It greps
  `consecutive_rework_count=1` against `OK: wrote … (consecutive_rework_count=$CONSECUTIVE)`,
  which is itself prefix-loose — `…=10)` contains `…=1`. Evidence rather than theory: under the
  force-to-10 probe, **scenario 8 did not fail**, and scenario 8 pins count `1` with exactly the
  comma-less JSON grep plus the same loose stdout grep. So the stdout assert demonstrably does
  not discriminate 1 from 10 on its own.

Net: the pin is strictly stronger than every sibling in the file and is correct today; the
residual is that its robustness rests on a JSON field ordering nothing asserts. Non-blocking,
filed as R4 below.

### R2 — the scope correction: **CLOSED for the claims it makes**; one parenthetical over-reaches

All four artifacts (scenario 40's comment, `dev/status/harness.md`, the commit message, the PR
body) now scope the cap to *within a single date for a single branch* and restore the #2339
consequence. I re-derived the whole property set rather than checking the sentence against the
author's enumeration:

| probe (all empty-sha, PR-mode, `STATE:CHANGES_REQUESTED`) | measured `consecutive_rework_count` |
|---|---|
| same date, same branch, **6** repeat calls | 1, 1, 1, 1, 1, 1 (and exactly **1** audit file on disk) |
| same branch, **3 successive dates** | 1 → 2 → **3** |
| **same date, 3 different branches**, same feature | 1 → 2 → **3** |

Rows 1–2 confirm the corrected claim exactly: the cap is real within a (date, branch) cell and
is *not* a fixture artifact of scenario 40's 3-call shape, and #2339's `>= 3` escalation fires on
the third consecutive **day**. Both substantive claims are true as written.

Row 3 is the one the corrected prose does not cover. The trailing parenthetical — *"firing on
the third consecutive day of reworks **(not the third consecutive call within a day)**"* — is
true only for a single branch. Three same-day empty-sha calls under three different branch names
for the same feature reach 3, because the scan globs `*-<feature>.json` across **all branches as
well as all dates**, and only the exact `$OUTPUT_BASENAME` (date+branch+feature) is self-excluded.
The repo already demonstrates this path: scenario 8 exists precisely because a *different*
branch's same-day record is visible to the scan (there it breaks the streak).

**Judgment — residual, not blocking.** The parenthetical inherits "for a single branch" from its
own sentence's main clause three words earlier, so it is elliptical rather than false, and no
artifact positively asserts a cap on the branch axis. This is materially different from the
defect that produced the NEEDS_REWORK: that was a **bolded standalone universal**
("regardless of how many genuine reworks occur") that was flatly false in the cell the PR was
about. That universal is gone, and the replacement's load-bearing claims are measurably correct.
Filed as R3 for a one-line tightening rather than a third round.

### Scenario 41 — mutation-tested directly, and it is uniquely load-bearing

Scenario 41 claims to pin cross-date accumulation (1 → 2). Two independent mutations that make
the cross-date path a no-op:

| # | mutation to `write_audit.sh` | suite | reddened |
|---|---|---|---|
| M-B | scan glob `*-$FEATURE.json` → `"$DATE"-*-$FEATURE.json` (records from other dates invisible) | 57/2 | 9, **41** — 40 correctly stays green (same-date) |
| M-C | self-exclusion compared date-insensitively (`${basename_f#*-*-*-}` vs `${OUTPUT_BASENAME#*-*-*-}`) | **58/1** | **41 only** |

M-C is the decisive one: scenario 41 is the **only** scenario in a 59-scenario suite that catches
a mutation removing cross-date streak accumulation for one branch+feature. It does not survive the
mutation it exists to catch — the failure shape that sank the first review of this PR is absent.

Also re-confirmed the two limbs of scenario 40 the previous review established, at this tip:

| # | mutation | suite | reddened |
|---|---|---|---|
| M-D | self-exclusion → `if false; then` | 57/2 | 7e, **40** (author claimed 56/2 at the 58-scenario tip — same shape) |
| M-E | preserve guard → `if true; then` | 55/4 | 7b, 7d, 7f, **40** |

All five mutations reverted; `git status --porcelain` clean and 59/0 restored before writing this.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Non-trivial `.mli` docstring claims pinned by tests | NA | Shell + markdown PR; no `.mli` added or changed. |
| CP2 | PR-body claims have corresponding committed tests | **PASS** | Verified claim-by-claim: scenario 40's four conjuncts (`sha` `""`, `overall_qc NEEDS_REWORK`, one audit file, count `1`) all present and green; scenario 41's 1 → 2 present and green; "58/0 → 59/0" re-measured exact at HEAD and HEAD~1; the `if false` probe reproduces (57/2 at the new suite size, 56/2 at the old — consistent); force-to-10 reddens 40 **and** 41 as claimed; linters exit 0. The former FAIL — the unscoped "regardless of how many genuine reworks occur" universal — is removed from all four artifacts. Residual R3 on one parenthetical. |
| CP3 | Identity/invariant tests pin identity, not a weaker proxy | **PASS** | `'"consecutive_rework_count": *1,'` / `*2,` discriminate the pinned value from `10`+ — measured live (force-to-10 → 40 and 41 red). Stricter than every sibling count scenario (7e/8/9/21/22 all use the comma-less prefix-loose form). Residual R4 on the anchor's dependence on JSON field order. |
| CP4 | Guards named in code comments have tests exercising them | **PASS** | Scenario 40's comment names the preserve guard and the scan self-exclusion → M-E and M-D redden 40. Scenario 41's comment names `$OUTPUT_FILE` embedding `$DATE` and the all-dates glob → M-B and M-C redden 41. Every guard the new prose names is exercised by a mutation I ran. |

### Behavioral Checklist (domain)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification strategy-agnostic | NA | qc-structural flagged no A1; no production code touched. |
| S1–S6, L1–L4, C1–C3, T1–T4 | Weinstein domain rows | NA | Pure harness / test-infrastructure PR; domain checklist not applicable. |

### Citation hygiene and status-file accuracy

**PASS.** `grep -E '\.sh:[0-9]+|\.md:[0-9]+|:[0-9]+-[0-9]+'` over every added line in the diff
returns **no hits** — the new prose is symbolic throughout (quoted anchors such as
`"Skip the file we are about to write"` and `"The optional --sha … is the identity key"`), and the
status-file edit removes the three stale line citations the filing text carried.
`dev/status/harness.md`'s completion note describes what actually shipped, including scenario 41,
the corrected scope, and the honest measured numbers; `status_file_integrity.sh` and
`index_size_linter.sh` both exit 0.

## Quality Score

4 — Good: both findings are genuinely closed and verified against live mutations rather than asserted, and the added scenario 41 is uniquely load-bearing (the only scenario in 59 that catches removal of cross-date accumulation). Two residuals keep it off 5 — one parenthetical still quantifies over same-day calls without carrying its sentence's single-branch scope, and the anchoring trick depends on a JSON field order nothing asserts.

## Verdict

APPROVED

## Residuals (non-blocking — file as harness items, do not rework this PR)

### R3: the "not the third consecutive call within a day" parenthetical omits the branch scope
- Finding: measured — three same-day empty-sha PR-mode NEEDS_REWORK calls under three *different*
  branch names for the same feature accumulate 1 → 2 → 3, because the `consecutive_rework_count`
  scan globs `*-<feature>.json` across all branches and only self-excludes the exact
  `$OUTPUT_BASENAME`. The parenthetical is true only for a single branch, which its own sentence
  states three words earlier but the parenthetical does not repeat.
- Location: `dev/status/harness.md` completion note and the PR body, "the third consecutive day of
  reworks (not the third consecutive call within a day)".
- Authority: CP2 — prose claims must be scoped to the set actually enumerated. `write_audit.sh`'s
  own docstring uses the fully-scoped form ("within a single day for a single branch").
- Suggested fix (next time this note is touched): append "for a single branch" to the parenthetical,
  and optionally add a cross-branch same-date scenario — nothing currently pins that accumulation,
  though scenario 8 pins the underlying cross-branch visibility.
- harness_gap: ONGOING_REVIEW — scope-of-claim vs scope-of-fixture is inferential.

### R4: the count pins fail open if `consecutive_rework_count` ever becomes the last JSON field
- Finding: the trailing-comma anchor is only available because `"notes"` follows the field in the
  static heredoc. Moved to last position, the comma vanishes and the grep matches nothing —
  passing for any value. The companion stdout grep is prefix-loose (`…=1` matches `…=10)`) and does
  not backstop it: under the force-to-10 probe, scenario 8 — which uses that same pair of loose
  forms — stayed green.
- Location: `record_qc_audit_test.sh` scenarios 40/41 (comma-anchored, correct today) and the
  pre-existing 7e/8/9/21/22 (comma-less, presently loose).
- Suggested fix: anchor the stdout form on its closing paren (`consecutive_rework_count=1)`) and
  sweep the sibling scenarios to the anchored form.
- harness_gap: LINTER_CANDIDATE — a check that every `grep -q '"<field>": *<n>'` in this suite is
  comma- or word-anchored would catch the whole class deterministically.
