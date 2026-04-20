# Status Index

Single-source view of all tracked work. Update when a status file flips
state, an owner changes, or a PR opens / merges / closes. Keep the table
terse; detail belongs in the per-track status files linked in column 1.

Last updated: 2026-04-19 (run-5 reconcile: #447 3c Full tier, #448 retire inline fast scan, #449 run-4 summary, #450 draft→ready flip all merged since run-4; #451 harness weekly-deep-scan-cron, #452 backtest-scale 3d tracer phases (QC APPROVED), #453 cleanup weinstein_strategy @large-module all dispatched this run)

## Active + complete tracks

Each row: one line; deeper task detail in the linked status file.
"Next task" = top-of-queue concrete item from that file's Next Steps.

| Track | Status | Owner | Open PR(s) | Next task |
|---|---|---|---|---|
| [backtest-infra](backtest-infra.md) | MERGED | — | — | — (#419 per-phase tracing merged 2026-04-19) |
| [backtest-scale](backtest-scale.md) | READY_FOR_REVIEW | feat-backtest | #452 | #447 (3c Full tier) merged 2026-04-19. #452 (3d tracer phases) dispatched run-5, structural + behavioral QC APPROVED (quality 5). Next: 3e (runner + scenario `loader_strategy` plumbing, ~150 LOC) after #452 lands. |
| [support-floor-stops](support-floor-stops.md) | MERGED | — | — | — (PRs #382 primitive + #390 wiring both merged 2026-04-17) |
| [short-side-strategy](short-side-strategy.md) | MERGED | — | — | — (#420 merged 2026-04-19). Follow-ups carried to own tracks: bear-window backtest regression, full short cascade, Ch.11 behavioural spot-check. |
| [strategy-wiring](strategy-wiring.md) | MERGED | — | — | — (#408 + #409 both merged 2026-04-18) |
| [sector-data](sector-data.md) | MERGED | — | — | — (#436 merged 2026-04-19). GHA orchestrator runs continue to consume `trading/test_data/sectors.csv`. |
| [harness](harness.md) | READY_FOR_REVIEW | harness-maintainer | #451 | #448 (T3-A+ sub-item 2) merged 2026-04-19. #451 (T3-A+ sub-item 1: weekly GHA cron `.github/workflows/health-deep-weekly.yml` dispatching `health-scanner` in deep mode on Mondays 15:17 UTC; PR opens advisory, no auto-merge) dispatched run-5. After #451 lands: remaining open T3 items are advisory (T3-C, T3-F rule-promotion, T3-G audit-trail quality score, T3-H commit-level QC) + Tier 4 end-state. |
| [orchestrator-automation](orchestrator-automation.md) | IN_PROGRESS | harness-adjacent | — | Phase 1 live (daily cron runs producing summary PRs). Phase 2 (background execution for scrapers, golden re-runs, cross-feature QC) pending empirical tests per status file. |
| [cleanup](cleanup.md) | IN_PROGRESS | code-health | #453 | #453 (annotate `weinstein_strategy.ml` as `@large-module` — 320 lines → 324 lines with annotation; file-length linter now OK) dispatched run-5. Backlog empty after this PR merges; next run will re-scan fast-health for a new finding. |
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
