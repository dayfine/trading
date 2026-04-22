# Status Index

Single-source view of all tracked work. Update when a status file flips
state, an owner changes, or a PR opens / merges / closes. Keep the table
terse; detail belongs in the per-track status files linked in column 1.

Last updated: 2026-04-21 (manual reconcile post-merge wave: #473 T3-F rule promotion, #480 live-evidence rule, #482 qc-structural → Haiku, #483 gha-cost-tracking, #484 3g parity, #488 orchestrator self-sabotage fixes, #490 consolidated-summary exclusion — all merged 2026-04-21. Tiered-loader track's 3a→3g shipped. Remaining Tiered-track work: F2 closure (`Summary_compute` returns `None` for every universe symbol on every Friday — Tiered stays observationally inert on the parity scenario) and 3h (nightly A/B comparison). F1 (test tolerance) non-blocking. Main baseline green. Review queue empty.)

## Active + complete tracks

Each row: one line; deeper task detail in the linked status file.
"Next task" = top-of-queue concrete item from that file's Next Steps.

| Track | Status | Owner | Open PR(s) | Next task |
|---|---|---|---|---|
| [backtest-infra](backtest-infra.md) | MERGED | — | — | — (#419 per-phase tracing merged 2026-04-19) |
| [backtest-scale](backtest-scale.md) | IN_PROGRESS | feat-backtest | — | Tiered-loader track 3a→3g shipped (#484 merged 2026-04-21 including F2 partial fix `benchmark_symbol=GSPC.INDX`). Next: F2 full closure — debug why `Summary_compute.compute_values` returns `None` for every universe symbol on every Friday (one of `ma_30w` / `atr_14` / `rs_line` / `stage_heuristic`), then real-data fixtures to replace synthetic 100.00+drift macro CSVs so parity is non-trivial. After F2: 3h (nightly A/B comparison), then flip Tiered to default closing the M5 track. |
| [support-floor-stops](support-floor-stops.md) | MERGED | — | — | — (PRs #382 primitive + #390 wiring both merged 2026-04-17) |
| [short-side-strategy](short-side-strategy.md) | MERGED | — | — | — (#420 merged 2026-04-19). Follow-ups carried to own tracks: bear-window backtest regression, full short cascade, Ch.11 behavioural spot-check. |
| [strategy-wiring](strategy-wiring.md) | MERGED | — | — | — (#408 + #409 both merged 2026-04-18) |
| [sector-data](sector-data.md) | MERGED | — | — | — (#436 merged 2026-04-19). GHA orchestrator runs continue to consume `trading/test_data/sectors.csv`. |
| [harness](harness.md) | IN_PROGRESS | harness-maintainer | — | Recent wave merged 2026-04-21: #473 (T3-F rule promotion), #480 (live-evidence rule for [critical] escalations + stale nesting follow-up cleared), #482 (qc-structural → Haiku), #483 (gha-cost-tracking — measurement active), #488 (orchestrator self-sabotage fixes: Step 0.5 Condition 2 exempts own summary, [critical] tag correction, QC worktree-isolation via `git checkout --detach`), #490 (consolidated-summary scan exclusion). No open PRs. Next passive: observe upcoming GHA runs for Step 0.5 fast-exit, measured cost data, cross-track drift. |
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
