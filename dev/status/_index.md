# Status Index

Single-source view of all tracked work. Update when a status file flips
state, an owner changes, or a PR opens / merges / closes. Keep the table
terse; detail belongs in the per-track status files linked in column 1.

Last updated: 2026-04-25 (Stage 2 PR-G of `data-panels` opens as PR #564 on `feat/panels-stage02-pr-g-stops-support-floor`: reshape `Weinstein_stops.compute_initial_stop_with_floor` with a callback path. Adds `Weinstein_stops.compute_initial_stop_with_floor_with_callbacks ~callbacks` plus a `Weinstein_stops.callbacks` bundle (re-export of new `Support_floor.callbacks`) wrapping five day-offset accessors `get_high`/`get_low`/`get_close`/`get_date`/`n_days`. Bundle exposes a pre-windowed view: `as_of` filtering and `support_floor_lookback_bars` truncation are applied at construction so the algorithm scans `[0..n_days-1]` without further bounds checks. Day offset 0 = newest bar; chronological "latest tie wins" maps to "smallest offset wins" via strict `>`. Existing `compute_initial_stop_with_floor ~bars ~as_of` becomes a thin wrapper preserving byte-identical behavior. 10 new parity tests cover support-floor / no-floor-fallback (long+short), anchor-at-end, tie-break-latest-peak / tie-break-latest-trough, lookback-truncates-old-correction, and empty-bars (long+short). PR-F (Macro.analyze) merged as #563. PR-G is the seventh in the eight-PR sequence; PR-H ports the 6 `Bar_history` reader sites and deletes `Bar_history`.)

## Active + complete tracks

Each row: one line; deeper task detail in the linked status file.
"Next task" = top-of-queue concrete item from that file's Next Steps.

| Track | Status | Owner | Open PR(s) | Next task |
|---|---|---|---|---|
| [backtest-infra](backtest-infra.md) | MERGED | — | — | — Steps 1 (#399) + 2 (#419) landed earlier. Sweep harness extension #547 landed 2026-04-25. Continuous monitoring + release-gate scope moved to `backtest-perf` track; Tier-3-architecture follow-on now tracked at `data-panels` (supersedes `incremental-indicators`). |
| [backtest-scale](backtest-scale.md) | READY_FOR_REVIEW | feat-backtest | — | #517 + #519 closed the post-#507 A/B parity gaps. Verified on GHA `tiered-loader-ab` (run 24870169890). 5 hypothesis tests against the residual +95% Tiered RSS gap (H1 trim, H2 cap, H3 skip-AD, H7 stream-CSV, GC tuning, List.filter refactor #548) — all disproved. Diagnosis: heap-doesn't-shrink + structural ~2× ratio from post-#519 promote-all design. Memory work continues on the new `data-panels` track (columnar redesign, plan #554). 7-symbol CI fixture rebuild + Tiered flip default still open follow-ups (latter likely moot once data-panels lands). |
| [backtest-perf](backtest-perf.md) | PENDING | feat-backtest | #550 (catalog + release-gate plan) | Continuous perf coverage in CI + release-gate strategy. 4-tier scenario catalog (per-PR / nightly / weekly / release). Tier 4 (5000-stock decade-long release-gate) blocked on `data-panels` stages 0-3 landing. |
| [data-panels](data-panels.md) | IN_PROGRESS (Stage 2, PR-G in 8-PR sequence) | feat-backtest | #564 (feat/panels-stage02-pr-g-stops-support-floor) | Columnar data-shape redesign. Stages 0-1 + Stage 2 foundation merged (#555, #557, #558). PR-B (`Stage.classify`) #559, PR-C (`Rs.analyze`) #560, PR-D (`Stock_analysis.analyze`) #561, PR-E (`Sector.analyze`) #562, PR-F (`Macro.analyze`) #563 — all merged. **Stage 2 PR-G (this branch, PR #564)**: reshape `Weinstein_stops.compute_initial_stop_with_floor` with a callback path. Adds `Weinstein_stops.compute_initial_stop_with_floor_with_callbacks ~callbacks` plus a `Weinstein_stops.callbacks` bundle (re-export of new `Support_floor.callbacks`) wrapping five day-offset accessors `get_high`/`get_low`/`get_close`/`get_date`/`n_days`. Bundle exposes a pre-windowed view: `as_of` filtering and `support_floor_lookback_bars` truncation are applied at construction so the algorithm scans `[0..n_days-1]` without further bounds checks. Day offset 0 = newest bar; chronological "latest tie wins" maps to "smallest offset wins" via strict `>`. Existing `compute_initial_stop_with_floor ~bars ~as_of` becomes a thin wrapper preserving byte-identical behavior. 10 new parity tests cover support-floor / no-floor-fallback (long+short), anchor-at-end, tie-break-latest-peak / tie-break-latest-trough, lookback-truncates-old-correction, and empty-bars (long+short). Next: PR-H ports the 6 `Bar_history` reader sites + deletes Bar_history + reshapes Volume/Resistance to drop the bars_for_volume_resistance parameter. |
| [support-floor-stops](support-floor-stops.md) | MERGED | — | — | — (PRs #382 primitive + #390 wiring both merged 2026-04-17) |
| [short-side-strategy](short-side-strategy.md) | MERGED | — | — | — (#420 merged 2026-04-19). Follow-ups carried to own tracks: bear-window backtest regression, full short cascade, Ch.11 behavioural spot-check. |
| [strategy-wiring](strategy-wiring.md) | MERGED | — | — | — (#408 + #409 both merged 2026-04-18) |
| [sector-data](sector-data.md) | MERGED | — | — | — (#436 merged 2026-04-19). GHA orchestrator runs continue to consume `trading/test_data/sectors.csv`. |
| [harness](harness.md) | IN_PROGRESS | harness-maintainer | — | No open harness PR. Recent merges: #493 POSIX-sh linter, #495 cost-capture new-day fix, #499 cost-capture commit+auto-merge, #504 budget PR creation via curl, #505 budget rescue (all 2026-04-22). Backlog remains saturated — T1 done; T2 milestone-gated; T3-C superseded; T3-H low-priority. Recurring status-file integrity drift from human-merged PRs is a [info] follow-up — linter already exits 1 on violation; requires branch-protection config to enforce. |
| [orchestrator-automation](orchestrator-automation.md) | IN_PROGRESS | harness-adjacent | — | Phase 1 live (daily cron runs producing summary PRs). Phase 2 (background execution for scrapers, golden re-runs, cross-feature QC) pending empirical tests per status file. |
| [cleanup](cleanup.md) | IN_PROGRESS | code-health | — | Backlog remains empty (no new medium/high findings from latest deep scan or today's fast health check). No code-health dispatch this run. |
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
