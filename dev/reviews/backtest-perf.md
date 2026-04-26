Reviewed SHA: 6f689d62c7fd07bf00545a9a8df937542b63d47f

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | |
| H2 | dune build | PASS | |
| H3 | dune runtest | PASS | All tests passed; perf_catalog_check.sh passed as part of runtest |
| P1 | Functions ≤ 50 lines (linter) | NA | No new OCaml functions; only shell scripts and comment headers |
| P2 | No magic numbers (linter) | NA | No new code with magic numbers; shell scripts + sexp comments only |
| P3 | Config completeness | NA | No new tunable parameters added |
| P4 | .mli coverage (linter) | NA | No new .mli files |
| P5 | Internal helpers prefixed with _ | NA | Shell scripts use standard naming; no OCaml code |
| P6 | Tests conform to test-patterns.md | NA | No test files modified |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to core modules |
| A2 | No imports from analysis/ into trading/trading/ | PASS | Only shell scripts and sexp comment headers; no imports |
| A3 | No unnecessary modifications to existing modules | PASS | Only modified: dev/status/backtest-perf.md (status update), 15 sexp headers (tier tags), trading/devtools/checks/dune (perf_catalog_check.sh wiring), 2 new shell scripts (perf_tier1_smoke.sh, perf_catalog_check.sh) |

## Additional Structural Findings

