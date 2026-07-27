Reviewed SHA: fd41ed6a

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
