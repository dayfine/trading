# Status Index

Single-source view of all tracked work. Update when a status file flips
state, an owner changes, or a PR opens / merges / closes. Keep the table
terse; detail belongs in the per-track status files linked in column 1.

Last updated: 2026-04-20 (run-2 reconcile: #458, #459, #460, #461, #462 all merged since run-1. New dispatches this run: #463 backtest-scale 3f-part1 shadow_screener adapter — overall_qc APPROVED (structural + behavioral quality 4/5) after one rework cycle on P6; #464 harness T3-G audit quality-score wiring — qc-structural APPROVED, behavioral N/A. Both awaiting human merge.)

## Active + complete tracks

Each row: one line; deeper task detail in the linked status file.
"Next task" = top-of-queue concrete item from that file's Next Steps.

| Track | Status | Owner | Open PR(s) | Next task |
|---|---|---|---|---|
| [backtest-infra](backtest-infra.md) | MERGED | — | — | — (#419 per-phase tracing merged 2026-04-19) |
| [backtest-scale](backtest-scale.md) | READY_FOR_REVIEW | feat-backtest | #463 | #459 (3e) + #462 (3e runner date-token fix) merged 2026-04-20. #463 (3f-part1 shadow_screener adapter, ~300 LOC inc. tests) dispatched run-2, structural + behavioral QC APPROVED (quality 4/5) after one P6 rework cycle on test composition. Next after #463 lands: 3f-part2 — runner integration (`_run_tiered_backtest` + flag branching in `run_backtest`), consuming the `Shadow_screener.screen` entry point this PR adds. Then 3g is the merge gate. |
| [support-floor-stops](support-floor-stops.md) | MERGED | — | — | — (PRs #382 primitive + #390 wiring both merged 2026-04-17) |
| [short-side-strategy](short-side-strategy.md) | MERGED | — | — | — (#420 merged 2026-04-19). Follow-ups carried to own tracks: bear-window backtest regression, full short cascade, Ch.11 behavioural spot-check. |
| [strategy-wiring](strategy-wiring.md) | MERGED | — | — | — (#408 + #409 both merged 2026-04-18) |
| [sector-data](sector-data.md) | MERGED | — | — | — (#436 merged 2026-04-19). GHA orchestrator runs continue to consume `trading/test_data/sectors.csv`. |
| [harness](harness.md) | READY_FOR_REVIEW | harness-maintainer | #464 | #458 + #461 merged 2026-04-20. #464 (T3-G — audit trail quality-score wiring via new `record_qc_audit.sh` + Step 5 Stage 4 in lead-orchestrator.md + qc-behavioral output contract) dispatched run-2, qc-structural APPROVED, behavioral N/A. Remaining open: advisory T3 items (T3-C, T3-F rule-promotion, T3-H commit-level QC) + Tier 4 end-state. |
| [orchestrator-automation](orchestrator-automation.md) | IN_PROGRESS | harness-adjacent | — | Phase 1 live (daily cron runs producing summary PRs). Phase 2 (background execution for scrapers, golden re-runs, cross-feature QC) pending empirical tests per status file. |
| [cleanup](cleanup.md) | IN_PROGRESS | code-health | — | #453 + #457 + #461 (baseline nesting-linter cleanup, orchestrator-authored) merged 2026-04-20. Backlog currently empty — run-2 deep scan shows 0 critical, 5 warnings (all low-severity: design doc drift, followup accumulation at 18, milestone-pinned linter exceptions unknown). No code-health dispatch this run. |
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