| Check | Status | Notes |
|-------|--------|-------|
| POSIX shell compliance (dash -n) | PASS | Both new scripts pass `dash -n` syntax check |
| No Python files | PASS | 0 .py files in the diff; no violation of no-python.md rule |
| Tier assignment defensibility | PASS | 4×T1 (bull-3m, bull-6m, panel-golden-2019-full, tiered-loader-parity), 6×T2 (goldens-small 3× + smoke 3×), 2×T3 (perf-sweep 1y/3y), 3×T4 (goldens-broad SKIPPED); exact match to plan. Tier-rationale headers present on all 15 scenarios. |
| Perf catalog check coverage | PASS | Script correctly detects missing tier tags; perf_catalog_check.sh wired into `(alias runtest)` in dune with annotate-only default (PERF_CATALOG_CHECK_STRICT=0 for backward compat). All 15 scenarios tagged and verified by check during H3. |
| Tier-1 scenario discovery | PASS | perf_tier1_smoke.sh correctly auto-discovers all 4 tier-1 scenarios: `smoke/tiered-loader-parity.sexp`, `smoke/panel-golden-2019-full.sexp`, `perf-sweep/bull-3m.sexp`, `perf-sweep/bull-6m.sexp`. File verification: both smoke scenarios exist on disk with tier-1 headers. |
| Worktree contamination check | PASS | Clean ancestry (merge-base = main@origin = 1e921de); no stacking on sibling PRs (e.g., #575). File list exactly: 15 scenario sexps + 2 new shell scripts + dune wiring + status update. No `runner.ml`, `loader_strategy/`, `panel_runner.ml`, or other contamination. |
| GHA workflow file held out | FLAG | The `.github/workflows/perf-tier1.yml` workflow file is **held out of this PR** because the agent's PAT lacks `workflow` scope. The drafted YAML is documented in the PR body and branch history. The tier-1 smoke script and catalog check are complete and functional; workflow deployment requires maintainer follow-up using a workflow-scoped token. Catalog check no-ops gracefully if workflow is missing (checks any paths found in the file, exits 0 if file not found). |

## Verdict

APPROVED

## Notes

- The staged feature (Steps 1+2) is structurally complete and sound. Tier headers are consistent, shell scripts pass POSIX validation, dune integration is correct, and no contamination is present.
- The held-out workflow (FLAG item above) is a scope limitation on the agent's token, not a structural defect in this PR. Maintainer should commit the drafted workflow in a follow-up with proper permissions.
- Status file correctly updated to IN_PROGRESS with clear notes on the workflow hold-out and next steps (tiers 2, 3, 4).

---

# Behavioral QC — backtest-perf (Steps 1+2)
Date: 2026-04-26
Reviewer: qc-behavioral

## Note on applicability

This PR is infrastructure / tooling (scenario tier cataloging + a smoke-runner shell script + an integrity check). It contains **no Weinstein-domain logic** — no stage classifier, no screener, no stop-loss state machine, no analysis pipeline. The S*/L*/C* trading-domain rows of the standard checklist are all NA. T* rows are evaluated against the script-level contracts rather than trading-metric contracts.

Authority docs consulted:
- `dev/plans/perf-scenario-catalog-2026-04-25.md` (PR #550, MERGED) — the agreed design
- `dev/status/backtest-perf.md` (in-PR update) — the agent's status claims
- The two new scripts' header docstrings — the contracts the scripts make to callers
- The four representative scenario sexps (one per directory) — to verify tier assignment defensibility

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | NA | No new .mli files in this PR (shell scripts + sexp comment headers only). |
| CP2 | Each claim in PR body / commit messages "Test plan"/"Test coverage" has a corresponding test in the committed test file | PASS | Commit messages claim: (a) "Greps every scenario sexp for `;; perf-tier:` header" — verified by directly running `perf_catalog_check.sh`, see CP4. (b) "Cross-checks .sexp paths in workflow file" — verified by injecting a synthetic perf-tier1.yml with a non-tier-1 path + a missing path; check correctly emitted `WORKFLOW_PATH_NOT_TIER1` and `WORKFLOW_PATH_NOT_FOUND`. (c) "Annotate-only by default" — verified: default exit 0 with WARNING; `PERF_CATALOG_CHECK_STRICT=1` flips to exit 1 with FAIL. (d) "Auto-discovers `;; perf-tier: 1` scenarios" — verified: 4 tier-1 scenarios match what status file enumerates. (e) "POSIX sh; passes `dash -n`" — verified: `dash -n` exits 0 on both scripts. The verification path is the script behaviour itself; there is no separate OUnit test, which is appropriate for shell-script tooling and matches the pattern of sibling check scripts (`posix_sh_check_test.sh`, `consolidate_day_check.sh`). |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size_is | NA | No identity / pass-through semantics in this PR — the smoke runner produces metrics, it does not assert them. |
| CP4 | Each guard in code docstrings has a test that exercises the guarded scenario | PASS | The script's main guards are: (i) "fails if scenario lacks `;; perf-tier:` header" — exercised by removing the tag from `recovery-2023.sexp` and re-running; both annotate-only (WARNING + exit 0) and strict (FAIL + exit 1) paths fired correctly. (ii) "skips check if workflow file absent" — exercised by current PR state (perf-tier1.yml held out); check cleanly skips the cross-check block, exits 0 with no false-positive. (iii) "scopes only catalog dirs (skips experiments/, panel_goldens/, universes/)" — verified by inspection: those dirs exist on disk, do not appear in `CATALOG_DIRS`, and were not in the violations list. |

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic (only fill if qc-structural flagged A1) | NA | qc-structural reported A1 PASS — no core-module touches. |
| S1–S6 | Stage 1/2/3/4 definitions, buy criteria, no buys in non-Stage-2 | NA | No Weinstein-domain logic in this PR. |
| L1–L4 | Initial stop, trailing stop, weekly close, state machine | NA | No stop-loss logic in this PR. |
| C1–C3 | Screener cascade, macro gate, sector RS | NA | No screener / macro / sector logic in this PR. |
| T1 | Tests cover all 4 stage transitions | NA | No stage logic. Replaced with: tooling claims have a verification path — see CP2/CP4 above. |
| T2 | Bearish-macro → zero buy candidates test | NA | No macro logic. |
| T3 | Stop trailing tests | NA | No stop logic. |
| T4 | Tests assert domain outcomes, not "no error" | PASS | The catalog check asserts the SPECIFIC violation categories (MISSING_TAG, WORKFLOW_PATH_NOT_FOUND, WORKFLOW_PATH_NOT_TIER1) rather than a generic exit code, and the smoke runner reports per-cell pass/fail with wall-time + peak-RSS rather than a generic "ran without error". Both meet the spirit of T4. |

## Tier-assignment defensibility (PR-specific)

Verified by reading one scenario from each directory:

| Scenario | Tier | Universe | Period | Defensibility |
|----------|------|----------|--------|---------------|
| `smoke/tiered-loader-parity.sexp` | 1 | 7-symbol parity | 6 months | DEFENSIBLE — small + fast, well within ≤2 min |
| `smoke/panel-golden-2019-full.sexp` | 1 | 7-symbol parity | ~8 months | DEFENSIBLE — same scale as parity |
| `smoke/bull-2019h2.sexp` | 2 | 1654-symbol broad | 6 months | DEFENSIBLE — verified `(universe_size 1654)` in file; rationale matches plan |
| `smoke/crash-2020h1.sexp` | 2 | 1654-symbol broad | 6 months | DEFENSIBLE |
| `smoke/recovery-2023.sexp` | 2 | 1654-symbol broad | 12 months | DEFENSIBLE |
| `goldens-small/bull-crash-2015-2020.sexp` | 2 | 302-symbol small | 6 years | DEFENSIBLE — within 30-min nightly budget per existing goldens runtime data |
| `perf-sweep/bull-1y.sexp` | 3 | 1000-symbol broad | 1 year | DEFENSIBLE — matches existing perf-sweep harness scope |
| `perf-sweep/bull-3y.sexp` | 3 | 1000-symbol broad | 3 years | DEFENSIBLE |
| `perf-sweep/bull-3m.sexp` | 1 | 1000-symbol broad (sentinel) | 3 months | **CONCERN — see below** |
| `perf-sweep/bull-6m.sexp` | 1 | 1000-symbol broad (sentinel) | 6 months | **CONCERN — see below** |
| `goldens-broad/*` | 4 | 1654-symbol broad (full) | 4–6 years (SKIPPED) | DEFENSIBLE — placeholders pending data-panels Stage 4 |

**Concern (info, not a blocker)** — `perf-sweep/bull-3m.sexp` and `bull-6m.sexp` carry tier-1 tags whose rationale text says "when run with a small universe_cap override". But `perf_tier1_smoke.sh` invokes `scenario_runner.exe` with NO `--override` flag — the runner doesn't even parse one. Confirmed by reading `scenario_runner.ml`: it reads `s.config_overrides` from the sexp itself, which is `()` (empty) for both bull-3m and bull-6m. The `universe_cap` override mechanism is the property of `dev/scripts/run_perf_sweep.sh` (which uses a different binary), NOT of `scenario_runner`. So when invoked via tier-1 smoke, both scenarios will run against the FULL ~1654-symbol broad universe.

This is mitigated by the smoke runner's `PERF_TIER1_TIMEOUT=120` per-cell guard — over-budget cells time out and report FAIL, surfacing the issue rather than silently corrupting. The plan also explicitly says budgets are loose initially. Net: tier-1 placement of these two scenarios may be optimistic, but the contract enforces visibility, not silent failure. Status file's roadmap item #4 ("After ~10 PR cycles of tier-1 perf data: pin per-cell budgets") is the right re-evaluation moment.

## Annotate-only semantics check

Plan §"Decision items" #3 says: annotate-only initially, with a future-strict toggle. Verified empirically:
- Default mode (no env var): WARNING line + exit 0 — does not block dune runtest.
- `PERF_CATALOG_CHECK_STRICT=1`: FAIL line + exit 1 — gates dune runtest.
- Wired into `(alias runtest)` in `trading/devtools/checks/dune` per the same pattern as other check scripts.

Matches the plan's contract.

## Held-out workflow note

[info] `.github/workflows/perf-tier1.yml` is intentionally absent from this PR (agent PAT lacks `workflow` scope). Until a maintainer commits the workflow with a workflow-scoped token, no per-PR perf gate fires on push/PR events — only the local catalog check runs in `dune runtest`. The script's workflow-cross-check skips cleanly when the file is absent (verified by current state). This is acceptable for Steps 1+2; the gate can land in a follow-up commit.

## Quality Score

5 — Tier choices are largely defensible and the one debatable placement (bull-3m/bull-6m at T1) is robust to being wrong because of the per-cell timeout. The catalog check has crisp guards, both annotate-only and strict modes work as advertised, and the workflow-drift cross-check fires correctly on synthetic bad-workflow injection. The held-out workflow file is a documented scope limitation, not a contract gap.

(Does not affect verdict. Tracked for quality trends over time.)

## Verdict

APPROVED

