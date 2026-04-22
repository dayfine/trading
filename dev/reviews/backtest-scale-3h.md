Reviewed SHA: 5f485dd069a54ae74919686dc0c0d8eb800252d7

## Structural Checklist — backtest-scale 3h (nightly A/B compare, PR #496)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | |
| H2 | dune build | PASS | |
| H3 | dune runtest | PASS | Full test suite green; no new unit tests in this increment (3h is CI/scripting) |
| P1 | Functions ≤ 50 lines (linter) | PASS | Shell script longest function `_run_backtest` is 27 lines; all helpers ≤ 9 lines |
| P2 | No magic numbers (linter) | PASS | 0.00001 (0.001% tolerance) and 1.0 (floor) are documented in function headers and plan §Resolutions #1; not arbitrary |
| P3 | Config completeness | NA | No new configurable thresholds introduced — parity tolerance is pinned in the plan and documented in code |
| P4 | .mli coverage (linter) | NA | No OCaml .ml/.mli files added (shell script + GHA workflow only) |
| P5 | Internal helpers prefixed with _ | PASS | All shell helpers (`_die`, `_usage`, `_scenario_name`, `_scenario_start`, `_scenario_end`, `_run_backtest`, `_trade_count`, `_final_portfolio_value`, `_abs_delta`, `_pv_warn_threshold`, `_gt`) correctly prefixed |
| P6 | Tests conform to matchers library | NA | No new OCaml test files |
| A1 | Core module modifications | PASS | Portfolio/Orders/Position/Strategy/Engine untouched; no changes to trading/trading/weinstein/ or bar_loader logic |
| A2 | No imports from analysis/ into trading/ | PASS | No analysis imports in the diff |
| A3 | No unnecessary existing module modifications | PASS | Only `trading/devtools/checks/posix_sh_check.sh` extended: added `dev/scripts` to `SCAN_DIRS` (+7/-2 lines), purely scope expansion for the linter itself |

## Verdict

APPROVED

## Scope & Design Verification

