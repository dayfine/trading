# Status Index

Single-source view of all tracked work. Update when a status file flips
state, an owner changes, or a PR opens / merges / closes. Keep the table
terse; detail belongs in the per-track status files linked in column 1.

Last updated: 2026-04-22 run-2 (orchestrator reconcile post-dispatch: PR #492 F2 tail_days fix merged at 01:04Z; PR #493 POSIX-sh linter merged at 01:04Z; PR #495 cost-capture new-day fix merged at 01:46Z (human-driven CI fix). This run dispatched feat-backtest on 3h nightly A/B trace comparison — PR #496 open, QC APPROVED (structural + behavioral, quality 5/5), awaiting human merge. Main baseline green.)

## Active + complete tracks

Each row: one line; deeper task detail in the linked status file.
"Next task" = top-of-queue concrete item from that file's Next Steps.

| Track | Status | Owner | Open PR(s) | Next task |
|---|---|---|---|---|
| [backtest-infra](backtest-infra.md) | MERGED | — | — | — (#419 per-phase tracing merged 2026-04-19) |
| [backtest-scale](backtest-scale.md) | IN_PROGRESS | feat-backtest | #496 | PR #496 awaiting-merge — 3h nightly A/B trace comparison (GHA workflow + POSIX-sh compare script; workflow staged in `dev/ci-staging/` pending human `git mv` at merge due to bot token lacking `workflow` scope). 3g parity test (#484) and F2 tail_days fix (#492) both merged 2026-04-22. Post-merge: human activates workflow via 1-line `git mv`; then flip `loader_strategy` default Legacy→Tiered; then retire Legacy codepath. |
| [support-floor-stops](support-floor-stops.md) | MERGED | — | — | — (PRs #382 primitive + #390 wiring both merged 2026-04-17) |
| [short-side-strategy](short-side-strategy.md) | MERGED | — | — | — (#420 merged 2026-04-19). Follow-ups carried to own tracks: bear-window backtest regression, full short cascade, Ch.11 behavioural spot-check. |
| [strategy-wiring](strategy-wiring.md) | MERGED | — | — | — (#408 + #409 both merged 2026-04-18) |
| [sector-data](sector-data.md) | MERGED | — | — | — (#436 merged 2026-04-19). GHA orchestrator runs continue to consume `trading/test_data/sectors.csv`. |
| [harness](harness.md) | IN_PROGRESS | harness-maintainer | — | No open harness PR. Recent merges: #493 POSIX-sh linter (today), #495 cost-capture new-day fix (today, human). Backlog remains saturated — T1 done; T2 milestone-gated; T3-C superseded; T3-H low-priority. Stale follow-up `.claude/worktrees/` already resolved (present in `.gitignore` line 49). |
| [orchestrator-automation](orchestrator-automation.md) | IN_PROGRESS | harness-adjacent | — | Phase 1 live (daily cron runs producing summary PRs). Phase 2 (background execution for scrapers, golden re-runs, cross-feature QC) pending empirical tests per status file. |
| [cleanup](cleanup.md) | IN_PROGRESS | code-health | — | Backlog remains empty (no new medium/high findings from latest deep scan or today's fast health check). No code-health dispatch this run. |
| [cost-tracking](cost-tracking.md) | IN_PROGRESS | harness-maintainer | — | GHA cost capture step landed (#483). Cost-capture new-day bug fixed today via #495 (human-driven). Next: verify measured `total_cost_usd` on next full-pass GHA run; compare costs pre/post #481/#482/#495. |
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
