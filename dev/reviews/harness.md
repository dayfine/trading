Reviewed SHA: ff97df57b34904f109d8d4fa5aaf20207f446f3b

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | Exit 0; no formatting diff |
| H2 | dune build | PASS | Exit 0; all shell scripts and dune stanzas valid |
| H3 | dune runtest | FAIL | Full-repo exit code 1. Pre-existing baseline failures on `origin/main` (fn_length_linter: `runner.ml:193 run_backtest 56 lines`; nesting_linter: 49 functions in `analysis/scripts/`; file_length_linter: `weinstein_strategy.ml 320 lines`; magic_numbers: `weinstein_strategy.ml` and `trace.ml`). All failing files are unchanged by this PR (zero diff for all flagged paths vs origin/main). New smoke test `deep_scan_linter_expiry_check.sh` passes when invoked directly (exit 0, "OK: deep scan Linter Exception Expiry section (T1-K) structural check passed."). Scaffolding audit in deep scan report shows `PASS: deep_scan_linter_expiry_check.sh — referenced`. |
| P1 | Functions ≤ 50 lines — covered by fn_length_linter (dune runtest) | NA | No OCaml files changed in this PR. All changes are shell scripts and dune stanzas. |
| P2 | No magic numbers — covered by linter_magic_numbers.sh (dune runtest) | NA | No OCaml files changed in this PR. |
| P3 | All configurable thresholds/periods/weights in config record | NA | No domain logic or tunable parameters introduced. Shell-only harness change. |
| P4 | .mli files cover all public symbols — covered by linter_mli_coverage.sh (dune runtest) | NA | No OCaml files changed in this PR. |
| P5 | Internal helpers prefixed with _ | PASS | `_milestone_num()` shell function in `deep_scan.sh` correctly prefixed with underscore. No other new internal helpers. |
| P6 | Tests use the matchers library (per CLAUDE.md) | NA | No OCaml test files changed. Smoke test is a shell script, not an OCaml test. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | Zero diff in any of the core trading modules. |
| A2 | No imports from analysis/ into trading/trading/ | PASS | No OCaml files changed; no new imports introduced. |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | Changed files: `dev/health/2026-04-19-deep.md` (generated report — expected), `dev/metrics/cc-latest.json` (CC snapshot update — expected side effect of running deep_scan.sh), `dev/status/harness.md` (appropriate status update), `trading/devtools/checks/deep_scan.sh` (feature target), `trading/devtools/checks/deep_scan_linter_expiry_check.sh` (new smoke test), `trading/devtools/checks/dune` (wiring). No existing check blocks modified; Check 11 appended after Check 10. |

## Scope Verification

- **Check 11 implementation**: `deep_scan.sh` adds a well-delimited block after Check 10 with clear `# Check 11: Linter Exception Expiry` header. Block reads `linter_exceptions.conf`, processes each active entry, handles milestone (M1-M7) and date (YYYY-MM-DD) comparison modes, emits `[MANUAL REVIEW]` when current milestone cannot be parsed (fallback clearly labeled), and always emits `## Linter Exception Expiry` section in the report.
- **Deep scan end-to-end**: Ran successfully (exit 0). Report at `dev/health/2026-04-19-deep.md` contains `## Linter Exception Expiry` at line 155.
- **Milestone fallback**: `weinstein-trading-system-v2.md` has no `Current milestone:` marker; the script correctly falls back to "MANUAL REVIEW" with a clear parse warning in the report. This is documented intentional behaviour per scope context.
- **Smoke test**: `deep_scan_linter_expiry_check.sh` verifies (1) Check 11 structural markers in `deep_scan.sh` and (2) most-recent `dev/health/*-deep.md` contains `## Linter Exception Expiry`. Both assertions run. Exit 0 confirmed.
- **Dune wiring**: `trading/devtools/checks/dune` adds a new `(rule (alias runtest) ...)` stanza for `deep_scan_linter_expiry_check.sh` with `_check_lib.sh` as a dep, matching the pattern used for `deep_scan_recent_commits_check.sh` (Check 10).
- **Status file**: `dev/status/harness.md` sub-item 3 under "Deep scan heuristic gaps" is struck through (`~~**Linter exception expiry**...~~`) and a completion note is added under Completed section.
- **No scope creep**: Zero diff in any OCaml source, feature modules, or unrelated devtools scripts.