1. **Parity contract (plan §Resolutions #1):** Correctly encoded in `tiered_loader_ab_compare.sh`:
   - Hard gate: trade-count diff == 0 → exit 1 (lines 274–281)
   - Warn gate: |legacy_pv − tiered_pv| ≤ max($1.00, 0.001% of legacy_pv) → ::warning:: + exit 0 (lines 283–303)
   - Threshold formula correct: `awk -v pv="$1" 'BEGIN { t = pv * 0.00001; if (t < 1.0) t = 1.0; printf "%.4f\n", t }'` (lines 190–196)

2. **Broad scenarios (plan §Resolutions #2):** Workflow exercises the three goldens:
   - `bull-crash-2015-2020.sexp` (lines 79–88)
   - `covid-recovery-2020-2024.sexp` (lines 90–99)
   - `six-year-2018-2023.sexp` (lines 101–110)

3. **Staging path documented:** `dev/ci-staging/tiered-loader-ab.yml` is clearly marked as pending `git mv` to `.github/workflows/` at merge time:
   - Documented in status file (lines 35–46)
   - Referenced in script header (lines 10–12)
   - GHA workflow includes design note (lines 16–20)
   - Next steps pinpoint the handoff (lines 113–116)

4. **POSIX-sh discipline:** 
   - Script passes `dash -n` parse-only check ✓
   - Linter extended to scan `dev/scripts/` (posix_sh_check.sh SCAN_DIRS, lines 54–57)
   - Linter now reports 42 scripts clean (up from 41) ✓
   - Script uses `set -eu` for error discipline (line 47)
   - All functions in scope (shell helpers, grep/sed/awk utilities)

5. **Error handling & cleanup:**
   - Backtest failures captured in log files before rc check (lines 135–137); logs preserved for investigation
   - Hard parity violations (trades.csv missing or count diff) trigger GHA `::error::` annotations and exit 1 (lines 265–281)
   - Warn-only violations (PV drift above threshold, missing PV fields) trigger `::warning::` and exit 0 (lines 283–303)
   - GHA workflow uses `continue-on-error: true` on individual scenario steps so all three run even if one fails (lines 82, 93, 104)
   - Aggregate step re-surfaces any failure as job-level exit status (lines 126–147)
   - Output trees copied to stable `<out>/legacy/` and `<out>/tiered/` for artefact upload (lines 240–244)

6. **Scope boundary:** 
   - Files touched: `dev/scripts/tiered_loader_ab_compare.sh` (new), `dev/ci-staging/tiered-loader-ab.yml` (new), `trading/devtools/checks/posix_sh_check.sh` (scope extension), `dev/status/backtest-scale.md` (status log)
   - No OCaml code modified; no strategy/screener/loader refactors
   - No changes to Bar_loader tier logic or the Tiered_runner/Tiered_strategy_wrapper implementations

7. **Feature completeness:**
   - Smoke verification (status file lines 207–212): both strategies produce 3 trades / identical $1,096,397.65 final PV (delta $0.00 within warn threshold $10.96) on tiered-loader-parity.sexp ✓
   - Script documentation comprehensive (usage, parity contract, scenarios, exit status — lines 1–45)
   - GHA workflow permissioning correct: no `workflow` scope required; runs under standard `GITHUB_TOKEN` (lines 45–46)

---

# Behavioral QC — backtest-scale 3h (nightly A/B compare, PR #496)
Date: 2026-04-22
Reviewer: qc-behavioral

## Behavioral Checklist — backtest-scale 3h (nightly A/B compare, PR #496)

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | NA | No new .mli files added — PR is shell script + GHA workflow + status log + linter scope extension. Script-header documentation is advisory, not an API contract |
| CP2 | Each claim in PR body / commit messages vs committed artefacts | PASS | Commit `0f7b7add` (feat commit) claims: (a) hard gate on trade-count, (b) warn gate at max($1.00, 0.001% of legacy_pv), (c) missing trades.csv = hard fail, (d) uses backtest_runner.exe not scenario_runner, (e) extracts start_date/end_date via grep+sed, (f) output dir pinned via "Output written to: ..." stderr line, (g) no jq dependency, (h) posix_sh_check.sh extended to scan dev/scripts/. All 8 claims verified in the script (lines 123–151 for (d)/(e)/(f); 265–281 for (a)/(c); 283–303 for (b); no `jq` tokens anywhere; posix_sh_check.sh lines 54–57 for (h)). Commit `14bc61f5` (staged workflow) claims workflow lives at `dev/ci-staging/tiered-loader-ab.yml` with deferred `git mv` to `.github/workflows/` — verified (file exists at staged path, commented in workflow header lines 16–20 and status file lines 35–46) |
| CP3 | Pass-through / identity / invariant tests pin identity (not just size) | NA | No OCaml-level pass-through tests. Smoke parity output identified in status file lines 207–212 pins exact PV ($1,096,397.65 both sides, delta $0.00) and exact trade count (3 both sides); this exceeds a size-only check |
| CP4 | Each guard called out explicitly in docstrings has a test that exercises it | NA | Script-level guards (hard vs. warn gates, MISSING branches) are not unit-tested — 3h is explicitly a CI/visibility surface, not a test suite. The status file §Completed verification section describes a smoke run that exercises the happy path; failure-path coverage is by design deferred to the first nightly run. Plan §3h says "not a test (too slow), not a merge gate — just visibility" |

### Weinstein Domain Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural did not flag A1; no core module modifications in this diff |
| S1 | Stage 1 definition matches book | NA | No stage classification code in 3h |
| S2 | Stage 2 definition matches book | NA | No stage classification code in 3h |
| S3 | Stage 3 definition matches book | NA | No stage classification code in 3h |
| S4 | Stage 4 definition matches book | NA | No stage classification code in 3h |
| S5 | Buy criteria: Stage 2 entry on breakout with volume | NA | No entry logic in 3h |
| S6 | No buy signals in Stage 1/3/4 | NA | No entry logic in 3h |
| L1 | Initial stop below base | NA | No stops in 3h |
| L2 | Trailing stop never lowered | NA | No stops in 3h |
| L3 | Stop triggers on weekly close | NA | No stops in 3h |
| L4 | Stop state machine transitions | NA | No stops in 3h |
| C1 | Screener cascade order | NA | No screener code in 3h |
| C2 | Bearish macro blocks all buys | NA | No screener code in 3h |
| C3 | Sector RS vs. market, not absolute | NA | No screener code in 3h |
| T1 | Tests cover all 4 stage transitions | NA | No OCaml domain tests in 3h |
| T2 | Bearish macro → zero buy candidates test | NA | No OCaml domain tests in 3h |
| T3 | Stop trailing tests | NA | No OCaml domain tests in 3h |
| T4 | Tests assert domain outcomes | NA | No OCaml domain tests in 3h |

### Plan §Resolutions Conformance (primary authority for 3h)

The relevant authority for this CI/scripting PR is `dev/plans/backtest-tiered-loader-2026-04-19.md`. The two contracts that matter:

**§Resolutions #1 — Parity threshold:**
> Zero trade-count diff is the hard gate. Any missing or extra trade fails parity.
> Portfolio-value diff tolerance: max($1.00, 0.001% of final portfolio_value).

Verification (script `dev/scripts/tiered_loader_ab_compare.sh`):
- Hard gate (trade-count diff): lines 274–281. `if [ "$LEGACY_TRADES" != "$TIERED_TRADES" ]; then exit 1`. Emits `::error::` annotation. ✓ PASS
- Hard gate (missing trades.csv): lines 265–272. Either side MISSING → exit 1 with `::error::`. ✓ PASS (stronger than the plan literally says; plan only mentions "missing or extra trade" — script treats a missing `trades.csv` file as a malformed run, a stronger invariant, which the feat commit message calls out explicitly. Consistent with the plan's intent.)
- Warn gate (PV drift): lines 283–303. Threshold formula at lines 190–196: `t = pv * 0.00001; if (t < 1.0) t = 1.0` — equivalent to `max(1.0, 0.00001 * pv)`. 0.00001 is precisely 0.001% (`0.001/100 = 1e-5`). ✓ PASS — formula exact-matches the plan text.
- Warn gate exits 0 (`::warning::` annotation): lines 296–303, and the "Warn gate (exit 0, ::warning::)" flow in status file lines 186–189. ✓ PASS
- Warn gate when PV MISSING: lines 283–289 emit `::warning::` and `exit 0`. This is slightly softer than the hard gate — reasonable: summary.sexp can be present-without-final_portfolio_value if the simulator aborts mid-run, and that's a separate signal from trade-count divergence. Arguably this could be a hard fail (the spec is silent on this edge), but I don't think it violates the plan.

**§Resolutions #2 — Broad A/B scenarios:**
> Start with 2-3 scenarios covering different regimes (one bull, one bear, one choppy). Nominal picks: six-year (2018-2023 mixed), bull-crash (2015-2020, bullish → crash), covid-recovery (2020-2024, whipsaw).

Verification (`dev/ci-staging/tiered-loader-ab.yml`):
- 3 scenario steps (lines 79–110), each running one of:
  - `goldens-broad/bull-crash-2015-2020.sexp` (bullish → crash regime) ✓
  - `goldens-broad/covid-recovery-2020-2024.sexp` (whipsaw regime) ✓
  - `goldens-broad/six-year-2018-2023.sexp` (mixed regime) ✓
- All 3 scenarios verified present at `trading/test_data/backtest_scenarios/goldens-broad/`. ✓ PASS — matches the plan's nominal-pick list verbatim.

**Rationale for the parity-contract implementation choices:**

- The script parses the scenario sexp with grep+sed rather than a proper parser. This is documented in the feat commit and the script header. The scope is restricted to `(name ...)` and `(period (start_date ...) (end_date ...))`. For the three broad goldens this works — all three have the expected shape. Accepted: the plan's "line budget: ~100 lines" implicitly forbids a proper parser, and sexp parsing in pure shell would balloon the script.
- The script ignores `universe_path` and `config_overrides`, relying on backtest_runner's default universe/sector-map behaviour. Documented in script header lines 14–18. Accepted: all three goldens ship without explicit universe/config overrides, so this is a safe restriction for the initial scope.
- The GHA workflow uses `continue-on-error: true` on individual scenario steps + an aggregate step that re-surfaces any failure (lines 82/93/104 + 126–146). This ensures all 3 scenarios run on every nightly, so a regression in scenario 1 doesn't mask a separate regression in scenarios 2/3. ✓ Good design beyond what the plan strictly requires.

## Quality Score

5 — Faithful, economical implementation of plan §3h with all contract surfaces (hard gate, warn gate, threshold formula, 3 nominal scenarios, nightly cadence, artefact layout) exactly matching §Resolutions #1 & #2. POSIX-sh discipline maintained; linter scope extension is a principled side-effect that keeps the new script under the existing portability gate. Staging path (`dev/ci-staging/` → `.github/workflows/` via `git mv`) is well-documented in three independent locations (script header, workflow header, status file). No hardcoded thresholds — `0.00001` is the plan's `0.001%` constant verbatim, documented in the function header. Smoke verification on the parity scenario reports exact-match output.

(Does not affect verdict. Tracked for quality trends over time.)

## Verdict

APPROVED

(Derived mechanically: all applicable CP* items PASS, all S*/L*/C*/T* rows NA for this CI/scripting PR, and both plan-level contracts (§Resolutions #1 parity formula; §Resolutions #2 scenario picks) match verbatim.)
