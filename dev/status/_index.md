# Status Index

Single-source view of all tracked work. Update when a status file flips
state, an owner changes, or a PR opens / merges / closes. Keep the table
terse; detail belongs in the per-track status files linked in column 1.

Last updated: 2026-04-16

## Active + complete tracks

Each row: one line; deeper task detail in the linked status file.
"Next task" = top-of-queue concrete item from that file's Next Steps.

| Track | Status | Owner | Open PR(s) | Next task |
|---|---|---|---|---|
| [backtest-infra](backtest-infra.md) | READY_FOR_REVIEW | feat-backtest | feat/metrics-unrealized-fix | UnrealizedPnl=0 bug fix + CAGR/annualized-return docstring (follow-up items 1+2). Still blocked on #382 for support-floor experiment |
| [support-floor-stops](support-floor-stops.md) | READY_FOR_REVIEW | feat-weinstein | #382 | Merge #382 (overall_qc APPROVED this run) |
| [short-side-strategy](short-side-strategy.md) | PENDING | — | — | Blocked on PR A of support-floor split (`feat/support-floor-stops`) — primitive widening to long+short |
| [sector-data](sector-data.md) | IN_PROGRESS | ops-data | — | One-shot run of `fetch_finviz_sectors.exe` + filter with updated default.sexp (Item 2) |
| [strategy-wiring](strategy-wiring.md) | MERGED | — | — | — |
| [harness](harness.md) | IN_PROGRESS | harness-maintainer | #383 (T3-G trend analysis) | harness/orchestrator-idempotency (Step 1.5 + structured summary) in progress; T3-F architecture graph analyzer next |
| [orchestrator-automation](orchestrator-automation.md) | IN_PROGRESS | harness-adjacent | — | Solve open blockers (BOT_GITHUB_TOKEN + CLAUDE_CODE_OAUTH_TOKEN setup; gh/jj availability in container) |
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
