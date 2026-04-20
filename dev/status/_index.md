# Status Index

Single-source view of all tracked work. Update when a status file flips
state, an owner changes, or a PR opens / merges / closes. Keep the table
terse; detail belongs in the per-track status files linked in column 1.

Last updated: 2026-04-20 (run-4 reconcile: no new commits on any open PR since run-3. PR tip SHAs match Reviewed SHAs in dev/reviews/*.md, so no re-QC needed. All 4 PRs (#463, #464, #466, #467) remain APPROVED and awaiting human merge — the throttle this window is review queue depth, not orchestrator capacity. No new feat/harness/ops-data/cleanup dispatches this run: backtest-scale is at the plan-first stack cap (#463 root + #466 stacked = 2/2); harness has 2 PRs in flight, and §Step 1.5 skips further dispatch while non-plan-first work is in review; data-gaps.md unchanged; cleanup backlog empty.)

## Active + complete tracks

Each row: one line; deeper task detail in the linked status file.
"Next task" = top-of-queue concrete item from that file's Next Steps.

| Track | Status | Owner | Open PR(s) | Next task |
|---|---|---|---|---|
| [backtest-infra](backtest-infra.md) | MERGED | — | — | — (#419 per-phase tracing merged 2026-04-19) |
| [backtest-scale](backtest-scale.md) | READY_FOR_REVIEW | feat-backtest | #463, #466 | #463 (3f-part1 shadow_screener adapter) and #466 (3f-part2 tiered runner path skeleton, stacked on #463) both APPROVED and unchanged since run-3. Stack is at depth 2/2 (plan-first cap), so no new dispatch until one lands. Next: 3f-part3 — Friday Summary-promote → Shadow_screener.screen → Full-promote cycle + per-transition promote/demote. Then 3g (parity acceptance test) is the merge gate. |
| [support-floor-stops](support-floor-stops.md) | MERGED | — | — | — (PRs #382 primitive + #390 wiring both merged 2026-04-17) |
| [short-side-strategy](short-side-strategy.md) | MERGED | — | — | — (#420 merged 2026-04-19). Follow-ups carried to own tracks: bear-window backtest regression, full short cascade, Ch.11 behavioural spot-check. |
| [strategy-wiring](strategy-wiring.md) | MERGED | — | — | — (#408 + #409 both merged 2026-04-18) |
| [sector-data](sector-data.md) | MERGED | — | — | — (#436 merged 2026-04-19). GHA orchestrator runs continue to consume `trading/test_data/sectors.csv`. |
| [harness](harness.md) | READY_FOR_REVIEW | harness-maintainer | #464, #467 | #464 (T3-G audit trail quality-score wiring) and #467 (Same-day summary consolidation — `dev/lib/consolidate_day.sh` + Step 8b wiring) both APPROVED and unchanged since run-3 — two open harness PRs in flight, so Step 1.5 skips further dispatch. Remaining open after these land: advisory T3 items (T3-C superseded, T3-F rule-promotion, T3-H commit-level QC) + Tier 4 end-state. |
| [orchestrator-automation](orchestrator-automation.md) | IN_PROGRESS | harness-adjacent | — | Phase 1 live (daily cron runs producing summary PRs). Phase 2 (background execution for scrapers, golden re-runs, cross-feature QC) pending empirical tests per status file. |
| [cleanup](cleanup.md) | IN_PROGRESS | code-health | — | Backlog remains empty (no new medium/high findings from latest deep scan or today's fast-run4). No code-health dispatch this run. |
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
