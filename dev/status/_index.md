# Status Index

Single-source view of all tracked work. Update when a status file flips
state, an owner changes, or a PR opens / merges / closes. Keep the table
terse; detail belongs in the per-track status files linked in column 1.

Last updated: 2026-04-21 (run-1 reconcile: 8 PRs merged overnight — #473 T3-F rule promotion, #477 Tiered_runner extraction, #478 3f-part3 Friday cycle, #479 qc-rigor P6 + CP* upgrade, #480 live-evidence rule, #481 saturated-queue Step 0.5, #482 qc-structural model haiku, plus run-6 summary #476. Dispatched backtest-scale 3g (fresh work on unblocked plan) → PR #484 APPROVED structural + behavioral (Quality Score 3) this run. Dispatched qc-structural on harness gha-cost-tracking (PR #483, tip d1ba14a3) → NEEDS_REWORK due to POSIX-sh violations in new budget_rollup{,_check}.sh scripts; behavioral skipped per Step 5 policy. Harness track flipped IN_PROGRESS → NEEDS_REWORK on #483. backtest-scale remains READY_FOR_REVIEW, now on PR #484 (3f-part3 landed; 3g is the merge gate closing the tiered-loader track). ops-data skipped — data-gaps.md unchanged since 2026-04-14. cleanup backlog empty — no code-health dispatch. M5 acceptance gate becomes live once #484 merges.)

## Active + complete tracks

Each row: one line; deeper task detail in the linked status file.
"Next task" = top-of-queue concrete item from that file's Next Steps.

| Track | Status | Owner | Open PR(s) | Next task |
|---|---|---|---|---|
| [backtest-infra](backtest-infra.md) | MERGED | — | — | — (#419 per-phase tracing merged 2026-04-19) |
| [backtest-scale](backtest-scale.md) | READY_FOR_REVIEW | feat-backtest | #484 | #484 (3g parity acceptance test — merge gate closing tiered loader track) APPROVED this run — structural + behavioral both green (Quality Score 3; F1/F2 observability flags non-blocking, see dev/reviews/backtest-scale.md §3g). Reviewed SHA 6d69081. Prior #474 (3f-part3) merged overnight. After #484 lands: 3h (nightly A/B comparison) follows, closing the M5 track. |
| [support-floor-stops](support-floor-stops.md) | MERGED | — | — | — (PRs #382 primitive + #390 wiring both merged 2026-04-17) |
| [short-side-strategy](short-side-strategy.md) | MERGED | — | — | — (#420 merged 2026-04-19). Follow-ups carried to own tracks: bear-window backtest regression, full short cascade, Ch.11 behavioural spot-check. |
| [strategy-wiring](strategy-wiring.md) | MERGED | — | — | — (#408 + #409 both merged 2026-04-18) |
| [sector-data](sector-data.md) | MERGED | — | — | — (#436 merged 2026-04-19). GHA orchestrator runs continue to consume `trading/test_data/sectors.csv`. |
| [harness](harness.md) | NEEDS_REWORK | harness-maintainer | #483 | #483 (gha-cost-tracking) NEEDS_REWORK — bash-only syntax (`#!/usr/bin/env bash`, `set -euo pipefail`, `${BASH_SOURCE[0]}`, `<<<`, `[[ ]]`, arrays) in `budget_rollup{,_check}.sh` which dune invokes with `/bin/sh`. Reviewed SHA d1ba14a3. Fix: rewrite both scripts to POSIX sh. Prior T3-F (#473), live-evidence rule (#480), saturated-queue (#481), qc-structural haiku model (#482) all merged overnight. |
| [orchestrator-automation](orchestrator-automation.md) | IN_PROGRESS | harness-adjacent | — | Phase 1 live (daily cron runs producing summary PRs). Phase 2 (background execution for scrapers, golden re-runs, cross-feature QC) pending empirical tests per status file. |
| [cleanup](cleanup.md) | IN_PROGRESS | code-health | — | Backlog remains empty (no new medium/high findings from latest deep scan). No code-health dispatch this run. |
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
