# Status Index

Single-source view of all tracked work. Update when a status file flips
state, an owner changes, or a PR opens / merges / closes. Keep the table
terse; detail belongs in the per-track status files linked in column 1.

Last updated: 2026-04-27 (no-dispatch run — main GREEN: prior `[critical]`s on csv_storage nesting and data-panels integrity both resolved when #578 + #575 merged 2026-04-26. Major in-flight work since last summary: data-panels Stage 4 PR-A/B/C/D (#584/#588/#590/#594), Stage 4.5 PR-A/B (#599/#604) all merged 2026-04-26→27 — data-panels track now MERGED, columnar redesign + lazy cascade landed end-to-end. backtest-perf Steps 1+2 (#574) merged; Steps 3+4 still pending workflow-PAT. hybrid-tier Phase 1 (#609/#610) merged: empirical results invalidate the original Phase 2 design — engine-layer is the wedge, not data-layer. Three open docs PRs by maintainer this morning: #608 + #612 (short-side bear-window investigation, supersedes itself) and #611 (engine-pooling vs daily-snapshot streaming replan). All three awaiting human review/merge; orchestrator does not touch them. No feature dispatch this run — every track is either MERGED, BLOCKED on human decision (hybrid-tier Phase 2 direction), or hard-blocked (backtest-perf workflow-scoped PAT).)

## Active + complete tracks

Each row: one line; deeper task detail in the linked status file.
"Next task" = top-of-queue concrete item from that file's Next Steps.

| Track | Status | Owner | Open PR(s) | Next task |
|---|---|---|---|---|
| [backtest-infra](backtest-infra.md) | MERGED | — | — | — Steps 1 (#399) + 2 (#419) landed earlier. Sweep harness extension #547 landed 2026-04-25. Continuous monitoring + release-gate scope moved to `backtest-perf` track; Tier-3-architecture follow-on now tracked at `data-panels` (supersedes `incremental-indicators`). |
| [backtest-scale](backtest-scale.md) | MERGED (superseded) | — | — | Tiered path entirely deleted in `data-panels` Stage 3 PR 3.3 (#573, 2026-04-26). PR #525 (`Bar_history.trim_before` primitive) merged 2026-04-24 but is now moot — `Bar_history` itself deleted in Stage 3 PR 3.2 (#569). All residual concerns (RSS, parity, Legacy→Tiered flip) absorbed by `data-panels` columnar redesign. Per-track status file lags reality and should be flipped to MERGED/superseded; orchestrator merge-watch flagged but did not auto-edit (leaves discretion to maintainer). |
| [backtest-perf](backtest-perf.md) | IN_PROGRESS (Steps 1+2 MERGED) | feat-backtest | — | Steps 1+2 (`feat/backtest-perf-tier1-catalog`, #574) merged 2026-04-26T16:07Z. **Held-out:** `.github/workflows/perf-tier1.yml` (drafted in #574's PR body; maintainer must commit with `workflow`-scoped token). Steps 3+4 (tier-2 nightly + tier-3 weekly workflows) outstanding — same blocker. Step 5 (`release_perf_report` OCaml exe) tracked via #585/#606. Tier-4 release-gate scenarios structurally unblocked (data-panels Stage 4.5 PR-B #604 merged 2026-04-27T02:33Z); next memory-win lever is engine-layer-pooling (hybrid-tier Option 1, awaiting human go-ahead via PR #611). |
| [data-panels](data-panels.md) | MERGED | — | — | Stage 4.5 PR-B (#604) merged 2026-04-27T02:33Z — last in-flight data-panels PR. Columnar redesign + lazy cascade (Stages 0–4 + 4.5 PR-A/PR-B) landed end-to-end. Stage 4 PR-A/B/C/D = #584/#588/#590/#594; Stage 4.5 PR-A = #599. Engine-wedge investigation surfaced by post-PR-A memtrace handed off to `hybrid-tier` track (Phase 1 results in `dev/notes/hybrid-tier-phase1-results-2026-04-27.md`). PR-C (tunable filter thresholds) remains an optional follow-up; not currently scoped. |
| [hybrid-tier](hybrid-tier.md) | BLOCKED (Phase 2 design invalidated) | feat-backtest | #611 (open, by maintainer) — replan options doc | Phase 1 (`feat/hybrid-tier-phase1-measurement`, #609) merged 2026-04-27T04:02Z; results note (#610) merged 2026-04-27T04:44Z. Empirical findings invalidate the original 3-tier `Tiered_panels.t` design: Exp A shows H_load wins (RSS-default ≈ RSS-no-candidates within 0.2%); Exp B shows the wedge is in engine/simulator per-tick allocations, not data layer. Two replanning options on PR #611 (open, by maintainer): **Option 1** engine-layer pooling (~600 LOC, immediate), **Option 2** daily-snapshot streaming (~3,000 LOC, larger payoff at tier-4 release-gate scale). Awaiting human go-ahead on which option to dispatch first. |
| [support-floor-stops](support-floor-stops.md) | MERGED | — | — | — (PRs #382 primitive + #390 wiring both merged 2026-04-17) |
| [short-side-strategy](short-side-strategy.md) | MERGED | — | #608, #612 (open, docs/notes by maintainer) | MVP slice #420 merged 2026-04-19. Two open docs PRs by maintainer (2026-04-27): #608 investigation note (bear-window blocked on stale breadth data) and #612 real-data verification (supersedes #608's premise — bug lives in screener cascade / signal-emission, not in macro). Awaiting human review/close-out before any code dispatch on the screener-cascade fix. |
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
