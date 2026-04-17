# Status Index

Single-source view of all tracked work. Update when a status file flips
state, an owner changes, or a PR opens / merges / closes. Keep the table
terse; detail belongs in the per-track status files linked in column 1.

Last updated: 2026-04-17 (orchestrator run 1)

## Active + complete tracks

Each row: one line; deeper task detail in the linked status file.
"Next task" = top-of-queue concrete item from that file's Next Steps.

| Track | Status | Owner | Open PR(s) | Next task |
|---|---|---|---|---|
| [backtest-infra](backtest-infra.md) | READY_FOR_REVIEW | feat-backtest | #399 (feat/backtest-scenario-small-universe) | Step 2 — per-phase tracing (`dev/plans/backtest-scale-optimization-2026-04-17.md`) |
| [backtest-scale](backtest-scale.md) | PENDING | feat-backtest | — | Blocked on step 2 tracing under backtest-infra. Target: tier-aware bar loader (Metadata/Summary/Full) |
| [support-floor-stops](support-floor-stops.md) | MERGED | — | — | — (PRs #382 primitive + #390 wiring both merged 2026-04-17) |
| [short-side-strategy](short-side-strategy.md) | PENDING | — | — | Unblocked (PR A #382 merged); candidate owner `feat-weinstein` — wire screener candidate `side` + bearish-macro short branch |
| [sector-data](sector-data.md) | IN_PROGRESS | ops-data | — | One-shot run of `fetch_finviz_sectors.exe` + filter with updated default.sexp (Item 2) |
| [strategy-wiring](strategy-wiring.md) | MERGED | — | — | — |
| [harness](harness.md) | IN_PROGRESS | harness-maintainer | — | Fix `dev/lib/run-in-env.sh` GHA path bug (see 2026-04-17 Escalations); then T3-F architecture graph analyzer or deep-scan heuristic gap sub-item 2 |
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