## Notes on H3 (pre-existing failures)

The `dune runtest` exit code 1 is caused entirely by pre-existing linter violations that exist on `origin/main` and are unchanged by this PR:

1. `fn_length_linter`: `trading/trading/backtest/lib/runner.ml:193 run_backtest` — 56 lines. File exists on `origin/main` (248 lines), zero diff in this PR.
2. `nesting_linter`: 49 functions in `analysis/scripts/universe_filter/` and `analysis/scripts/fetch_finviz_sectors/`. All pre-existing.
3. `file_length_linter`: `trading/trading/weinstein/strategy/lib/weinstein_strategy.ml` — 320 lines. Exists on `origin/main` (320 lines), zero diff in this PR.
4. `magic_numbers`: `weinstein_strategy.ml` (literal `11`) and `trace.ml` (literal `1024`). Both pre-existing on `origin/main`.

None of these were introduced by this PR. The new smoke test passes cleanly in isolation.

## Verdict

APPROVED

(H3 exit code 1 is pre-existing baseline noise unrelated to this PR. All checks applicable to this shell-only harness change are PASS or NA. No FAIL items attributable to this branch.)

---

# Behavioral QC — harness deep-scan Check 11 (linter exception expiry, T1-K)
Date: 2026-04-19
Reviewer: qc-behavioral

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural did not flag A1 (zero diff in core trading modules) |
| S1 | Stage 1 definition matches book | NA | Harness-only change; zero OCaml sources touched |
| S2 | Stage 2 definition matches book | NA | Harness-only change |
| S3 | Stage 3 definition matches book | NA | Harness-only change |
| S4 | Stage 4 definition matches book | NA | Harness-only change |
| S5 | Buy criteria: Stage 2 entry on breakout with volume | NA | Harness-only change |
| S6 | No buy signals in Stage 1/3/4 | NA | Harness-only change |
| L1 | Initial stop below base | NA | Harness-only change |
| L2 | Trailing stop never lowered | NA | Harness-only change |
| L3 | Stop triggers on weekly close | NA | Harness-only change |
| L4 | Stop state machine transitions | NA | Harness-only change |
| C1 | Screener cascade order | NA | Harness-only change |
| C2 | Bearish macro blocks all buys | NA | Harness-only change |
| C3 | Sector RS vs. market, not absolute | NA | Harness-only change |
| T1 | Tests cover all 4 stage transitions | NA | Harness-only change (shell smoke test, not domain tests) |
| T2 | Bearish macro → zero buy candidates test | NA | Harness-only change |
| T3 | Stop trailing tests | NA | Harness-only change |
| T4 | Tests assert domain outcomes | NA | Harness-only change |

### Ad-hoc policy-faithfulness checks (PF) for T1-K / Check 11

Weinstein domain axes are N/A — this is a harness/health-scanner policy change. The relevant behavioral dimensions are T1-K policy faithfulness, false-positive resistance, severity calibration, and report completeness.

