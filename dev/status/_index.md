# Status Index

Single-source view of all tracked work. Update when a status file flips
state, an owner changes, or a PR opens / merges / closes. Keep the table
terse; detail belongs in the per-track status files linked in column 1.

Last updated: 2026-04-25 (Stage 2 of `data-panels` columnar redesign foundation work landed on `feat/panels-stage02-no-bar-history`: `Bar_panels` reader module (daily/weekly bar reconstruction from `Ohlcv_panels` + zero-copy `low_window` for support-floor) + `adjusted_close` panel added to `Ohlcv_panels` (Stage 0/1 omission — without it, panel-reconstructed `Daily_price.t` records would silently diverge in indicator math for stocks with dividends or splits). 14 new tests pass; full repo `dune runtest` green. Six-reader-site migration + Bar_history deletion + Tiered_runner panel build + strengthened parity gate are remaining work — scope re-estimated at ~1500 LOC, not the 400 LOC the plan §Stage 2 row claims. Stage 2 status flipped to IN_PROGRESS.)

## Active + complete tracks

Each row: one line; deeper task detail in the linked status file.
"Next task" = top-of-queue concrete item from that file's Next Steps.

| Track | Status | Owner | Open PR(s) | Next task |
|---|---|---|---|---|
| [backtest-infra](backtest-infra.md) | MERGED | — | — | — Steps 1 (#399) + 2 (#419) landed earlier. Sweep harness extension #547 landed 2026-04-25. Continuous monitoring + release-gate scope moved to `backtest-perf` track; Tier-3-architecture follow-on now tracked at `data-panels` (supersedes `incremental-indicators`). |
| [backtest-scale](backtest-scale.md) | READY_FOR_REVIEW | feat-backtest | — | #517 + #519 closed the post-#507 A/B parity gaps. Verified on GHA `tiered-loader-ab` (run 24870169890). 5 hypothesis tests against the residual +95% Tiered RSS gap (H1 trim, H2 cap, H3 skip-AD, H7 stream-CSV, GC tuning, List.filter refactor #548) — all disproved. Diagnosis: heap-doesn't-shrink + structural ~2× ratio from post-#519 promote-all design. Memory work continues on the new `data-panels` track (columnar redesign, plan #554). 7-symbol CI fixture rebuild + Tiered flip default still open follow-ups (latter likely moot once data-panels lands). |
| [backtest-perf](backtest-perf.md) | PENDING | feat-backtest | #550 (catalog + release-gate plan) | Continuous perf coverage in CI + release-gate strategy. 4-tier scenario catalog (per-PR / nightly / weekly / release). Tier 4 (5000-stock decade-long release-gate) blocked on `data-panels` stages 0-3 landing. |
| [data-panels](data-panels.md) | IN_PROGRESS (Stage 2 foundation only) | feat-backtest | feat/panels-stage02-no-bar-history | Columnar data-shape redesign: replace per-symbol Hashtbl-of-bars with Bigarray panels (N × T per OHLCV field + per indicator). 5 stages. **Stage 0 (#555) and Stage 1 (#557) MERGED 2026-04-25**. **Stage 2 in progress** on this branch: foundation committed (`Bar_panels` reader module — daily/weekly bar reconstruction from Ohlcv_panels + zero-copy `low_window` slice for support-floor — plus a missing `adjusted_close` panel added to `Ohlcv_panels` + 14 new tests). The 6-reader-site migration + Bar_history deletion + Tiered_runner panel build + parity-gate strengthening are deferred to follow-up sessions: scope re-estimated at ~1500 LOC, not the 400 LOC the plan §Stage 2 row claims. The discrepancy: every reader site consumes `Daily_price.t list` and the callees (`Stage.classify`, `Sector.analyze`, `Macro.analyze`, `Stock_analysis.analyze`, `Weinstein_stops.compute_initial_stop_with_floor`) recompute MA internally from the bar list — replacing list reads with single-value MA reads requires reshaping all of those callees, which crosses into Stage 4 territory. Pragmatic Stage 2 path (now committed): back the bar lists with on-the-fly panel reconstruction via `Bar_panels`, eliminating the parallel `Bar_history` cache (the +95% Tiered RSS gap source) without touching the callees. |
| [support-floor-stops](support-floor-stops.md) | MERGED | — | — | — (PRs #382 primitive + #390 wiring both merged 2026-04-17) |
| [short-side-strategy](short-side-strategy.md) | MERGED | — | — | — (#420 merged 2026-04-19). Follow-ups carried to own tracks: bear-window backtest regression, full short cascade, Ch.11 behavioural spot-check. |
| [strategy-wiring](strategy-wiring.md) | MERGED | — | — | — (#408 + #409 both merged 2026-04-18) |
| [sector-data](sector-data.md) | MERGED | — | — | — (#436 merged 2026-04-19). GHA orchestrator runs continue to consume `trading/test_data/sectors.csv`. |
| [harness](harness.md) | IN_PROGRESS | harness-maintainer | — | No open harness PR. Recent merges: #493 POSIX-sh linter, #495 cost-capture new-day fix, #499 cost-capture commit+auto-merge, #504 budget PR creation via curl, #505 budget rescue (all 2026-04-22). Backlog remains saturated — T1 done; T2 milestone-gated; T3-C superseded; T3-H low-priority. Recurring status-file integrity drift from human-merged PRs is a [info] follow-up — linter already exits 1 on violation; requires branch-protection config to enforce. |
| [orchestrator-automation](orchestrator-automation.md) | IN_PROGRESS | harness-adjacent | — | Phase 1 live (daily cron runs producing summary PRs). Phase 2 (background execution for scrapers, golden re-runs, cross-feature QC) pending empirical tests per status file. |
| [cleanup](cleanup.md) | IN_PROGRESS | code-health | — | Backlog remains empty (no new medium/high findings from latest deep scan or today's fast health check). No code-health dispatch this run. |
| [cost-tracking](cost-tracking.md) | IN_PROGRESS | harness-maintainer | — | GHA cost capture step landed (#483). Cost-capture new-day bug fixed via #495 + #499 (both 2026-04-22). Next: verify measured `total_cost_usd` now lands correctly on this run's `dev/budget/2026-04-22-run3.json`; compare costs pre/post #481/#482/#495/#499. |
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
