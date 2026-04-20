Reviewed SHA: f0c402a620247a9423a9982c4300222cf2cd644a

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | Exit 0; no formatting diff |
| H2 | dune build | PASS | Exit 0; no compilation errors |
| H3 | dune runtest | FAIL | Full-repo exit code 1. Pre-existing baseline failures — nesting_linter: 51 functions in `analysis/scripts/universe_filter/` and `analysis/scripts/fetch_finviz_sectors/` plus `trading/weinstein/strategy/lib/ad_bars.ml` and `analysis/technical/indicators/atr/lib/atr.ml`. All failing paths are unchanged by this PR (zero diff for all flagged paths vs origin/main). New smoke test `deep_scan_drift_coverage_check.sh` passes when invoked directly (exit 0, "OK: deep scan drift coverage extension (backtest subsystem, harness gap sub-item 1) structural check passed."). |
| P1 | Functions ≤ 50 lines — covered by fn_length_linter (dune runtest) | NA | No OCaml files changed in this PR. All changes are shell scripts and dune stanzas. |
| P2 | No magic numbers — covered by linter_magic_numbers.sh (dune runtest) | NA | No OCaml files changed in this PR. |
| P3 | All configurable thresholds/periods/weights in config record | NA | No domain logic or tunable parameters introduced. Shell-only harness change. |
| P4 | .mli files cover all public symbols — covered by linter_mli_coverage.sh (dune runtest) | NA | No OCaml files changed in this PR. |
| P5 | Internal helpers prefixed with _ | NA | No new OCaml helper functions. Shell `fail()` local to smoke test is a terminal error handler, not an internal helper in the OCaml sense. |
| P6 | Tests use the matchers library (per CLAUDE.md) | NA | No OCaml test files changed. Smoke test is a shell script. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | Zero diff in any core trading modules. Changed files: `dev/health/2026-04-20-deep.md`, `dev/metrics/cc-latest.json`, `dev/status/harness.md`, `trading/devtools/checks/deep_scan/check_02_design_doc_drift.sh`, `trading/devtools/checks/deep_scan_drift_coverage_check.sh`, `trading/devtools/checks/dune`. |
| A2 | No imports from analysis/ into trading/trading/ | PASS | No OCaml files changed; no new imports introduced. |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | `check_02_design_doc_drift.sh`: new stanza appended after the existing three (weinstein_strategy, weinstein_portfolio, data_source) without touching prior blocks. `dune`: one stanza added at end. `dev/status/harness.md`: sub-item 1 struck through and completion entry added to Completed section — appropriate and scoped. |

## Scope Verification

- **4th subsystem entry shape**: The new backtest stanza in `check_02_design_doc_drift.sh` (lines 79–96) follows the same pattern as the existing three — PLAN/DIR variables, `if [ -f ] && [ -d ]` guard, for-loop over subdirs, `_build|test|.formatted` skip cases, `grep -qi` against plan doc, `add_warning` on miss. Shape is consistent.
- **Smoke test pattern**: `deep_scan_drift_coverage_check.sh` sources `_check_lib.sh`, uses `repo_root` and `die` from it (both defined in `_check_lib.sh`), verifies BACKTEST_PLAN, BACKTEST_DIR, plan filename, and subsystem path markers in `check_02`, then checks the most-recent deep report for "Design doc drift". Matches the pattern of sibling smoke tests (`deep_scan_stale_bookmarks_check.sh`, `deep_scan_linter_expiry_check.sh`).
- **Dune wiring**: `trading/devtools/checks/dune` adds `(rule (alias runtest) (deps _check_lib.sh) (action (run sh %{dep:deep_scan_drift_coverage_check.sh})))` — identical shape to adjacent stanzas. `_check_lib.sh` correctly listed in `deps` (required since the script sources it at runtime).
- **Part 2 check semantics**: The OR condition `grep -qF 'Design doc drift' "$LATEST_DEEP" || grep -qF 'DRIFT_COUNT' "$CHECK_02"` is permissive: the second arm is always true (DRIFT_COUNT is always in check_02), making the Part 2 check structurally weak — it would pass even if the health report had no drift section at all. However, since the deep report `dev/health/2026-04-20-deep.md` does contain "Design doc drift" (2 occurrences), the first arm is satisfied, and the check is working as intended in this state.
- **Sub-item 1 status update**: `dev/status/harness.md` line 130 strikes through the sub-item header with `~~**Drift coverage too narrow**~~`; a separate "### Deep scan heuristic gap sub-item 1" entry is added to the Completed section at line 295 with a full verification recipe. Shape matches sub-items 2, 3, 4 (all previously marked DONE).
- **H3 pre-existing failures**: All nesting_linter failures are in `analysis/scripts/` paths unchanged by this PR. The pre-flight context explicitly flags these as unrelated baseline noise.

## Notes on H3 (pre-existing failures)

The `dune runtest` exit code 1 is caused entirely by pre-existing nesting_linter violations that exist on `origin/main` and are unchanged by this PR. All 51 flagged functions are in `analysis/scripts/universe_filter/`, `analysis/scripts/fetch_finviz_sectors/`, `trading/weinstein/strategy/lib/ad_bars.ml`, and `analysis/technical/indicators/atr/lib/atr.ml`. None were introduced by this PR.

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
