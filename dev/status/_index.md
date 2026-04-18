# Status Index

Single-source view of all tracked work. Update when a status file flips
state, an owner changes, or a PR opens / merges / closes. Keep the table
terse; detail belongs in the per-track status files linked in column 1.

Last updated: 2026-04-18 (orchestrator run 3)

## Active + complete tracks

Each row: one line; deeper task detail in the linked status file.
"Next task" = top-of-queue concrete item from that file's Next Steps.

| Track | Status | Owner | Open PR(s) | Next task |
|---|---|---|---|---|
| [backtest-infra](backtest-infra.md) | APPROVED | feat-backtest | #419 (feat/backtest-phase-tracing) | QC APPROVED (structural + behavioral, quality 5) — awaiting human merge. Then Step 3 tier-aware bar loader (backtest-scale track). |
| [backtest-scale](backtest-scale.md) | PENDING | feat-backtest | — | Unblocked once #419 merges; start Step 3 tier-aware bar loader on `feat/backtest-tiered-loader`. |
| [support-floor-stops](support-floor-stops.md) | MERGED | — | — | — (PRs #382 primitive + #390 wiring both merged 2026-04-17) |
| [short-side-strategy](short-side-strategy.md) | APPROVED | feat-weinstein | #420 (feat/short-side-strategy) | QC APPROVED (structural + behavioral, quality 5) — awaiting human merge. Follow-ups: bear-window backtest regression, full short cascade, Ch.11 behavioural spot-check. |
| [strategy-wiring](strategy-wiring.md) | MERGED | — | — | — (#408 + #409 both merged 2026-04-18) |
| [sector-data](sector-data.md) | IN_PROGRESS | ops-data | — | Item 2 (one-shot `fetch_finviz_sectors.exe` + filter with updated default.sexp) — requires 2.2h human-driven fetch |
| [harness](harness.md) | IN_PROGRESS | harness-maintainer | #421 (harness/deep-scan-recent-commits-guard) | Deep-scan Recent Commits guard (Check 10 + smoke test) — awaiting review. Next: deep-scan heuristic gaps sub-items 3 (linter exception expiry vs milestone) and 4 (stale local jj bookmarks). |
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
