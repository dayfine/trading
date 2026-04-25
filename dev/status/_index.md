# Status Index

Single-source view of all tracked work. Update when a status file flips
state, an owner changes, or a PR opens / merges / closes. Keep the table
terse; detail belongs in the per-track status files linked in column 1.

Last updated: 2026-04-25 (Stage 2 PR-H of `data-panels` opens on `feat/panels-stage02-pr-h-final`: `Bar_reader` abstraction + reader-site swap point + parity test. Introduces `Bar_reader.t` — a thin closure-bundle hiding the choice between `Bar_history` (parallel Hashtbl cache) and `Bar_panels` (panel-backed reads). Ports the 6 reader sites (macro_inputs ×2, stops_runner ×1, weinstein_strategy ×3) to `Bar_reader`. `Weinstein_strategy.make` gains `?bar_panels:Bar_panels.t` taking precedence over `?bar_history` when both supplied. New `test_bar_reader_parity` (5 tests) feeds identical bars through both backends and asserts bit-identical bar-list outputs from `daily_bars_for` / `weekly_bars_for`. PR-G (Weinstein_stops support floor reshape) READY_FOR_REVIEW on `feat/panels-stage02-pr-g-stops-support-floor`. PR-H is the eighth and final PR in the Stage 2 sequence; Bar_history deletion + the runner-level swap deferred to a Stage 3 PR because the Tiered cycle's incremental Friday seeding diverges structurally from Bar_panels' upfront-load shape.)

## Active + complete tracks

Each row: one line; deeper task detail in the linked status file.
"Next task" = top-of-queue concrete item from that file's Next Steps.

| Track | Status | Owner | Open PR(s) | Next task |
|---|---|---|---|---|
| [backtest-infra](backtest-infra.md) | MERGED | — | — | — Steps 1 (#399) + 2 (#419) landed earlier. Sweep harness extension #547 landed 2026-04-25. Continuous monitoring + release-gate scope moved to `backtest-perf` track; Tier-3-architecture follow-on now tracked at `data-panels` (supersedes `incremental-indicators`). |
| [backtest-scale](backtest-scale.md) | READY_FOR_REVIEW | feat-backtest | — | #517 + #519 closed the post-#507 A/B parity gaps. Verified on GHA `tiered-loader-ab` (run 24870169890). 5 hypothesis tests against the residual +95% Tiered RSS gap (H1 trim, H2 cap, H3 skip-AD, H7 stream-CSV, GC tuning, List.filter refactor #548) — all disproved. Diagnosis: heap-doesn't-shrink + structural ~2× ratio from post-#519 promote-all design. Memory work continues on the new `data-panels` track (columnar redesign, plan #554). 7-symbol CI fixture rebuild + Tiered flip default still open follow-ups (latter likely moot once data-panels lands). |
| [backtest-perf](backtest-perf.md) | PENDING | feat-backtest | #550 (catalog + release-gate plan) | Continuous perf coverage in CI + release-gate strategy. 4-tier scenario catalog (per-PR / nightly / weekly / release). Tier 4 (5000-stock decade-long release-gate) blocked on `data-panels` stages 0-3 landing. |
| [data-panels](data-panels.md) | IN_PROGRESS (Stage 2 PR-H — final in 8-PR sequence) | feat-backtest | #564 (PR-G), feat/panels-stage02-pr-h-final (PR-H new) | Columnar data-shape redesign. Stages 0-1 + Stage 2 foundation merged (#555, #557, #558). PR-B (`Stage.classify`) #559, PR-C (`Rs.analyze`) #560, PR-D (`Stock_analysis.analyze`) #561, PR-E (`Sector.analyze`) #562, PR-F (`Macro.analyze`) #563 — all merged. PR-G (`Weinstein_stops.compute_initial_stop_with_floor`) #564 READY_FOR_REVIEW. **Stage 2 PR-H (this branch, final)**: `Bar_reader` abstraction + 6 reader-site swap point + parity test. Introduces `Bar_reader.t` (closure bundle hiding Bar_history vs Bar_panels). All 6 reader sites — macro_inputs (`build_global_index_bars`, `build_sector_map`), stops_runner (`_compute_ma`), weinstein_strategy (entry stop, `_screen_universe`, primary index Friday detection) — now consume `Bar_reader`. `Weinstein_strategy.make` gains `?bar_panels:Bar_panels.t`; when supplied it takes precedence over `?bar_history`. `Bar_panels.column_of_date` (new helper) maps "today's date" to a panel column. Reader-site parity test (`test_bar_reader_parity`, 5 tests) feeds identical bars through both backends and asserts bit-identical bar-list outputs (daily, weekly, unknown-symbol, as_of-truncation, out-of-calendar). **Scope deviation**: Bar_history deletion + runner-level swap deferred — wiring `~bar_panels` into Panel_runner triggered structural divergence with Tiered (5 vs 3 trades on smoke parity scenario) because Tiered seeds Bar_history incrementally via the Friday Full-tier promote cycle while Bar_panels is fully populated up-front. The reader-level swap is correct (parity-tested). Closing the runner-level gap requires Stage 3 (collapse Tiered cycle) and is deferred. |
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
