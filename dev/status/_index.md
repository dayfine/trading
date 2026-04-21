# Status Index

Single-source view of all tracked work. Update when a status file flips
state, an owner changes, or a PR opens / merges / closes. Keep the table
terse; detail belongs in the per-track status files linked in column 1.

Last updated: 2026-04-21 (run-2 reconcile: dispatched harness-maintainer for the scoped POSIX-sh rework of PR #483 per run-1 Question #2 recommendation (a). Rework landed at tip 792b5b09 — 32 LOC across budget_rollup{,_check}.sh (shebang, `set -eu`, array → tmpfile+xargs, `${BASH_SOURCE[0]}` → `repo_root` helper, `<<<` → `< /dev/null`); preserves rollup semantics. qc-structural re-review APPROVED — all 13 items PASS/NA; H3 now green; `bash -n` + `dash -n` clean; smoke-test 8/8 assertions. Behavioral N/A (harness/utility-script, no domain logic). Audit updated APPROVED. Harness row: NEEDS_REWORK → READY_FOR_REVIEW. #484 (backtest-scale 3g) unchanged since run-1 APPROVAL — no re-QC (tip_SHA == Reviewed_SHA). Run-1 summary PR #485 merged to main during this run so run-1 context is visible going forward. ops-data skipped (data-gaps.md unchanged); cleanup skipped (backlog empty). No other eligible tracks. After #483 + #484 land: harness moves to T1-N/T3-H/T4 surface; backtest-scale → 3h nightly A/B (final tiered-loader increment). Prior run-1 reconcile: 8 PRs merged overnight — #473 T3-F rule promotion, #477 Tiered_runner extraction, #478 3f-part3 Friday cycle, #479 qc-rigor P6 + CP* upgrade, #480 live-evidence rule, #481 saturated-queue Step 0.5, #482 qc-structural haiku model, plus run-6 summary #476.)

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
| [harness](harness.md) | READY_FOR_REVIEW | harness-maintainer | #483 | #483 (gha-cost-tracking) APPROVED after POSIX-sh rework — new tip `792b5b09`, 32 LOC diff across `budget_rollup.sh` + `budget_rollup_check.sh` (shebang, `set -eu`, array → tmpfile+xargs, `${BASH_SOURCE[0]}` → `repo_root`, `<<<` → `< /dev/null`). `dash -n` + `bash -n` both clean; smoke-test 8/8 assertions. Behavioral N/A. Mergeable_state "dirty" = docs-file conflict with #485 (resolve at merge). Awaiting human merge. |
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
