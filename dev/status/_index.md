# Status Index

Single-source view of all tracked work. Update when a status file flips
state, an owner changes, or a PR opens / merges / closes. Keep the table
terse; detail belongs in the per-track status files linked in column 1.

Last updated: 2026-04-28 run-2 (orchestrator reconcile post run-1 — between run-1 (08:52Z) and run-2: PR #652 (optimal-strategy PR-1) merged at 12:52Z; PR #654 (session follow-ups note) merged at 12:45Z; PR #641 (`fix/split-day-mtm`) closed-without-merge at 12:50Z (held indefinitely per `dev/notes/session-followups-2026-04-28.md` §1; needs broker-model redesign instead of band-aid). This run dispatched feat-backtest on optimal-strategy PR-2 (`Outcome_scorer`) → PR #659 (combined QC APPROVED, quality 5, 21/21 tests pass). Index row deltas: optimal-strategy READY_FOR_REVIEW → IN_PROGRESS (#652 merged, #659 in flight); simulation row drops the #641 reference (closed-without-merge). Schema fixes: hybrid-tier.md `PARTIAL_DONE` → `IN_PROGRESS` (run-1, persists). Carried forward from run-1: A2 architecture rule still stale (overridden again on PR-2); broker-model design plan still pending human authorship.)

## Active + complete tracks

Each row: one line; deeper task detail in the linked status file.
"Next task" = top-of-queue concrete item from that file's Next Steps.

| Track | Status | Owner | Open PR(s) | Next task |
|---|---|---|---|---|
| [backtest-infra](backtest-infra.md) | MERGED | — | — | — Steps 1 (#399) + 2 (#419) landed. Sweep harness extension #547 landed 2026-04-25. Continuous monitoring + release-gate scope moved to `backtest-perf`; Tier-3-architecture follow-on lives at `data-panels` (supersedes `incremental-indicators`). |
| [backtest-scale](backtest-scale.md) | MERGED | — | — | Tiered path entirely deleted in `data-panels` Stage 3 PR 3.3 (#573, 2026-04-26). PR #525 (`Bar_history.trim_before` primitive) merged 2026-04-24 but moot — `Bar_history` itself deleted in Stage 3 PR 3.2 (#569). Track confirmed wrapped per #636 (docs status hygiene 2026-04-28). |
| [backtest-perf](backtest-perf.md) | IN_PROGRESS | feat-backtest | — | Tier-1..tier-4 perf workflows all live (tier-1 #574+#616+#634, tier-2 #622, tier-3 #625, tier-4 N=1000 #635+#640). Engine-pool PR-1..PR-5 (#618/#626/#628/#632/#633) all merged — β: 4.30 → 3.94 MB/symbol (−8%), wall −36% at 292×6y. `release_perf_report` exe (#629) merged. Tier-1 universe-path bug fix (#634) flipped continue-on-error to false. Status file's §Open work block is now stale — every named branch on it has merged; orchestrator did not in-place edit to keep parallel-write surface narrow (refresh during next feat-backtest dispatch). Outstanding: §Decision items (4 human/QC sign-off questions), tier-4 first manual `workflow_dispatch` to produce canonical baseline, N≥5000 release-gate stays P1 awaiting daily-snapshot streaming (`dev/plans/daily-snapshot-streaming-2026-04-27.md`). |
| [data-panels](data-panels.md) | MERGED | — | — | Stage 4.5 PR-B (#604) merged 2026-04-27T02:33Z — last in-flight data-panels PR. Columnar redesign + lazy cascade (Stages 0–4 + 4.5 PR-A/PR-B) landed end-to-end. Engine-wedge investigation handed off to `hybrid-tier` (Phase 1 results in `dev/notes/hybrid-tier-phase1-results-2026-04-27.md`). PR-C (tunable filter thresholds) remains an optional follow-up. |
| [hybrid-tier](hybrid-tier.md) | IN_PROGRESS | feat-backtest | — | Option 1 (engine-layer pooling) DONE 2026-04-28 — five PRs (#618 instrumentation, #626 Scratch type, #628 thread per-tick, #632 buffer pool, #633 matrix re-run). β: 4.30 → 3.94 MB/symbol (−8%, short of plan's 1-1.5 target); wall: −36% at 292×6y. N=1000×10y now fits 8 GB. Option 2 (daily-snapshot streaming) — P1 future work, ~3,000 LOC across 5-8 PRs per `dev/plans/daily-snapshot-streaming-2026-04-27.md`; required for tier-4 release-gate at N≥5,000. Track stays IN_PROGRESS until Option 2 ships. Schema fix: ## Status `PARTIAL_DONE` → `IN_PROGRESS` on this run. |
| [trade-audit](trade-audit.md) | MERGED | — | — | All five phased PRs landed 2026-04-28: PR-1 (#638) types+collector+persistence, PR-2 (#642) capture sites, PR-2 ext (#646) cascade-rejection counts, PR-3 (#643) markdown renderer, PR-4 (#649) `Trade_rating` heuristics + 4 behavioral metrics, PR-5 (#651) wired into `release_perf_report`. Track wraps; sister `optimal-strategy` track now picks up the next layer. |
| [optimal-strategy](optimal-strategy.md) | IN_PROGRESS | feat-backtest | #659 (feat/optimal-strategy-pr2) | PR-1 (#652) merged 2026-04-28T12:52Z. PR-2 (`Outcome_scorer`) dispatched + delivered + QC'd this run on `feat/optimal-strategy-pr2` → PR #659 (212 LOC lib + 364 LOC tests, 21/21 pass with PR-1 carry-over, combined QC APPROVED, quality score 5). Plan §Risks item 4 resolved as option (a) — `Weinstein_stops` API is already pure, no refactor needed; PR-3 onward can reuse the same threading pattern. Awaiting human merge of #659. Next: PR-3 (`Optimal_portfolio_filler` + `Optimal_summary` ~400 LOC) per plan §Phase C once PR-2 lands. |
| [support-floor-stops](support-floor-stops.md) | MERGED | — | — | — (PRs #382 primitive + #390 wiring both merged 2026-04-17) |
| [short-side-strategy](short-side-strategy.md) | MERGED | — | — | All four §Follow-ups now landed: bear-window regression (#617), live-cascade Bearish macro plumbing fix (#623), full short cascade Stage-4 mirror (#630), Ch.11 spot-check on real 2022 bear (#631). Status file confirmed MERGED via #636 (docs status hygiene 2026-04-28). Future short-side work is performance-driven (cascade-parameter revisits once trade-audit/optimal-strategy land insights). |
| [strategy-wiring](strategy-wiring.md) | MERGED | — | — | — (#408 + #409 both merged 2026-04-18) |
| [sector-data](sector-data.md) | MERGED | — | — | — (#436 merged 2026-04-19). GHA orchestrator runs continue to consume `trading/test_data/sectors.csv`. |
| [harness](harness.md) | IN_PROGRESS | harness-maintainer | — | Backlog drained: T1 done, T2 milestone-gated, T3-C superseded, T3-H low-priority, T4-* future. No dispatchable items. Recurring status-file integrity drift from human-merged PRs is a [info] follow-up (linter writes FAIL to stdout but `dune runtest` exits 0; making it gating requires branch-protection config, not a code change). NEW [info] follow-up surfaced this run: `.claude/rules/qc-structural-authority.md` §A2 ("no imports from `analysis/` into `trading/trading/`") is stale relative to actual repo precedent — 5+ existing `trading/trading/backtest/*` dunes already import `weinstein.*`; the rule should be reformulated (drop, allow-list, or repo reorg). Tripped a false-positive NEEDS_REWORK from qc-structural on optimal-strategy PR-1 today. |
| [orchestrator-automation](orchestrator-automation.md) | IN_PROGRESS | harness-adjacent | — | Phase 1 live (daily cron runs producing summary PRs). Phase 2 (background execution for scrapers, golden re-runs, cross-feature QC) pending empirical tests per status file. NEW [info] follow-up surfaced this run: qc-structural agent edited `dev/status/optimal-strategy.md` (out-of-scope — should write only `dev/reviews/`); orchestrator reverted on the agent's branch before checkout to `ops/daily-2026-04-28`. Worth tightening qc-structural's tool subset or adding a guard in its prompt. |
| [cleanup](cleanup.md) | IN_PROGRESS | code-health | — | Backlog empty after #578 (csv_storage nesting fix). Next finding via weekly deep scan (`.github/workflows/health-deep-weekly.yml`) or via Step 2e if today's deterministic post-run checks surface a new `[medium]`/`[high]` item. None surfaced this run. |
| [cost-tracking](cost-tracking.md) | IN_PROGRESS | harness-maintainer | — | GHA cost capture step landed (#483); cost-capture new-day bug fixed via #495 + #499 (2026-04-22). Next: verify measured `total_cost_usd` lands on this run's `dev/budget/2026-04-28-run*.json` post-orchestrator-exit. |
| [data-layer](data-layer.md) | MERGED | — | — | — |
| [portfolio-stops](portfolio-stops.md) | MERGED | — | — | — |
| [screener](screener.md) | MERGED | — | — | — |
| [simulation](simulation.md) | IN_PROGRESS | feat-backtest | feat/split-day-pr2 | Split-day OHLC redesign (`dev/plans/split-day-ohlc-redesign-2026-04-28.md`) in flight. PR-1 (`Split_detector` primitive) merged 2026-04-28 as #658. PR-2 (`Split_event` ledger primitive in `Trading_portfolio`) opened 2026-04-28 on `feat/split-day-pr2` — pure broker-model adjustment, preserves total cost basis, keeps fractional shares. No simulator wiring yet (PR-3). Existing goldens stay bit-identical. |

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
