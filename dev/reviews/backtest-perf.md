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


---

# Behavioral QC — backtest snapshot-cache occupancy telemetry (PR #2888)

## Behavioral QC — backtest snapshot-cache occupancy telemetry (#2878)

Reviewed SHA: 6e56853b3647b3b0d94c13ff54bd2d4a9c7fc88a
CI re-checked at this tip by me: `build-and-test` success, `perf-tier1-smoke` success, `goldens-affected` success.

**Scope.** Pure infrastructure telemetry. No Weinstein domain logic, no strategy
config field, no `[@sexp.default]` in the diff. Per
`.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely",
the entire S\*/L\*/C\*/T\* domain block is **NA** and CP1–CP4 is the full review.
Authorities used: the new/changed `.mli` docstrings, the PR body's claims, and
issue #2878's ask. The book is not implicated and was not consulted.

**Method: mutation testing, not a read-through.** 21 mutations applied
individually to the PR's own source, each built and run, each reverted before
the next. Reruns were scoped to the three affected test executables
(`test_daily_panels.exe`, `test_snapshot_cache_config.exe`, `test_gc_trace.exe`,
`test_panel_runner_gc_trace.exe`) rather than the full suite — structural
already ran `dune runtest` green at this tip, so a clean-build pass was not
repeated. Working tree verified clean (`git status --porcelain` empty) after the
last revert.

### Mutation results — 19 RED, 2 GREEN

Hunting the two shapes the author was warned about: the **projection blind spot**
(#2875) and the **vacuous fixture** (#2875, deeper half).

| # | mutation | result |
|---|---|---|
| M1 | `occupancy.max_entries` + 1 | RED (8 failures) |
| M2 | `occupancy.max_bytes` + 1 | RED (8) |
| M3 | `occupancy.max_mmap_open` + 1 | RED (7) |
| M4 | `occupancy.avg_entries` + 1.0 | RED (7) |
| M5 | `occupancy.avg_bytes` + 1.0 | RED (6) |
| M6 | `miss_absent` never incremented | RED (1) |
| M7 | `n_symbols_touched` + 1 | RED (7) |
| M8 | `n_symbols_absent` + 1 | RED (6) |
| M9 | sample **before** `_enforce_limits` (docstring says after) | RED |
| M10 | **bit-identical probe:** `_over_limits` consults `Occupancy.summary` | RED |
| M11 | drop `cap_mb=%d` from the format string | **COMPILE_ERROR** |
| M12 | move `miss_absent` to after `evictions` in the line | RED |
| M13 | `loads_per_touched` forgets to subtract `miss_absent` | RED |
| M14 | `maxrss` scaled by word size instead of kB | **GREEN — unpinned** |
| M15 | `top_heap` scaled by kB instead of word size | **GREEN — unpinned** |
| M16 | `avg_bytes` rounds instead of truncates | RED |
| M17 | **zero-overhead probe:** force the sampler before `record`'s `None` check | RED |
| M18 | unsampled cache columns render `0,0,0` instead of `,,` | RED |
| M19 | drop `mmap_open` from the CSV header | RED |
| M20 | `Panel_runner` stops passing `~cache_sampler` (the wiring) | RED |
| M21 | **anti-vacuity probe:** flatten `_sized_six` to uniform row counts | RED |

**M1–M8 close the projection blind spot.** Every occupancy field and every new
counter reddens *individually*. The mechanism is `_expect_stats`, which builds a
whole expected `stats` record and compares with `equal_to`, so no field is
dropped from the comparison. Where a float tolerance forced a leaf-by-leaf form
(`test_v2_handle_cap_at_symbol_count_never_evicts`,
`test_occupancy_peaks_at_binding_handle_cap`) all 11 leaves are asserted rather
than a partial projection. #2875 does not recur.

**M21 closes the vacuous fixture — and the guard defends itself.** `_sized_six`
carries strictly increasing row counts, and
`test_occupancy_bytes_track_entry_sizes_not_counts` asserts that precondition
(`sizes = List.dedup_and_sort sizes`) *before* using it. Flattening the fixture
to uniform sizes reddens immediately, so the fixture cannot silently decay into
the vacuous state. This is the strongest form of the fix I have seen on this
codebase and is worth citing to other PRs.

**The armed/control pair is real.** `test_occupancy_peaks_at_binding_handle_cap`
runs 6 symbols under a handle cap of 3 (cap binds: `evictions = 3`,
`max_entries = 3`, `max_mmap_open = 3`, `avg_entries = 2.5` from the 1,2,3,3,3,3
ramp); `test_occupancy_control_unbinding_cap_reports_true_peak` runs the same
fixture at cap 6 (`evictions = 0`, peaks report true residency 6,
`avg_entries = 3.5`). Without the control, `max_entries = cap` could pass on an
implementation that merely echoed the cap. The dispatch brief's worry that the
eviction path might be unpinned because the author's reported run shows
`max_mmap_open=0 evictions=0` does **not** hold: that is the *integration*
fixture (a v1 in-process snapshot); the *unit* tests do exercise a binding cap
and a non-zero eviction count, and M3/M9/M10 all redden through that path.

**M11 is the strongest pinning in the PR.** Dropping a field from the format
string is a *compile* error (sprintf arity), not a test failure — structural's
#2875 observation that compile-time pinning beats any test, realised here for
free. M12 confirms the render test pins the **whole line** character-for-character
rather than a substring: reordering two adjacent fields reddens.

**`max_entries = j`, not `j+1`, and the docstring says so.** Because the sample
is taken *after* `_enforce_limits`, the armed arm correctly asserts
`max_entries = 3` under a cap of 3 with 6 symbols. `daily_panels.mli` states
"Under a binding handle cap `max_mmap_open` equals that cap (and `max_entries`
equals it too when every entry is an `Mmap` backing)" — the test matches the
docstring; neither assumes the other. The separately-documented oversized-entry
carve-out (`_enforce_limits` leaves ≥ 1 entry resident) is an independent claim
about the *byte* budget and is stated as such (`max_bytes` "can exceed the byte
budget by design").

**The `misses_per_symbol` compatibility claim is accurate.** I read the format
string, not the prose. Old: `hits misses evictions n_symbols misses_per_symbol`.
New: `hits misses miss_absent evictions n_symbols misses_per_symbol`. So
`miss_absent` is inserted *before* `evictions`; `misses_per_symbol` keeps its key,
its value and its position immediately after `n_symbols` (a `misses_per_symbol=`
grep still matches); and every field from `evictions` rightward shifts one place
for a positional `awk` reader. That is exactly what the `.mli` and the PR body
say. The final commit's self-correction landed correctly.

### Bit-identical claim — verified, not taken on trust

The load-bearing claim. Verified three ways:

1. **Structural separation is enforced by definition order.** `_over_limits`,
   `_enforce_limits` and `_evict_one` are all defined *above* `_sample_occupancy`
   in `daily_panels.ml`, so the eviction path cannot reference the accumulator
   without a deliberate code move. The `occ` field is written only by
   `Occupancy.sample` / `touch` / `mark_absent` and read only by `cache_stats`.
2. **M10 proves a future violation would be caught.** I made `_over_limits`
   consult `(Daily_panels_occupancy.summary t.occ).max_entries` so that eviction
   stops once the peak exceeds 2 — a genuine telemetry-influences-behaviour
   change of exactly the shape this PR promises never to make. Two eviction tests
   went red.
3. **M17 pins the `--gc-trace`-off overhead claim.** `test_cache_sampler_not_forced_without_trace`
   is a call-counter, not a comment; forcing the thunk before `record`'s `None`
   check reddens it. `Panel_runner` builds the sampler closure unconditionally
   (one partial application per run) but it is only ever *forced* inside
   `Gc_trace.record`'s `Some trace` branch. The claim is "zero overhead", and one
   closure allocation per run is a fair reading of that.

I found **no** behaviour change and **no** golden movement. `goldens-affected` is
green at this tip and the PR correctly states that
`.claude/rules/config-default-blast-radius.md` does not fire (zero
`[@sexp.default …]` and zero `let default*` records in the diff — I confirmed
this against the diff).

I also independently reproduced the author's reported after-line by running
`test_panel_runner_gc_trace.exe` in my own worktree:

```
Panel_runner: snapshot cache hits=25793 misses=22 miss_absent=0 evictions=0 n_symbols=22 misses_per_symbol=1.00 n_symbols_touched=22 n_symbols_absent=0 loads_per_touched=1.00 max_entries=22 max_bytes=1278608 max_mmap_open=0 avg_entries=11.5 avg_bytes=697518 cap_mb=4096 cap_mmap_handles=256 top_heap_bytes=18265984 maxrss_bytes=31952896
```

Byte-identical to the PR body except `top_heap_bytes` / `maxrss_bytes`, which are
environment-dependent by construction. The PR body's "Before" line is explicitly
labelled *reconstructed, not re-run*, and its five values do appear byte-for-byte
in the after line — an honest disclosure of a reconstruction rather than a
silent one.

### The `misses` / `miss_absent` design decision

I judge the author's reasoning sound, and the `.mli` honest about it.

- **`misses` semantics genuinely unchanged.** `t.misses <- t.misses + 1` still
  fires *before* the manifest lookup (unchanged context line in the diff), so an
  absent symbol still counts as a miss exactly as on `main`. The `.mli` says
  "**Meaning unchanged** since the counter was introduced: it still counts every
  non-hit read, including reads of symbols that are not in the manifest at all."
  That is true of the code. Redefining it would have silently moved a number
  present in every historical chain log — the conservative choice is right.
- **Declining to add a negative-lookup cache is correct for this PR.** It would
  alter the load path, which is precisely the constraint a telemetry PR is under,
  and the avoided cost is an O(1) hashtable miss. `n_symbols_absent` exposes the
  actionable quantity (the warehouse-coverage hole, counted in names) without
  touching behaviour. M6 and `test_absent_symbol_misses_are_split_out` pin that an
  absent read increments *both* `misses` and `miss_absent`, counts distinct absent
  names, and leaves occupancy untouched (`n_symbols_touched` stays at the one real
  symbol) — the full contract, not just the counter.
- **`loads_per_touched` is the honest ratio and M13 pins the subtraction.**

### Sampling point

Issue #2878 required "pick one and document it". Both halves check out:

- **Documented** in `daily_panels.mli`'s `occupancy` docstring, with the rejected
  alternative (per-`read_today`) and *why* it was rejected (means would be
  weighted by read frequency, not residency), plus the consequence of sampling
  after enforcement (marks are peak **resident**, never a transient over-limit
  spike). The PR body repeats it and `daily_panels_occupancy.mli` cross-refers
  rather than duplicating — the contract has one owner.
- **Implemented where the docstring says.** `_sample_occupancy` is called from
  `_insert_into_cache`, after `_enforce_limits`, once per insert. M9 (moving the
  sample before enforcement) reddens two tests, so the documented ordering is
  pinned by the suite and not merely asserted in prose.

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new `.mli` docstrings has an identified test that pins it | PASS | `occupancy` high-water/mean semantics → M1–M5 all red via `_expect_stats` whole-record equality + the sized/armed/control trio. "Sampling point: once per insert, after limit enforcement" → M9 red. "Every field here is observation only … results are identical whether or not the counters are consulted" → M10 red (bit-identical probe). `miss_absent` / `n_symbols_touched` / `n_symbols_absent` → M6/M7/M8 red + `test_absent_symbol_misses_are_split_out`. `resident` + `max_cache_bytes` / `max_mmap_handles` → `test_resident_and_caps_report_live_state`. `render_cache_stats_line` format contract → M11 (compile error) / M12 / M13 / M16 red. `Gc_trace.record` "called **only** on the `Some trace` path, so a run without `--gc-trace` pays nothing" → M17 red. "`None` renders as three blank CSV fields — blank rather than a sentinel" → M18 red. CSV header → M19 red. Residual R1 below is the one `.mli` claim a mutation did not redden. |
| CP2 | Each claim in the PR body's "Test design" / "Bit-identical" sections has a corresponding test in the committed test files | PASS | "Whole-record assertions … a regression in any field reddens" → verified by M1–M8, not assumed. "Distinct per-symbol sizes … the strict-increase precondition is *itself* asserted" → verified by M21. "Armed / control pair" → both tests present and asserting different peaks (3 vs 6) and eviction counts (3 vs 0). "Wiring pinned end-to-end" → M20 red. "Line format pinned character-for-character, with all-distinct field values so no two columns can be transposed" → M12 red. "`--gc-trace` off … pinned by a call-counter test, not by a comment" → M17 red, and it is literally a call counter. Every advertised test exists in the committed files; no claim is unbacked. |
| CP3 | Pass-through / identity / invariant contracts pin identity, not just size/shape | PASS | The identity contract here is *bit-identical behaviour*, and M10 is the direct probe: making the eviction path read telemetry reddens. The record-level analogue also holds — `_expect_stats` compares the entire `stats` value with `equal_to`, and `test_cache_sampler_forced_once_per_record` compares the whole `(calls, cache list)` tuple with `equal_to (2, [Some _sample; Some _sample])` rather than counting elements. `test_cache_columns_render_sampled_and_blank` uses `elements_are [equal_to "12,3456,7"; equal_to ",,"]`, not `size_is 2`. |
| CP4 | Each guard called out explicitly in code docstrings has a test exercising the guarded-against scenario | PASS | "blank rather than a sentinel so a consumer cannot mistake 'not sampled' for a measured zero" → `test_cache_columns_render_sampled_and_blank`, M18 red. "the thunk is never forced and no cache is touched" without `--gc-trace` → `test_cache_sampler_not_forced_without_trace`, M17 red. "means are `0.0` when no sample was ever taken" / zero-denominator ratios → `test_zero_denominators_render_zero` pins `0.00`, not nan/inf. "the marks describe peak **resident** occupancy, never a transient over-limit spike" → M9 red. "`n_symbols_touched` … Using the *universe* size as the denominator understates thrash" → `test_absent_misses_move_only_the_loads_ratio` pins that removing absent misses moves `loads_per_touched` (2.70) and leaves `misses_per_symbol` (1.35) alone. `_release_entry`/fd-leak guard is pre-existing and untouched. |

## Behavioral Checklist (domain)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1, S1–S6, L1–L4, C1–C3, T1–T4 | — | NA | Pure infrastructure / telemetry PR; touches no Weinstein domain logic, no stage classifier, no stop, no screener, no strategy config. Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely", the domain checklist does not apply and CP1–CP4 above is the full review. qc-structural did not flag A1. No `BOOK-CHECK-NEEDED` items arise. |

## Residuals (non-blocking — do not hold this PR)

**R1 — `read_process_high_water`'s unit-conversion scalars are unpinned.**
The two GREEN mutations. M14 (`maxrss` scaled by `_bytes_per_word` = 8 instead of
`_bytes_per_kb` = 1024, a 128× understatement) and M15 (`top_heap` scaled by 1024
instead of the word size, a 128× overstatement) both leave the suite green,
because `test_process_high_water_is_positive` asserts only `> 0`. The `.mli`
states both scalings precisely ("`top_heap_words` scaled by the word size",
"`ru_maxrss` (kB on Linux) scaled to bytes") and neither claim is pinned.
Cheap fix: replace `gt 0` with a plausible-range assertion — any OCaml test
binary has `maxrss_bytes` ≥ 1 MiB and `top_heap_bytes` ≥ 64 KiB, and both
mis-scalings fall outside those bounds. Non-blocking: these are diagnostic-only
fields read by no decision path, and a 128× error would be obvious in a log.

**R2 — the `close` lifetime claim is unpinned.** `daily_panels.mli` states
"`close` does not reset these — they are lifetime figures. It does drop residency
to zero, so inserts after a `close` sample from an empty cache." I confirmed by
reading `close` that it clears `t.bytes` / `t.mmap_open` and leaves `t.occ`
alone, so the claim is *true* — but no test covers it, and a future `close` that
also reset `occ` would pass. A three-line test (read, close, read, assert
`max_entries` unchanged) would close it.

**R3 — the end-to-end line is only ever rendered in the v1 regime.** The
integration fixture is an in-process CSV snapshot, so the printed line always
carries `max_mmap_open=0 evictions=0`; no test renders the line from a run where
the handle cap actually bound. The *accounting* for that regime is pinned at the
unit level (armed arm, M3/M9/M10), so this is a gap in end-to-end render coverage
only, not in correctness. Worth a v2-backed integration case whenever one is
cheap.

**R4 — process note, not a code finding.** The dispatch brief said structural's
#2888 checklist was on disk at `dev/reviews/backtest-perf.md` with
`Reviewed SHA: 6e56853b…` as line 1. It is not: that file's line 1 is
`Reviewed SHA: 6f689d62…` and its contents are two older reviews (a prior
backtest-perf tiering PR and #703). `dev/reviews/` is untouched by this PR's
diff. I preserved the existing line 1 and appended my section under its own
explicit SHA heading. Structural's #2888 verdict is on the PR itself, so nothing
is lost — flagging so the gate record is not misread later.

## Quality Score

5 — Reference-grade. The two most recent QC catches on this codebase (#2875's
projection blind spot and vacuous fixture) were both anticipated and both closed,
verified by 21 mutations of which 19 reddened; the anti-vacuity precondition is
*itself* asserted so the fixture cannot silently decay, and the log-line format is
pinned at compile time rather than by a test. The bit-identical constraint holds
under direct probing. The one real gap (R1) is two diagnostic-only unit scalars.

## Verdict

APPROVED
