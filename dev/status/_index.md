# Status Index

Single-source view of all tracked work. Update when a status file flips
state, an owner changes, or a PR opens / merges / closes. Keep the table
terse; detail belongs in the per-track status files linked in column 1.

Last updated: 2026-04-27 run-2 (no-dispatch run — main GREEN re-verified after maintainer landed 6 PRs between run-1 and run-2: #611 + #612 + #615 + #616 + #617 + #618. Net effect: hybrid-tier Phase 2 direction implicitly chosen (Option 1 engine-pooling — maintainer authored PR-1 #618 directly), short-side bear-window regression test landed (#617), perf-tier1 held-out workflow yaml committed (#616), short-side real-data verification merged (#612, supersedes #608's premise). Zero open PRs against main. No feature dispatch this run: maintainer is actively driving engine-pooling track personally and no Direction Change in `dev/decisions.md` authorizes orchestrator dispatch of PR-2 onward. Steps 3+4 of backtest-perf still hard-blocked on workflow-PAT (Steps 3+4 yaml, distinct from #616).)

## Active + complete tracks

Each row: one line; deeper task detail in the linked status file.
"Next task" = top-of-queue concrete item from that file's Next Steps.

| Track | Status | Owner | Open PR(s) | Next task |
|---|---|---|---|---|
| [backtest-infra](backtest-infra.md) | MERGED | — | — | — Steps 1 (#399) + 2 (#419) landed earlier. Sweep harness extension #547 landed 2026-04-25. Continuous monitoring + release-gate scope moved to `backtest-perf` track; Tier-3-architecture follow-on now tracked at `data-panels` (supersedes `incremental-indicators`). |
| [backtest-scale](backtest-scale.md) | MERGED (superseded) | — | — | Tiered path entirely deleted in `data-panels` Stage 3 PR 3.3 (#573, 2026-04-26). PR #525 (`Bar_history.trim_before` primitive) merged 2026-04-24 but is now moot — `Bar_history` itself deleted in Stage 3 PR 3.2 (#569). All residual concerns (RSS, parity, Legacy→Tiered flip) absorbed by `data-panels` columnar redesign. Per-track status file lags reality and should be flipped to MERGED/superseded; orchestrator merge-watch flagged but did not auto-edit (leaves discretion to maintainer). |
| [backtest-perf](backtest-perf.md) | IN_PROGRESS | feat-backtest | — | Steps 1+2 (#574) merged 2026-04-26; held-out `perf-tier1.yml` workflow committed by maintainer in #616 (2026-04-27). Steps 3+4 (tier-2 nightly + tier-3 weekly workflow yamls) outstanding — same `workflow`-PAT blocker as before #616. Engine-pooling PR-1 (Gc.stat instrumentation, #618 by maintainer) merged 2026-04-27T12:26Z; PR-2..PR-4 (per-symbol scratch + float-array buffers + buffer pool, ~600 LOC total) pending — orchestrator does NOT auto-dispatch absent explicit Direction Change in `dev/decisions.md` (maintainer is driving manually). Step 5 (`release_perf_report` OCaml exe) tracked via #585/#606. |
| [data-panels](data-panels.md) | MERGED | — | — | Stage 4.5 PR-B (#604) merged 2026-04-27T02:33Z — last in-flight data-panels PR. Columnar redesign + lazy cascade (Stages 0–4 + 4.5 PR-A/PR-B) landed end-to-end. Stage 4 PR-A/B/C/D = #584/#588/#590/#594; Stage 4.5 PR-A = #599. Engine-wedge investigation surfaced by post-PR-A memtrace handed off to `hybrid-tier` track (Phase 1 results in `dev/notes/hybrid-tier-phase1-results-2026-04-27.md`). PR-C (tunable filter thresholds) remains an optional follow-up; not currently scoped. |
| [hybrid-tier](hybrid-tier.md) | BLOCKED (Phase 2 design invalidated; Option 1 implicitly chosen by maintainer) | feat-backtest | — | Phase 1 (#609 measurement; #610 results note) merged 2026-04-27. Replan plans both merged 2026-04-27 in #611 — Option 1 engine-layer pooling (~600 LOC, plan at `dev/plans/engine-layer-pooling-2026-04-27.md`) and Option 2 daily-snapshot streaming (~3,000 LOC, plan at `dev/plans/daily-snapshot-streaming-2026-04-27.md`). Maintainer authored PR-1 of Option 1 directly (#618, merged 2026-04-27T12:26Z) — implicit selection of Option 1. PR-2..PR-4 (per-symbol scratch buffers + buffer pool) pending. Orchestrator does NOT dispatch PR-2 until a Direction Change line lands in `dev/decisions.md` explicitly authorizing feat-backtest to take engine-pooling work (maintainer is currently driving the program personally). |
| [support-floor-stops](support-floor-stops.md) | MERGED | — | — | — (PRs #382 primitive + #390 wiring both merged 2026-04-17) |
| [short-side-strategy](short-side-strategy.md) | MERGED | — | — | MVP slice #420 merged 2026-04-19. #608 + #612 (docs/notes) merged 2026-04-27; #617 (`test_short_side_bear_window.ml` regression test pinning Macro=Bearish contract) merged 2026-04-27. Remaining: live-cascade Bearish macro plumbing (Follow-up #4 in status file) — bug upstream in `_run_screen.macro_callbacks` construction; PR #612 explicitly recommends opening a fresh issue scoped to the real wedge before code dispatch. Orchestrator awaits that issue + Direction Change before reactivating the track. |
| [strategy-wiring](strategy-wiring.md) | MERGED | — | — | — (#408 + #409 both merged 2026-04-18) |
| [sector-data](sector-data.md) | MERGED | — | — | — (#436 merged 2026-04-19). GHA orchestrator runs continue to consume `trading/test_data/sectors.csv`. |
| [harness](harness.md) | IN_PROGRESS | harness-maintainer | — | No open harness PR. Recent merges: #493 POSIX-sh linter, #495 cost-capture new-day fix, #499 cost-capture commit+auto-merge, #504 budget PR creation via curl, #505 budget rescue (all 2026-04-22). Backlog remains saturated — T1 done; T2 milestone-gated; T3-C superseded; T3-H low-priority. Recurring status-file integrity drift from human-merged PRs is a [info] follow-up — linter already exits 1 on violation; requires branch-protection config to enforce. |
| [orchestrator-automation](orchestrator-automation.md) | IN_PROGRESS | harness-adjacent | — | Phase 1 live (daily cron runs producing summary PRs). Phase 2 (background execution for scrapers, golden re-runs, cross-feature QC) pending empirical tests per status file. |
| [cleanup](cleanup.md) | IN_PROGRESS | code-health | — | csv_storage nesting fix (#578) merged 2026-04-26T16:04Z. Backlog now empty; next finding will land via the weekly deep scan (`.github/workflows/health-deep-weekly.yml`) or be added by orchestrator Step 2e if the deterministic post-run checks surface a new `[medium]`/`[high]` item. |
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