| # | Check | Status | Notes |
|---|-------|--------|-------|
| PF1 | Milestone tokens (M1–M7) extracted robustly, including from descriptive phrases | PASS | `deep_scan.sh:1096` uses `grep -o 'M[1-7]' | head -1`. Live report at `dev/health/2026-04-19-deep.md:165` correctly extracted `M5` from `"after segmentation is validated in simulation (M5)"` |
| PF2 | Date (YYYY-MM-DD) comparison uses `date +%F` against today | PASS | `TODAY="$(date +%Y-%m-%d)"` at `deep_scan.sh:32` (equivalent to `%F`); string comparison `[ "$review_date" \< "$TODAY" ]` at line 1117 — lexical comparison is valid for ISO-8601 dates |
| PF3 | `never*` values exempt by design (permanent exceptions) | PASS | `case "$review_at_val" in never*) continue ;; esac` at line 1084–1086. Confirmed empirically: all 6 `never` entries in `linter_exceptions.conf` were skipped in live run (zero appeared in section output) |
| PF4 | Missing `review_at:` annotation flagged as separate "policy violation" sub-section | PASS | Dedicated `EXPIRY_MISSING_COUNT` accumulator (line 1076) and separate `### Missing review_at annotation — policy violation T1-K` sub-section (line 1274). Currently zero such entries — section only rendered when count > 0, which is correct. T1-K policy requires "every entry must carry a review_at annotation" — `linter_exceptions.conf` header and T1-K completion note confirm intent |
| PF5 | MANUAL REVIEW fallback for milestone-pinned entries when current milestone cannot be parsed | PASS | `weinstein-trading-system-v2.md` has no `Current milestone:` marker today; script correctly emits `Parse warning:` at line 1259 plus `[MANUAL REVIEW — milestone unknown]` prefix per-entry at line 1104. Verified live: `dev/health/2026-04-19-deep.md:160` contains the parse warning; line 165 contains `[MANUAL REVIEW — milestone unknown]` prefix |
| PF6 | MANUAL REVIEW visually distinguished from EXPIRED (hard finding) | PASS | Three distinct prefixes used: `[EXPIRED]`, `[MANUAL REVIEW — milestone unknown]`, `[UNRECOGNISED format]`. Live report shows all three types rendered as distinct items, each with a unique prefix, making triage unambiguous |
| PF7 | Milestone-unknown fallback is not fatal; scan continues for date-based and missing-annotation cases | PASS | The milestone-parse branch only sets `MILESTONE_PARSE_WARN` and `CURRENT_MILESTONE_NUM=0` (via `_milestone_num ""`). Date-comparison branch (line 1114) and missing-annotation branch (line 1074) are independent and execute unaffected. Live run showed date-branch entries absent (none expired today), and unrecognised-format branch caught the `"when price_path.ml is actively modified"` annotation |
| PF8 | Severity is WARNING (not CRITICAL) — does not gate CI | PASS | Only `add_warning` is called (lines 1105, 1110, 1120, 1128); never `add_critical`. Exit policy (lines 1140–1148): `ACTION="YES"` only when `CRITICAL_COUNT > 0`; script never calls `exit 1`. Live run: 5 warnings, exit code 0, `Action required: NO`. Appropriate — humans retire/extend exceptions, not machines |
| PF9 | `## Linter Exception Expiry` section always emitted, even when no findings | PASS | Section emission at line 1252 is outside any conditional. Renders even on clean runs (empty case handled at line 1266: `"No expired or missing review_at annotations found."`) |
| PF10 | Unrecognised format surfaces as finding (not silently swallowed) | PASS | Line 1124–1128: `[UNRECOGNISED format]` prefix + warning. Caught `"when price_path.ml is actively modified"` entry in live run — good defensive behaviour against arbitrary text in `review_at` field |
| PF11 | Comment/blank lines skipped correctly; section headers (`# ── magic_numbers ──`) not parsed as exceptions | PASS | Line 1062–1066: `stripped` leading-space, then skip `''` or `'#'*`. All six `# ──` delimiter lines are correctly treated as comments |
| PF12 | Status-file update: sub-item 3 struck through, Completed entry added | PASS | `dev/status/harness.md:140` has `~~**Linter exception expiry**~~`; Completed section at line 263–265 has `### Deep scan heuristic gap sub-item 3: Linter exception expiry` with full verification recipe |
| PF13 | End-to-end: deep scan runs to completion with Check 11 active and emits the expected section | PASS | Ran `sh trading/devtools/checks/deep_scan.sh` — exit 0. `dev/health/2026-04-19-deep.md:154` contains `## Linter Exception Expiry`; section contains parse warning, 2 findings (1 UNRECOGNISED, 1 MANUAL REVIEW), no false positives on the 6 `never` entries. Smoke test `deep_scan_linter_expiry_check.sh` passes (exit 0) |

## Quality Score

5 — Exemplary. Policy faithfully encodes T1-K intent (review_at retirement, never-exempt, missing-annotation = policy violation). Three-way triage labels (EXPIRED / MANUAL REVIEW / UNRECOGNISED) handle every realistic annotation shape, including the descriptive `"after ... (M5)"` form which the implementer explicitly designed for. Severity calibration is correct (WARNING, non-gating). Fallback behaviour when milestone cannot be parsed is graceful (parse warning + surface all milestone-pinned entries) rather than silent or fatal. Empirically verified end-to-end against the live conf file.

## Verdict

APPROVED

(All applicable checks PASS; all Weinstein domain axes N/A for this harness-only shell change.)

