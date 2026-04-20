# Status Index

Single-source view of all tracked work. Update when a status file flips
state, an owner changes, or a PR opens / merges / closes. Keep the table
terse; detail belongs in the per-track status files linked in column 1.

Last updated: 2026-04-20 (run-5 reconcile: all 4 open PRs from run-4 merged between 16:37-17:03 UTC — #463 3f-part1 shadow screener adapter, #464 T3-G audit trail quality-score, #466 3f-part2 tiered runner skeleton, #467 T3-J same-day consolidation. This run dispatched 2 new tracks in parallel: feat-backtest on 3f-part3 (PR #474) and harness-maintainer on T3-F rule promotion path (PR #473). Both QC cycles completed APPROVED — #474 structural + behavioral (Quality Score 4); #473 structural; audit records written to dev/audit/. Draft flip and fresh-stack dispatch not attempted this run: 3g acceptance test depends on 3f-part3 LANDING (not just branch existing, per plan Resolutions §4 parity harness needs full promote/demote loop merged). Cleanup backlog empty after latest deep scan; ops-data skipped — data-gaps.md unchanged.)

## Active + complete tracks

Each row: one line; deeper task detail in the linked status file.
"Next task" = top-of-queue concrete item from that file's Next Steps.

| Track | Status | Owner | Open PR(s) | Next task |
|---|---|---|---|---|
| [backtest-infra](backtest-infra.md) | MERGED | — | — | — (#419 per-phase tracing merged 2026-04-19) |
| [backtest-scale](backtest-scale.md) | READY_FOR_REVIEW | feat-backtest | #474 | #474 (3f-part3 tiered runner Friday cycle + per-transition promote/demote) APPROVED this run — structural + behavioral both green (Quality Score 4). Reviewed SHA d493f2a. Root PRs #463 (3f-part1) and #466 (3f-part2) merged 2026-04-20 between 16:41-17:03 UTC. Next after #474 lands: 3g (parity acceptance test) is the merge gate closing the tiered loader track. |
| [support-floor-stops](support-floor-stops.md) | MERGED | — | — | — (PRs #382 primitive + #390 wiring both merged 2026-04-17) |
| [short-side-strategy](short-side-strategy.md) | MERGED | — | — | — (#420 merged 2026-04-19). Follow-ups carried to own tracks: bear-window backtest regression, full short cascade, Ch.11 behavioural spot-check. |
| [strategy-wiring](strategy-wiring.md) | MERGED | — | — | — (#408 + #409 both merged 2026-04-18) |
| [sector-data](sector-data.md) | MERGED | — | — | — (#436 merged 2026-04-19). GHA orchestrator runs continue to consume `trading/test_data/sectors.csv`. |
| [harness](harness.md) | READY_FOR_REVIEW | harness-maintainer | #473 | #473 (T3-F rule promotion path — auto-generate dune checks from declared rules) APPROVED this run (structural). Reviewed SHA c251b3c. PRs #464 (T3-G quality-score) and #467 (T3-J consolidation) merged 2026-04-20. Remaining open after #473 lands: T3-C superseded cleanup, T3-H commit-level QC, T1-N golden scenarios (blocked on data purchase), Tier 4 end-state. |
| [orchestrator-automation](orchestrator-automation.md) | IN_PROGRESS | harness-adjacent | — | Phase 1 live (daily cron runs producing summary PRs). Phase 2 (background execution for scrapers, golden re-runs, cross-feature QC) pending empirical tests per status file. |
| [cleanup](cleanup.md) | IN_PROGRESS | code-health | — | Backlog remains empty (no new medium/high findings from latest deep scan or today's fast-run5). No code-health dispatch this run. |
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
