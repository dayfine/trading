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

---

# QC Structural Review — backtest-g6-decade-nondeterminism (PR #703)
Date: 2026-04-30
Reviewer: qc-structural

Reviewed SHA: e39bda57ccedbd04f4c150791c8c021f9b11ba0e

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | |
| H2 | dune build | PASS | |
| H3 | dune runtest | PASS | Trading-specific tests passed; pre-existing linter warnings on unmodified modules do not block (file-length, nesting, magic-numbers failures pre-date this PR) |
| P1 | Functions ≤ 50 lines (linter) | PASS | New test module opens Matchers; dune-wired linter coverage includes new files |
| P2 | No magic numbers (linter) | PASS | No magic numbers in new code |
| P3 | Config completeness | NA | Investigation note + regression test; no new config parameters |
| P4 | .mli coverage (linter) | NA | No new .mli files |
| P5 | Internal helpers prefixed with underscore | PASS | `_load_scenario`, `_sector_map_override`, `_run`, `_trades_of`, `_first_trade_divergence`, `_fixtures_root`, `_target_scenario_relpath`, `_perturber_scenario_relpath` all properly prefixed |
| P6 | Tests conform to test-patterns.md | PASS | Test opens `open Matchers`; Sub-rule 1 (List.exists + equal_to) — no matches. Sub-rule 2 (let _ = ...on_market_close or .run without assert) — no matches (all backtest runs captured and examined). Sub-rule 3 (match/Error/Ok without is_ok_and_holds) — clean: one assert_that on final_portfolio_value with float_equal matcher; explicit OUnit2.assert_failure for integration-test diagnostics (appropriate for cross-cell isolation checks that need clear error messages) |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to core modules; pure test + infra additions |
| A2 | No analysis/ → trading/ imports outside backtest exception | PASS | PR imports `weinstein.data_source` in dune file (allowed under backtest exception); pure test module |
| A3 | No unnecessary existing module modifications | PASS | File list from `gh pr view 703 --json files`: (1) investigation note markdown, (2) status file update (status section only, added "Completed" entry), (3) dune file (added test names/modules/library deps), (4) new test .ml file. No cross-feature drift, no unrelated modules touched. |

## Verdict

APPROVED

## Notes

