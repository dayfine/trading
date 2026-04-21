# Status Index

Single-source view of all tracked work. Update when a status file flips
state, an owner changes, or a PR opens / merges / closes. Keep the table
terse; detail belongs in the per-track status files linked in column 1.

Last updated: 2026-04-21 (run-4 reconcile: re-QC on both open PRs after new commits landed. #484 (backtest-scale 3g) received one review-follow-up commit `db925c5a` threading `benchmark_symbol=GSPC.INDX` into the Tiered `Bar_loader` (F2 partial fix) — re-APPROVED (structural + behavioral, Quality Score 3). New Reviewed SHA `db925c5a`. F2 narrowed: benchmark-symbol divergence fixed, but `Summary_compute` still emits `None` for every universe symbol on every Friday so Tiered remains observationally inert on the parity scenario — G5 FLAG downgraded, not resolved; gate before Tiered default-flip. #483 (harness gha-cost-tracking) force-pushed to rebase onto post-#487 main; re-APPROVED (structural, Quality Score 4; behavioral N/A). New Reviewed SHA `a3075010d3a0`. POSIX-sh fixes from prior `792b5b09` all intact. `dash -n` + `bash -n` clean on both scripts. ops-data skipped (data-gaps.md unchanged since 2026-04-14); cleanup skipped (backlog empty). No other eligible tracks. Main baseline green (`dune build` + `dune runtest` exit 0 on tip `3ecff21` post-#488-merge). Prior run-3 reconcile context retained in the run-3 summary file.)

## Active + complete tracks

Each row: one line; deeper task detail in the linked status file.
"Next task" = top-of-queue concrete item from that file's Next Steps.

| Track | Status | Owner | Open PR(s) | Next task |
|---|---|---|---|---|
| [backtest-infra](backtest-infra.md) | MERGED | — | — | — (#419 per-phase tracing merged 2026-04-19) |
| [backtest-scale](backtest-scale.md) | READY_FOR_REVIEW | feat-backtest | #484 | #484 (3g parity acceptance test — merge gate closing tiered loader track). Re-APPROVED run-4 after review-follow-up commit `db925c5a` threaded `benchmark_symbol=GSPC.INDX` into the Tiered `Bar_loader` (F2 partial fix): structural + behavioral both green (Quality Score 3). Reviewed SHA `db925c5a4c56`. F1 (test tolerance) unchanged. G5/F2 FLAG narrowed but still present: `Summary_compute` returns `None` for every universe symbol on every Friday, so Tiered remains observationally inert on the parity scenario — gate before flipping Tiered to default. After #484 lands: 3h (nightly A/B comparison) follows, closing the M5 track. |
| [support-floor-stops](support-floor-stops.md) | MERGED | — | — | — (PRs #382 primitive + #390 wiring both merged 2026-04-17) |
| [short-side-strategy](short-side-strategy.md) | MERGED | — | — | — (#420 merged 2026-04-19). Follow-ups carried to own tracks: bear-window backtest regression, full short cascade, Ch.11 behavioural spot-check. |
| [strategy-wiring](strategy-wiring.md) | MERGED | — | — | — (#408 + #409 both merged 2026-04-18) |
| [sector-data](sector-data.md) | MERGED | — | — | — (#436 merged 2026-04-19). GHA orchestrator runs continue to consume `trading/test_data/sectors.csv`. |
| [harness](harness.md) | READY_FOR_REVIEW | harness-maintainer | #483 | #483 (gha-cost-tracking) re-APPROVED run-4 after force-push rebase onto post-#487 main — new tip `a3075010d3a0`, 10 files / +742/-7 vs main (budget_rollup.sh + budget_rollup_check.sh POSIX-sh fixes from prior `792b5b09` all intact). Structural APPROVED (Quality Score 4); behavioral N/A (utility scripts, no domain logic). `dash -n` + `bash -n` clean on both scripts; all hard gates pass. Awaiting human merge. |
| [orchestrator-automation](orchestrator-automation.md) | IN_PROGRESS | harness-adjacent | — | Phase 1 live (daily cron runs producing summary PRs). Phase 2 (background execution for scrapers, golden re-runs, cross-feature QC) pending empirical tests per status file. |
| [cleanup](cleanup.md) | IN_PROGRESS | code-health | — | Backlog remains empty (no new medium/high findings from latest deep scan or today's fast-run5). No code-health dispatch this run. |
| [cost-tracking](cost-tracking.md) | IN_PROGRESS | harness-maintainer | — | GHA cost capture step + budget_rollup.sh landed (harness/gha-cost-tracking). Next: verify measured total_cost_usd on next GHA run; compare costs pre/post #481/#482. |
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
