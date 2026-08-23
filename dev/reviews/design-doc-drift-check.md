Reviewed SHA: 43379335

> Rework lineage: structural APPROVED @ 775aa1bc31ab7322721aed3ada0a3e264e10fe4e;
> behavioral NEEDS_REWORK @ the same SHA (2 blocking); rework commit 43379335
> addressed all 6 findings; structural and behavioral BOTH re-APPROVED @ 43379335.
> The line above tracks the CURRENT reviewed SHA — the sections below are kept in
> chronological order, so the earliest ones pin 775aa1bc.

## Structural QC — harness/design-doc-drift-check (PR #2494)

### Summary

This PR adds a mechanized per-PR CI gate (`backtest_appendix_drift_check.sh`) that fails the build if any subdirectory under `trading/trading/backtest/` (excluding the documented `lib/`, `test/`, `scenarios/`) lacks a corresponding row in the appendix table of `dev/plans/backtest-scale-optimization-2026-04-17.md`. The appendix had drifted twice already (PR #2096 → PR #2461), purely from feature PRs not adding rows. A durable linter replaces hand-maintained reconciliation.

### Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | CI green at 775aa1bc; scoped local `dune build @fmt` on trading/ also passes |
| H2 | dune build | PASS | CI green at 775aa1bc |
| H3 | dune runtest | PASS | CI green at 775aa1bc; scoped `dune build @devtools/checks/runtest --force`: both backtest_appendix_drift_check.sh and backtest_appendix_drift_check_test.sh exit 0 with "OK:" output |
| P1 | Functions ≤ 50 lines (linter) | NA | Shell scripts; no function-length rule applies. Inspected by hand: check script's main logic is straightforward guards + a single awk/sed pipeline + sort + comm + error reporting; test script's helper functions (_make_fixture, _run_check, _assert_exit, _assert_contains) are all under 20 lines. Linter scope. |
| P2 | No magic numbers (linter) | NA | Shell scripts; no magic-numbers linter applies to sh. No hardcoded thresholds in the logic — the script uses `comm -23` (standard set diff) and awk's line-matching (`^` anchors, exact heading text). Linter scope. |
| P3 | Config completeness | NA | Harness/linter PR, no domain knobs or thresholds. The three subdirectory exclusions (lib/test/scenarios) are hardcoded per the documented plan-file scope note (2026-08-21); hardcoding is intentional so a change to the exclusion set requires a two-file edit (plan + script), not silent divergence. Linter scope. |
| P4 | Public-symbol export hygiene (linter) | NA | Shell scripts; .mli coverage linter does not apply. Linter scope. |
| P5 | Internal helpers prefixed per convention | NA | Shell scripts; underscore-prefix convention does not apply to shell. Scripts use clear naming (_make_fixture, _run_check, _assert_exit, _assert_contains for test helpers). No OCaml module naming rules. Linter scope. |
| P6 | Tests conform to test-patterns.md | NA | No OCaml test files in this PR. Fixture-driven shell test (backtest_appendix_drift_check_test.sh) uses synthetic repo roots (via REPO_ROOT override) to exercise all code paths without depending on live repo state — the canonical approach for shell script tests in this harness suite. Test scope. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | NA | Harness/devtools PR; no core modules touched. |
| A2 | No new `analysis/` imports into `trading/trading/` outside backtest exception | NA | Harness PR; no source-code imports, only shell-script checks reading files. |
| A3 | No unnecessary modifications to existing modules | PASS | PR files: `trading/devtools/checks/backtest_appendix_drift_check.sh` (new), `trading/devtools/checks/backtest_appendix_drift_check_test.sh` (new), `trading/devtools/checks/dune` (+34 lines for two new rules + one docstring), `dev/status/cleanup.md` (one line: checked-off item), `dev/status/harness.md` (narrative addition). Zero changes to dev/plans/backtest-scale-optimization-2026-04-17.md itself (drift was already resolved in PR #2461). Verified: `git diff HEAD~1 HEAD dev/plans/...md` produces no output. |

### Key Findings

**1. Drift measurement independent verification:**
- Re-measured on-disk subdirectories vs. appendix rows by hand on the current worktree
- On-disk count: 30 total directories, 27 after excluding lib/test/scenarios
- Appendix table: exactly 27 rows (verified via grep-and-sed extraction)
- Set difference (comm -23): zero drift — every on-disk subdir has a row
- Confirms the agent's claim: the tree is clean (27/27), PR adds no rows, lands the check on an already-safe state

**2. Vacuous-pass guards — mutation test results:**
- **Guard 1** (appendix heading found): Fires correctly when heading is absent; stops execution before reaching later guards. Deleted version falls through to guard 2.
- **Guard 2** (zero table rows parsed): Fires when heading is present but no rows match the sed pattern. Fired in deleted-guard-1 scenario; backstops guard 1 for the "no rows" case.
- **Guard 3** (zero on-disk subdirs after exclusions): **Critical guard.** Deleted version produces exactly the false positive documented in the brief: `OK: backtest_appendix_drift_check — 0 on-disk subdirectories under trading/trading/backtest/ (excluding {lib test scenarios}), all have an appendix row.` With guard present, same empty-backtest-dir fixture correctly fails with `FAIL: found ZERO subdirectories ... expected several.` Guard 3 is load-bearing and cannot be removed without breaking the check.

All three guards are exercised in backtest_appendix_drift_check_test.sh's six scenarios (clean, missing-row, no-heading, no-rows, empty-backtest-dir, exclusions). Each scenario asserts both exit code and output content.

**3. Test suite — all 6 scenarios pass:**
- Scenario 1 (clean): 2 on-disk subdirs + matching 2-row appendix → OK, exit 0
- Scenario 2 (missing-row): 2 on-disk (alpha, beta) + 1-row appendix (alpha only) → FAIL with "beta/" named, exit 1
- Scenario 3 (no-heading): plan file exists, heading absent → FAIL with guard-1 message, exit 1
- Scenario 4 (no-rows): heading present, no parseable rows → FAIL with guard-2 message, exit 1
- Scenario 5 (empty-backtest-dir): backtest dir empty after exclusions → FAIL with guard-3 message, exit 1
- Scenario 6 (exclusions): lib/test/scenarios present + no rows for them, alpha covered → OK (proves hardcoded exclusion works), exit 0

Each scenario runs independently with synthetic REPO_ROOT; test never depends on live repo state. Test assertions use string matching on both exit codes and output content.

**4. POSIX sh compliance:**
- Ran posix_sh_check.sh against both new shell scripts
- Both scripts pass (79 scripts clean report includes them)
- Key invariants verified: `#!/bin/sh`, `set -eu`, no bash-specific syntax (no `${BASH_SOURCE}`, `<<<`, bash arrays)
- Uses only POSIX builtins and standard utilities (awk, sed, sort, comm, find, grep, mktemp, printf, basename)

**5. No Python:**
- Verified no .py files in new PR files
- Both scripts are pure shell

**6. Dune wiring — sandboxing and cache invalidation:**
- Main check rule: declares `(universe)` dep since it reads dev/plans/* and trading/trading/backtest/* via repo_root() outside the sandbox. Correct per H-CHECK-CACHE-BLIND (issue #919, #943).
- Test rule: declares explicit deps (backtest_appendix_drift_check.sh, _check_lib.sh) but NOT (universe), since test uses synthetic REPO_ROOT fixtures and doesn't read the live repo files. Correct.
- check_universe_deps.sh confirms wiring: "OK: backtest_appendix_drift_check.sh -- owning rule (run-target) declares (universe)"
- No cross-boundary file reads outside the declared deps

**7. Status files — appropriate, plan file untouched:**
- dev/status/cleanup.md: Checked off `design_doc_drift_mechanization` item with detailed narrative of the work
- dev/status/harness.md: Added 50-line section documenting the implementation, including the guard-mutation results
- dev/plans/backtest-scale-optimization-2026-04-17.md: Zero changes (drift already resolved; PR adds no new rows)
- dev/status/_index.md: Zero changes (per orchestrator contract, agents do not modify the index)

**8. Distinction from deep_scan/check_02_design_doc_drift.sh:**
- Existing check_02: runs weekly, is warning-only (loose substring grep against whole doc text)
- This new check: runs per-PR, FAILs the build, requires actual appendix TABLE ROW (not just text mention anywhere)
- New check is stricter and catches drift before merge, not days later in a scan

## Quality Score

5 — Clean implementation, comprehensive test coverage, three load-bearing guards all verified by mutation, dune wiring correct, POSIX-compliant, no domain logic (harness scope), and the work is complete on an already-clean tree (drift pre-resolved). No findings.

## Verdict

APPROVED


---

# Behavioral QC re-review @ 43379335 (rework iteration 1)

## Behavioral QC — design-doc-drift-check (re-review after rework iteration 1)

Pure harness PR. Verified in my own detached worktree at 43379335 (`/__w/trading/wt-qc2494b`, plain `git worktree add --detach`; the originally-assigned path had been pruned and was recreated). Every claim below was re-derived from scratch — no author transcript was accepted.

CI is green at 43379335 (`build-and-test`, `goldens-affected`, `perf-tier1-smoke` all `completed/success`); qc-structural re-ran the scoped `dune build @devtools/checks/runtest --force`. I independently ran the committed suite (exit 0, "all 9 scenarios passed"), the check against the real tree (exit 0, 27 subdirs), and `posix_sh_check.sh` (exit 0, `grep -c '^FAIL:'` = 0, 79 scripts clean).

### Prior-finding closure

| # | verdict | my own evidence |
|---|---|---|
| **B1** *(was blocking)* | **CLOSED** | Rebuilt my `smuggled/` fixture from scratch and ran it against both scripts extracted from git. Old (775aa1bc): `OK … 2 on-disk subdirectories`, **exit 0** — defect reproduced. New (43379335): `FAIL … trading/trading/backtest/smuggled/`, **exit 1**. |
| **B2** *(was blocking)* | **CLOSED** | Scenario 8 pins it and is non-vacuous — see mutation M2 below. |
| B3 | **PARTIAL** | Test-file header corrected and now accurate. **The identical false claim survives in the check script's own header** (lines 67-69) — see finding N1. |
| B4 | **CLOSED** | Header line added. Verified against #2461's record in `cleanup.md` (7 discrepancies, all missing rows) and independently on the live tree: `comm -13` on-disk vs appendix rows returns **empty** — zero ghost rows, so the one-directional scope is accurate today. |
| B5 | **CLOSED** | Definitive before/after — see mutation M3 below. |
| B6 | **CLOSED (behaviour) / unpinned (test)** | Semantically safe; no fixture pins it — see finding N2. |

### Mutation results — are scenarios 7/8/9 non-vacuous?

All three can fail. Each mutation was applied to an isolated copy of the check (baseline copy verified green first).

- **M1 — delete the section boundary** (`found && /^## / { exit }`, i.e. revert B1 to heading-to-EOF): suite **RED**, `[section-scoped] expected exit 1, got 0`, and *only* that scenario. **Scenario 7 pins exactly what it claims.**
- **M2 — credit pre-appendix rows** (drop the `found` gate on `print`, keeping the boundary, mimicking check_02's loose whole-doc match): suite **RED**, `[outside-appendix] expected exit 1, got 0`, and *only* that scenario. Deliberately isolated so scenario 7 stays satisfied. **Scenario 8 pins the headline differentiating claim that B2 said was unpinned.**
- **M3 — my prior mutation re-run** (exclusion exact `=` → substring `case`): against the **old** 6-scenario test file from 775aa1bc → **GREEN, exit 0** (reproducing the B5 gap verbatim); against the **new** 9-scenario file → **RED**, `[exclusion-not-broad] expected exit 1, got 0`. **Clean before/after; B5 is definitively closed.**

### B1 edge-case probes (did the fix hold, and did it overcorrect?)

- **Appendix as last section (no following `## `)** — synthetic fixture with both rows genuinely in the appendix → **exit 0**, both captured. Cross-checked on the real plan file: the appendix at line 158 *is* the last `## ` section (file is 208 lines), and my independent `sed -n '158,208p'` extraction parses **27 rows**, matching the 27 on-disk subdirs with **empty `comm` in both directions**. **No overcorrection — no rows dropped, no false FAIL.**
- **Appendix heading with trailing whitespace** → **exit 1** via guard 2. `grep -qF` (substring) still finds the heading but `awk`'s `$0 == heading` does not, so it **fails loud rather than passing silently**. Correct direction. (Minor: the diagnostic blames "table format" when the real cause is the heading line — cosmetic only.)
- **Nested `### Appendix B` smuggling a row** → **exit 0**, row credited. `^## ` does not match `### `. This is *not* a contract violation: both the script header and the inline comment scope the claim literally to a "`## `" section, and an h3 following the appendix is semantically a subsection *of* it. Recorded as residual, not a finding.
- **`##Appendix B` (no space)** → row credited. Also not a defect: CommonMark requires the space, so that line is paragraph text, not a heading.

### B6 semantic verdict — safe, but unpinned

`[A-Za-z0-9_]` → `[A-Za-z0-9_.-]`. **No new defect.** Probed directly:

- Hyphenated + dotted dirs (`walk-forward/`, `v1.2/`) that **do** have correct rows: old script → **false FAIL** (guard 2, zero rows parsed) — confirming the B6 defect was real; new script → **OK**. The fix is genuine.
- Adversarial rows (`` `../` ``, `` `.hidden/` ``, `` `-/` ``) are **inert**: the on-disk listing comes from a `*/` glob, which never yields `.`, `..`, or dotfiles, so no widened row name can ever equal a real on-disk basename. With those three rows present and a real undocumented `alpha/`, the check still correctly **FAILs naming `alpha/`**. A widened row can only *add* an entry that matches nothing; it cannot manufacture a false pass.
- Nested paths (`` `a/b/` ``) still do not parse — the class excludes `/`. Conservative direction.

**But it is unpinned.** Mutation **M4** (revert the class to `[A-Za-z0-9_]`) leaves the suite **fully GREEN**. No fixture in the file uses a hyphenated or dotted subdir name.

### Contract accuracy — the axis scored 2 last time

I re-read and tested every claim in the script header, the `awk` inline comment, the test-file header, `dev/status/harness.md` and `dev/status/cleanup.md`.

**No fresh overclaim was introduced by the rework.** Specifically verified accurate: the three-part "prose / pre-appendix table / later `## ` section" claim (all three pinned, M1+M2); the one-directionality claim (matches #2461 and today's tree); the inline `awk` comment's "stops at the NEXT `## ` heading (or EOF, if the appendix is the last section, which is true today)" — literally correct on both counts; and both status-file entries, which correctly attribute scenario 9 to the *exclusion* fix and pointedly do **not** claim the regex widening is tested.

Two non-blocking accuracy defects remain (N1 pre-existing, N2 introduced):

**N1 — the script header still carries the B3 overclaim.** `backtest_appendix_drift_check.sh` lines 67-69 say the guards are proven "by deleting it and re-running against fixtures that would otherwise report a false OK." I falsified this for two of three: deleting **guard 1** → still `FAIL`, **exit 1** (guard 2 catches it); deleting **guard 2** → still `FAIL`, **exit 1** (the diff backstop catches it). Only guard 3 produces a false OK. The rework corrected this exact sentence in the *test-file* header — accurately and at length — but left the sibling copy in the script header untouched. Not blocking: it is a claim about test methodology rather than check behaviour, the correct nuance is documented in two other places (test-file header, PR body table), and it was equally present at 775aa1bc where I did not flag it. I am not escalating on iteration 1 a nit I let stand on iteration 0.

**N2 — stale "6 scenarios" in two places.** `trading/devtools/checks/dune` line 786 and the PR body's "What landed" section both still say 6. Understatement in the safe direction — all six named scenarios exist, so CP2 does not fail — but both should read 9. The status files were correctly updated.

### Book faithfulness

**No faithfulness question arose.** This PR contains zero domain logic — it is a shell linter over a Markdown table and a fixture-driven self-test. Nothing touches stage classification, entry/exit rules, stops, screening, or any Weinstein parameter, so no tier-1/tier-2 consultation was required. (The book is in any case unreachable here — macOS-local path, issue #2457.) No `BOOK-CHECK-NEEDED` items.

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Non-trivial header/docstring claims pinned by a test | PASS | No `.mli`; the script header is the contract analogue. Every claim about **what the check accepts or rejects** is now pinned and mutation-proven: exclusion semantics → sc. 1/2/6 + sc. 9 (M3); "table row under the appendix, not prose / not a pre-appendix table / not a later `## ` section" → sc. 7 (M1) + sc. 8 (M2); three vacuous-pass guards → sc. 3/4/5. Two documentation defects logged as N1/N2 rather than failed: N1 is a meta-claim about test methodology (pre-existing, contradicted correctly elsewhere in the same PR), N2 is a stale count. The regex-widening claim (B6) is **true but unpinned** — see CP4 note. |
| CP2 | PR-body "Test plan" claims exist in the committed test file | PASS | The body advertises 6 scenarios by name (clean, missing-row, no-heading, no-rows, empty-backtest-dir, exclusions) — **all six exist**. CP2 fails only when a body advertises a test that does not exist; here the body *understates* (9 landed). Logged as N2. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size | PASS | Every FAIL-expecting scenario asserts the **exact subdirectory name** in the output (`_assert_contains "trading/trading/backtest/<name>/"`), not a count. Scenarios 2/7/8 additionally assert the *negative* — that `alpha/`, which has a real row, is **not** reported. Scenario 9 asserts all three names individually. No count-only assertions. |
| CP4 | Each guard named in docstrings has a test exercising the guarded-against scenario | PASS | Guard 1 → sc. 3 (`appendix heading not found`); guard 2 → sc. 4 (`parsed ZERO table rows`); guard 3 → sc. 5 (`found ZERO subdirectories`). All three verified firing, each asserting its specific diagnostic. Guard 3 independently confirmed as the only one whose deletion yields a false OK. Note: the B6 regex widening is a behaviour change with **no fixture** — M4 reverts it with the suite fully green; recommended follow-up, not a guard gap. |

## Behavioral Checklist (Weinstein domain)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1, S1–S6, L1–L4, C1–C3, T1–T4 | — | **NA** | Pure harness PR — a POSIX shell linter over a Markdown appendix table plus its fixture self-test. Zero domain logic; qc-structural raised no A1 flag. Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely", the entire domain block is not applicable. |

## Quality Score

4 — Good. Both blocking findings are closed with fixes I reproduced from scratch, and all three new scenarios are proven non-vacuous by isolated mutation — the rework did the real work rather than adding tests that cannot fail. Held back from 5 by two documentation nits: the B3 overclaim surviving in the script header (N1) and an unpinned regex widening (N2/B6).

## Verdict

APPROVED

Non-blocking follow-ups for the next harness PR (neither affects check behaviour; both are one-liners):

1. **N1** — correct or delete `backtest_appendix_drift_check.sh` lines 67-69 to match the test-file header's now-accurate account (only guard 3's deletion yields a false OK).
2. **N2/B6** — update the "6 scenarios" comment in `trading/devtools/checks/dune` line 786 to 9, and add a fixture with a hyphenated subdir (`walk-forward/`) that **has** a correct row, so the widened character class is pinned. Today M4 reverts it silently green.