- **Hard gates (H1–H3):** All pass. Pre-existing linter failures (file-length, nesting, magic-numbers on core modules from earlier features) do not block this PR.
- **Investigation + test quality:** The investigation note (`dev/notes/g6-decade-nondeterminism-investigation-2026-04-30.md`) is a rigorous audit of the fork-per-cell flow in `scenario_runner.ml`, narrowing the non-determinism to order-ID generation in `trading/orders/lib/create_order.ml` (a core module outside this agent's scope, correctly flagged for feat-weinstein/orders-owner follow-up). The regression test (`test_scenario_runner_isolation.ml`) pins the cross-cell isolation property on small-window data where the divergence does NOT currently reproduce, correctly classifying it as a forward guard per the task spec.
- **Test harness integration:** New dune file properly adds `test_scenario_runner_isolation` to the test suite and includes all required dependencies (`backtest`, `weinstein.data_source`, `trading.simulation`). Three test cases: (1) target after one perturber round_trips match standalone, (2) target after one perturber final_portfolio_value within ε=1e-9, (3) target across two perturber cycles round_trips stable. All pass on GHA-sized fixtures.
- **Status file:** Correctly updated with a "Completed" entry documenting the investigation finding, the flag to feat-weinstein/orders-owner for follow-up, and a note that the regression test PASSES today on small data and will catch regressions.

---

# Behavioral QC — backtest-g6-decade-nondeterminism (PR #703)
Date: 2026-04-30
Reviewer: qc-behavioral

## Note on applicability

This PR is a **pure infrastructure / investigation / forward-guard test PR** with no production code changes and no Weinstein-domain logic. It adds:
- A forward-guard regression test (`test_scenario_runner_isolation.ml`, ~215 LOC).
- An investigation note (`dev/notes/g6-decade-nondeterminism-investigation-2026-04-30.md`, 268 LOC).
- A `dev/status/backtest-perf.md` § Completed entry.
- A dune rule update for the new test.

Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely": pure infra / harness PRs that touch no domain logic — the generic CP1–CP4 alone constitute the full review. The S*/L*/C*/T* block is marked NA.

Authority docs / claims sources consulted:
- PR #703 body — explicit claims about what the PR does + does not do.
- `dev/notes/g6-decade-nondeterminism-investigation-2026-04-30.md` — investigation claims.
- `trading/trading/backtest/scenarios/test/test_scenario_runner_isolation.ml` public docstring + `test_…` definitions.
- `trading/trading/orders/lib/create_order.ml` + `trading/trading/orders/lib/manager.ml` — to verify the suspected leak-site narrative is plausible.
- `dev/status/backtest-perf.md` § Completed entry.

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | NA | No new .mli files in this PR. The new test module's top-of-file docstring (lines 1–28) is descriptive (purpose, sibling test, GHA-data caveat) and makes no promises about the `_run`/`_to_trade` helpers beyond what the suite asserts. |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" has a corresponding test in the committed test file | PASS | PR body advertises three sub-tests under "Forward-guard regression test": (a) "round_trips bit-identical to standalone" → `test_target_after_perturber_matches_standalone` (line 141); (b) "final_portfolio_value within 1e-9" → `test_target_after_perturber_summary_matches` (line 166, uses `float_equal ~epsilon:1e-9`); (c) "round_trips stable across two perturber+target cycles" → `test_target_after_two_perturber_cycles_matches` (line 179). All three are wired into the suite (lines 204–213) and present in the committed file. The agent reports 3 PASS in ~10 sec; the test passing today against the suspected (but non-reproducing on small data) leak is exactly the forward-guard contract this PR claims (small-data property holds today; test catches future regressions that flip even small-window runs). |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size_is | PASS | The "isolation" property is essentially an identity contract: `metric_record(target_alone) == metric_record(target_after_perturber)`. The implementation pins this via `_first_trade_divergence` (line 115), which performs element-wise structural-equality (`equal_trade`, derived via `[@@deriving sexp, eq, show]` on the local mirror type) and reports the first differing trade with a full record dump. This is correct identity-pinning, not size-only. The summary test (line 166) bit-pins `final_portfolio_value` with epsilon=1e-9 (effectively bit-equal). No `size_is`-only shortcuts. |
| CP4 | Each guard in code docstrings has a test that exercises the guarded scenario | PASS | The investigation note's primary guard claim is "the leak is INSIDE the child runtime, not at the parent-fork boundary" + "different scenario before the target run does not contaminate." The test exercises this guard surface directly: it runs a perturber scenario (`tiered-loader-parity`) and re-runs the target (`panel-golden-2019-full`) in-process; if the in-process property holds, the fork-mode property holds (via the strict-subset argument the docstring at lines 5–8 makes). The "two-cycle" sub-test (line 179) further exercises the guard against leaks that ONLY surface after multiple perturber rounds — addressing a stated concern in the docstring. The test reports PASS on small data, matching the explicit forward-guard contract ("test holds today on small windows; would catch a regression that breaks isolation badly enough to flip even small runs"). |

### Plausibility check — investigation note's suspected primary site (CP4 supplementary)

Spot-verified the investigation note's mechanism narrative against source:
- `_generate_order_id` at `trading/trading/orders/lib/create_order.ml:16-21` does mint IDs with `Time_ns_unix.now() |> to_int63_ns_since_epoch` prefix + `Random.int 10000` suffix — verified.
- `Manager.orders` is `(order_id, order) Hashtbl.t` at `trading/trading/orders/lib/manager.ml:12` — verified.
- `Manager.list_orders` iterates via `Hashtbl.fold (fun _ order acc -> order :: acc) manager.orders []` at `manager.ml:56-58` — verified.

Chain (timestamp prefix → Hashtbl bucket order → list_orders fold order → process_orders fill order → metrics divergence) is internally consistent against the cited evidence. The note correctly hedges that wall-clock-derived IDs alone don't fully explain the run-1=run-3 vs run-2 batch divergence (note §"Structural finding") and offers a CPU-contention amplifier hypothesis. Plausible for the investigation's stated purpose (flagging the site for follow-up, not pinning a fix).

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic (only fill if qc-structural flagged A1) | NA | qc-structural reported A1 PASS — no core-module touches in this PR (the PR is explicit that it does NOT fix the suspected `trading/orders/lib/create_order.ml` site, just flags it). |
| S1 | Stage 1 definition matches book | NA | Pure infra / investigation / test PR; domain checklist not applicable. |
| S2 | Stage 2 definition matches book | NA | Pure infra / investigation / test PR; domain checklist not applicable. |
| S3 | Stage 3 definition matches book | NA | Pure infra / investigation / test PR; domain checklist not applicable. |
| S4 | Stage 4 definition matches book | NA | Pure infra / investigation / test PR; domain checklist not applicable. |
| S5 | Buy criteria: Stage 2 entry on breakout with volume | NA | Pure infra / investigation / test PR; domain checklist not applicable. |
| S6 | No buy signals in Stage 1/3/4 | NA | Pure infra / investigation / test PR; domain checklist not applicable. |
| L1 | Initial stop below base | NA | Pure infra / investigation / test PR; domain checklist not applicable. |
| L2 | Trailing stop never lowered | NA | Pure infra / investigation / test PR; domain checklist not applicable. |
| L3 | Stop triggers on weekly close | NA | Pure infra / investigation / test PR; domain checklist not applicable. |
| L4 | Stop state machine transitions | NA | Pure infra / investigation / test PR; domain checklist not applicable. |
| C1 | Screener cascade order | NA | Pure infra / investigation / test PR; domain checklist not applicable. |
| C2 | Bearish macro blocks all buys | NA | Pure infra / investigation / test PR; domain checklist not applicable. |
| C3 | Sector RS vs. market, not absolute | NA | Pure infra / investigation / test PR; domain checklist not applicable. |
| T1 | Tests cover all 4 stage transitions | NA | Pure infra / investigation / test PR; domain checklist not applicable. |
| T2 | Bearish-macro → zero buy candidates test | NA | Pure infra / investigation / test PR; domain checklist not applicable. |
| T3 | Stop trailing tests | NA | Pure infra / investigation / test PR; domain checklist not applicable. |
| T4 | Tests assert domain outcomes, not "no error" | NA | Pure infra / investigation / test PR; domain checklist not applicable. |

## Quality Score

5 — Investigation note is a rigorous, well-evidenced audit (parent-fork flow walk, candidate enumeration with measurable claims, multiplicative-surface math explaining why only the 10y cell drifts, hedged "explanations of last resort" where the primary mechanism doesn't fully account for run-1=run-3 vs run-2 divergence). The forward-guard test is correctly scoped (in-process is a stricter contract than fork-mode per the strict-subset argument), structurally pinned with element-wise identity (not size-only), and includes a 2-cycle stress sub-test. PR body claims map cleanly to committed test names. The agent correctly STOPPED at the scope boundary (suspected fix site is in core orders module) rather than overstepping.

(Does not affect verdict. Tracked for quality trends over time.)

## Verdict

APPROVED
