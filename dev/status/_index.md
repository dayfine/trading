# Status Index

Single-source view of all tracked work. Update when a status file flips
state, an owner changes, or a PR opens / merges / closes. Keep the table
terse; detail belongs in the per-track status files linked in column 1.

Last updated: 2026-04-20 (run-1 reconcile: since run-5 — #451, #452, #453, #454, #455, #456 all merged; #457 cleanup baseline-linters merged this run; #458 harness drift-coverage extension dispatched + QC APPROVED; #459 backtest-scale 3e dispatched + QC APPROVED quality 5)

## Active + complete tracks

Each row: one line; deeper task detail in the linked status file.
"Next task" = top-of-queue concrete item from that file's Next Steps.

| Track | Status | Owner | Open PR(s) | Next task |
|---|---|---|---|---|
| [backtest-infra](backtest-infra.md) | MERGED | — | — | — (#419 per-phase tracing merged 2026-04-19) |
| [backtest-scale](backtest-scale.md) | READY_FOR_REVIEW | feat-backtest | #459 | #452 (3d tracer phases) merged 2026-04-19. #459 (3e — runner + scenario `loader_strategy` plumbing, ~218 LOC) dispatched run-1, structural + behavioral QC APPROVED (quality 5). Note: PR #459 has a merge conflict with PR #457 (both touch `runner.ml`'s `run_backtest`); rebase one or the other before merging. Next after #459 lands: 3f (tiered runner path skeleton, architecturally largest increment). |
| [support-floor-stops](support-floor-stops.md) | MERGED | — | — | — (PRs #382 primitive + #390 wiring both merged 2026-04-17) |
| [short-side-strategy](short-side-strategy.md) | MERGED | — | — | — (#420 merged 2026-04-19). Follow-ups carried to own tracks: bear-window backtest regression, full short cascade, Ch.11 behavioural spot-check. |
| [strategy-wiring](strategy-wiring.md) | MERGED | — | — | — (#408 + #409 both merged 2026-04-18) |
| [sector-data](sector-data.md) | MERGED | — | — | — (#436 merged 2026-04-19). GHA orchestrator runs continue to consume `trading/test_data/sectors.csv`. |
| [harness](harness.md) | READY_FOR_REVIEW | harness-maintainer | #458 | #451 + #454 merged 2026-04-19/20. #458 (deep-scan drift coverage extension to `trading/trading/backtest/`; closes Follow-up sub-item 1) dispatched run-1, qc-structural APPROVED. Remaining open: advisory T3 items (T3-C, T3-F rule-promotion, T3-G audit-trail quality score, T3-H commit-level QC) + Tier 4 end-state. |
| [orchestrator-automation](orchestrator-automation.md) | IN_PROGRESS | harness-adjacent | — | Phase 1 live (daily cron runs producing summary PRs). Phase 2 (background execution for scrapers, golden re-runs, cross-feature QC) pending empirical tests per status file. |
| [cleanup](cleanup.md) | IN_PROGRESS | code-health | — | #453 merged 2026-04-19. #457 (orchestrator-authored, not code-health: clear baseline-red `magic_numbers` + `fn_length` linters in `trace.ml`, `weinstein_strategy.ml`, `runner.ml` — no behaviour change) merged this run. Backlog now: pre-existing nesting_linter failures in `analysis/scripts/universe_filter` + `analysis/scripts/fetch_finviz_sectors` (deferred to a code-health pass; well-scoped) + a new fn_length on `run_backtest` introduced by 3e (will reappear on the linter once #459 lands). |
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
