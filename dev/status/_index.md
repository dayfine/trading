# Status Index

Single-source view of all tracked work. Update when a status file flips
state, an owner changes, or a PR opens / merges / closes. Keep the table
terse; detail belongs in the per-track status files linked in column 1.

Last updated: 2026-04-26-run2 (cleanup PR #578 opens on `cleanup/csv-storage-nesting` — extracts two `_`-prefixed helpers in `csv_storage.ml:_stream_in_range_prices` to flatten nesting; no behavior change, ~37 LOC. Verified empirically on the cleanup branch: `OK: nesting linter — all 886 functions within limits` (was: 833 + 1 fail). Build gate still exits 1 on main due to the unrelated `data-panels.md` `## Last updated:` integrity violation, which PR #575 fixes — that PR remains awaiting human merge. data-panels Stage 3 PR 3.4 (#575) and backtest-perf catalog (#574) both unchanged since run-1: tip SHAs match Reviewed SHAs in `dev/reviews/*` so re-QC was correctly skipped per Step 1.5.)

## Active + complete tracks

Each row: one line; deeper task detail in the linked status file.
"Next task" = top-of-queue concrete item from that file's Next Steps.

| Track | Status | Owner | Open PR(s) | Next task |
|---|---|---|---|---|
| [backtest-infra](backtest-infra.md) | MERGED | — | — | — Steps 1 (#399) + 2 (#419) landed earlier. Sweep harness extension #547 landed 2026-04-25. Continuous monitoring + release-gate scope moved to `backtest-perf` track; Tier-3-architecture follow-on now tracked at `data-panels` (supersedes `incremental-indicators`). |
| [backtest-scale](backtest-scale.md) | MERGED (superseded) | — | — | Tiered path entirely deleted in `data-panels` Stage 3 PR 3.3 (#573, 2026-04-26). PR #525 (`Bar_history.trim_before` primitive) merged 2026-04-24 but is now moot — `Bar_history` itself deleted in Stage 3 PR 3.2 (#569). All residual concerns (RSS, parity, Legacy→Tiered flip) absorbed by `data-panels` columnar redesign. Per-track status file lags reality and should be flipped to MERGED/superseded; orchestrator merge-watch flagged but did not auto-edit (leaves discretion to maintainer). |
| [backtest-perf](backtest-perf.md) | IN_PROGRESS (Steps 1+2 READY_FOR_REVIEW) | feat-backtest | #574 (catalog + tier-1 smoke gate) | Steps 1+2 implemented on `feat/backtest-perf-tier1-catalog`: 15 scenarios cataloged into 4 perf tiers (4×T1, 6×T2, 2×T3, 3×T4); `perf_catalog_check.sh` (annotate-only, `PERF_CATALOG_CHECK_STRICT=1` to gate) + `perf_tier1_smoke.sh` (auto-discovers tier-1 scenarios, runs each via `scenario_runner.exe` with timeout 120). QC APPROVED structural+behavioral 5/5. **Held-out:** `.github/workflows/perf-tier1.yml` (drafted in PR body; needs `workflow`-scoped token to commit). Plan #550 merged 2026-04-25. Tier-4 release-gate scenarios were blocked on data-panels stages 0-3 — now unblocked (all merged 2026-04-25/26); tier-4 effort still gated on Stage 4 callback-wiring per data-panels track. Next: Steps 3+4 (tier-2 nightly + tier-3 weekly workflows). |
| [data-panels](data-panels.md) | IN_PROGRESS (Stage 3 PR 3.4 READY_FOR_REVIEW) | feat-backtest | #575 (Stage 3 PR 3.4 on `feat/panels-stage03-pr-d-delete-legacy`) | Columnar data-shape redesign. Stages 0+1+2 foundation merged (#555 / #557 / #558). Stage 2 callee-reshape PRs B–H all merged (#559–#565). **Stage 3 PR 3.1 #567 / 3.2 #569 / 3.3 #573 all MERGED 2026-04-25/26.** **Stage 3 PR 3.4 (this run)**: deletes `_run_legacy` from `runner.ml`, the entire `loader_strategy/` library, `--loader-strategy` CLI flag, and the `loader_strategy` field from `Scenario.t` (`[@@sexp.allow_extra_fields]` retained for back-compat — tested). `run_backtest` now calls `Panel_runner.run` directly. ~271 LOC net delete across 22 files. QC APPROVED structural+behavioral 5/5; load-bearing `test_panel_loader_parity` round_trips golden gate intact. **Next dispatch (after merge):** Stage 4 — callbacks-through-runner wiring; per `dev/notes/panels-rss-spike-2026-04-25.md`, post-3.2 Panel mode peaks at 3.47 GB vs <800 MB projection because every reader site still rebuilds `Daily_price.t list` from panels per tick. Stage 4 wires the `*_with_callbacks` entry points all the way through `Panel_runner` so production no longer materializes the lists. |
| [hybrid-tier](hybrid-tier.md) | IN_PROGRESS (Phase 1) | feat-backtest | (this PR) `feat/hybrid-tier-phase1-measurement` | Hybrid-tier architecture for tier-4 release-gate (master plan `dev/plans/hybrid-tier-architecture-2026-04-26.md`). Phase 1 (measurement-only) lands `--gc-trace` flag on `backtest_runner.exe` + `Backtest.Gc_trace` library + two experiment scenarios under `goldens-hybrid-tier-experiment/` for the load-vs-activity decomposition. Per-Friday `Gc.stat` snapshots inside the simulator loop deferred to Phase 1.5 if coarse phase boundaries prove ambiguous. Phase 2 (Tiered_panels.t) gated on Experiment A/B results — see `dev/notes/hybrid-tier-phase1-cost-model-2026-04-26.md` for the decision rule + recommendation framework. |
| [support-floor-stops](support-floor-stops.md) | MERGED | — | — | — (PRs #382 primitive + #390 wiring both merged 2026-04-17) |
| [short-side-strategy](short-side-strategy.md) | MERGED | — | — | — (#420 merged 2026-04-19). Follow-ups carried to own tracks: bear-window backtest regression, full short cascade, Ch.11 behavioural spot-check. |
| [strategy-wiring](strategy-wiring.md) | MERGED | — | — | — (#408 + #409 both merged 2026-04-18) |
| [sector-data](sector-data.md) | MERGED | — | — | — (#436 merged 2026-04-19). GHA orchestrator runs continue to consume `trading/test_data/sectors.csv`. |
| [harness](harness.md) | IN_PROGRESS | harness-maintainer | — | No open harness PR. Recent merges: #493 POSIX-sh linter, #495 cost-capture new-day fix, #499 cost-capture commit+auto-merge, #504 budget PR creation via curl, #505 budget rescue (all 2026-04-22). Backlog remains saturated — T1 done; T2 milestone-gated; T3-C superseded; T3-H low-priority. Recurring status-file integrity drift from human-merged PRs is a [info] follow-up — linter already exits 1 on violation; requires branch-protection config to enforce. |
| [orchestrator-automation](orchestrator-automation.md) | IN_PROGRESS | harness-adjacent | — | Phase 1 live (daily cron runs producing summary PRs). Phase 2 (background execution for scrapers, golden re-runs, cross-feature QC) pending empirical tests per status file. |
| [cleanup](cleanup.md) | IN_PROGRESS | code-health | #578 (csv_storage nesting fix on `cleanup/csv-storage-nesting`) | Item `[~]` in flight: `_stream_in_range_prices` nested-match cleanup. PR #578 opened this run (run-2); helper-extraction approach. Awaiting human merge. After merge: backlog empty until next health-scan finding. |
| [cost-tracking](cost-tracking.md) | IN_PROGRESS | harness-maintainer | — | GHA cost capture step landed (#483). Cost-capture new-day bug fixed via #495 + #499 (both 2026-04-22). Next: verify measured `total_cost_usd` now lands correctly on this run's `dev/budget/2026-04-22-run3.json`; compare costs pre/post #481/#482/#495/#499. |
| [data-layer](data-layer.md) | MERGED | — | — | — |
| [portfolio-stops](portfolio-stops.md) | MERGED | — | — | — |
| [screener](screener.md) | MERGED | — | — | — |
| [simulation](simulation.md) | MERGED | — | — | — |

## How to use

- **Find what's in flight**: filter rows by Status = IN_PROGRESS.
- **Find what needs an owner**: look for empty Owner cells on non-MERGED rows.
- **Find what's awaiting review**: check the Open PR column.
- **Find the next concrete task** for a track: read its "Next task" cell.
- **Start a session**: open the linked status file to get full context.

## Maintenance

Agent-owned update: any agent that touches `dev/status/<track>.md`
during a session must also update that track's row here if Status,
Owner, Open PR, or Next task changed. Agents only touch their own row,
so parallel write conflicts stay rare.

Orchestrator reconciliation: `lead-orchestrator` diffs this index
against the per-track status files at end-of-run and flags drift.

Adding a new track means creating the status file AND adding a row
here in the same commit.
