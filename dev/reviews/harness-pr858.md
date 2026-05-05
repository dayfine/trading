Reviewed SHA: 5542c9e6a895bef5190f815d7aa23258a217c6a4

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | No formatting violations |
| H2 | dune build | PASS | Build successful |
| H3 | dune runtest | FAIL | Pre-existing failures on main; exit code 1 identical before/after this PR. Advisory linter failures (fn_length, nesting, magic_numbers) are in unrelated modules (entry_audit_capture.ml, exit_audit_capture.ml, etc.) not touched by this PR. No new test failures introduced. |
| P1 | Functions ≤ 50 lines (linter) | NA | Pure harness/utility scripts (shell); no OCaml source added. |
| P2 | No magic numbers (linter) | NA | Pure harness/utility scripts; no numeric literals subject to config routing. |
| P3 | Config completeness | NA | No configurable thresholds added; shell scripts only. |
| P4 | Public-symbol export hygiene (linter) | NA | No OCaml .mli files added. |
| P5 | Internal helpers prefixed per convention | NA | Shell scripts follow POSIX conventions; no OCaml helpers. |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | NA | New test files (`agent_compliance_test.sh`, `jj_workspace_smoke.sh`) are POSIX shell scripts, not OCaml test code. No Matchers library usage or `assert_that` patterns apply. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | NA | No core modules touched. Changes are isolated to `trading/devtools/checks/` (harness) and `dev/status/harness.md`. |
| A2 | No new `analysis/` imports into `trading/trading/` | NA | No imports added; harness-only change. |
| A3 | No unnecessary modifications to existing modules | PASS | Only 5 files changed: two new shell scripts (`agent_compliance_test.sh`, `jj_workspace_smoke.sh`), one extended shell script (`agent_compliance_check.sh`), one dune file extended with two new rules, and one status file updated. All changes are scoped to harness tasks. |

## Verdict

APPROVED

This is a pure harness/utility PR adding enforcement and smoke tests for the Pre-Work Setup boilerplate introduced in PR #839. All structural gates (H1: format, H2: build) pass. H3 (runtest) fails, but the failures are pre-existing on `main` — identical linter failures, identical exit code, none caused by this PR's changes.

The two new shell scripts (agent_compliance_test.sh, jj_workspace_smoke.sh) are well-written with:
- Clear comments explaining purpose and skip conditions
- POSIX sh compatibility (no bash-isms)
- Proper cleanup traps and error handling
- Deterministic pass/fail criteria

The extension to agent_compliance_check.sh adds Rule 2 (checking for ## Pre-Work Setup section) with proper scope: feat-*.md (excluding template), harness-maintainer.md, and ops-data.md; explicitly exempting read-only QC agents (qc-structural, qc-behavioral, health-scanner, track-pacer, lead-orchestrator, code-health).

The dune file correctly wires both new tests into `dune runtest`, and the status file update documents closure of the two follow-up items from PR #839.

---

# Behavioral QC — harness-pr858
Date: 2026-05-05
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new module docstrings has an identified test that pins it | PASS | No new `.mli` files. Script header docstrings make the following claims, each pinned: (a) `agent_compliance_check.sh` Rule 2 — "every jj-writing agent ... must contain ## Pre-Work Setup" → pinned by `agent_compliance_test.sh` Assertion 2 (REPO_ROOT-overridden run on stripped tree exits non-zero). (b) `agent_compliance_check.sh` skip exemptions for read-only QC agents → pinned by Assertion 1 (as-checked-in tree passes; verified by enumerating all 12 agent files: 6 in SKIP list lack `## Pre-Work Setup`, 5 jj-writing agents have it, template excluded). (c) `jj_workspace_smoke.sh` "execs the canonical boilerplate" → pinned by lines 49 + 56–62: actually invokes `jj -R "$REPO" workspace add "$AGENT_WS" --name "$AGENT_ID" -r main@origin` (matches `feat-agent-template.md` §"Pre-Work Setup" byte-for-byte modulo `-R` flag) and asserts `jj workspace list` contains `$AGENT_ID`. |
| CP2 | Each claim in PR body / status file follow-up entries has a corresponding test in the committed test files | PASS | Status file follow-up entries (`dev/status/harness.md` lines 120, 122) make 4 verifiable claims, all pinned: (1) "extended with Rule 2 — requires ## Pre-Work Setup on all jj-writing agents" → `agent_compliance_check.sh` lines 68–112 (Rule 2 block). (2) "Smoke test ... 2 assertions: as-is tree passes; stripped feat-data.md FAILs" → `agent_compliance_test.sh` Assertions 1 (line 19–25) and 2 (lines 27–74). (3) "Both wired into `dune runtest`" → `trading/devtools/checks/dune` lines 83–97 (Rule 1+2 check) and 99–109 (smoke). (4) "jj_workspace_smoke.sh execs canonical boilerplate, asserts `jj workspace list` shows entry, then cleans up" → script lines 36–69 (AGENT_ID generation, `jj workspace add`, `jj workspace list \| grep`, `jj workspace forget` + `rm -rf`). All claims trace to specific lines in the committed code. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size | NA | No pass-through semantics in this PR — all assertions are explicit FAIL/PASS exit-code checks (Assertion 1: `sh "$CHECK" >/dev/null 2>&1` exit 0; Assertion 2: same invocation exits non-zero on stripped tree). The smoke test asserts identity of the `$AGENT_ID` string in workspace list output via `grep -qF`. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | Three guards documented + tested: (a) `agent_compliance_check.sh` lines 49–56 — "if the glob matched zero feat-*.md files, fail loud rather than pass vacuously" — covered by Assertion 1 (real tree has 4+ feat-*.md files; vacuous-pass would still pass Assertion 1, but Assertion 2's stripped-tree path also has feat-*.md present so it would catch a regression to the silent-zero-glob bug if the strip logic ever broke). (b) `jj_workspace_smoke.sh` lines 23–26 — "skip cleanly when jj is not on PATH" — exercised every CI run on GHA (no jj installed); skip path prints `OK: ... SKIPPED (jj not on PATH).` and exits 0. (c) `jj_workspace_smoke.sh` lines 30–34 — "skip if not a jj repo" — same skip-path semantics. Edge case not directly tested but acceptable for smoke: `jj workspace add` failure due to name collision — mitigated by `AGENT_ID="smoke-$$-$(date +%s)"` (PID + epoch second); collision requires same PID + same second on same host, vanishingly improbable. Failure printf at line 50 is purely defensive (untested error-path). |

## Behavioral Checklist

Pure harness PR; domain checklist (S*/L*/C*/T* rows) not applicable per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely". A1 (core module mod generalizability) NA — qc-structural did not flag A1; no core modules touched.

## Quality Score

5 — Exemplary harness PR. Both follow-up gaps from PR #839 closed with deterministic tests; smoke test mirrors the canonical boilerplate byte-for-byte; SKIP list precisely matches the set of read-only agents (verified by enumerating all 12 agent files); proper trap-based cleanup in both scripts; gracefully degrades on GHA (no jj on PATH).

## Verdict

APPROVED
