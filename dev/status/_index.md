# Status Index

Single-source view of all tracked work. Detail belongs in the per-track
status files linked in column 1. Keep every "Next task" cell to one line
(<=160 chars); the `index_size_linter.sh` CI check enforces this.

Last updated: 2026-06-14 (orchestrator run 27514324131 [run 4]: 1 DISPATCH → AUTO-MERGED. Built + merged #1588 (weekly-snapshot M6.6 `generate_weekly_snapshot` bin / Initiative A — green-lit for GHA dispatch by the 2026-06-14 grill-session handoff). 1 rework cycle: CI nesting-linter caught 3 over-limit fns the scoped runtest missed → fix(review) cd87d217 extracted helpers → CI green → all 3 gates → squash-merged a05d9479. qc-structural A2 csv-finding adjudicated false-positive vs main precedent (data_panel/simulation/lib/data/sibling snapshot bins). Also cleared stale rolling-start-lens #1586 (merged). [run 3]: NO feat-dispatch — backlog still fully gated (run-1 drained the eligible non-gated work). Sole main change since run-2 is the maintainer-merged #1582, which flipped the NS1 cash-floor exemption default → ON on correctness grounds (R3-NA, goldens bit-equal) — resolving run-2's Question 2. This run reconciled the now-stale cash-floor-correctness.md (recorded the #1582 flip; NS4 demoted from promotion-gate to optional retrospective DD-validation; Owner note updated) + this index row. Main GREEN on 9d29ef28 (CI build-and-test + perf-tier1-smoke SUCCESS; 0 ci-red). [run 2]: status hygiene only — merged docs-only track-pacer #1580, refreshed weekly-snapshot.md + backtest-infra.md. [run 1]: 2 dispatches BOTH AUTO-MERGED — #1574 sweep-perf Win #4, #1575 cash-floor NS3.)

## Active + complete tracks

Each row: one line; deeper task detail in the linked status file.
"Next task" = top-of-queue concrete item from that file's Next Steps.

| Track | Status | Owner | Open PR(s) | Next task |
|---|---|---|---|---|
| [backtest-infra](backtest-infra.md) | IN_PROGRESS | dayfine (maintainer) | — | Fold_health wiring MERGED (#1558); warmup-suppression WF-CV rejects the flip (#1561); next: P2 matrix on composition-policy universe (data-gated) |
| [cash-floor-correctness](cash-floor-correctness.md) | IN_PROGRESS | feat-weinstein | — | NS1 impl+flip ON (#1567/#1582 correctness), NS2 design+NS3 MERGED (#1569/#1575); next: NS2 impl (human-gated), NS4 optional DD-validation (data-gated) |
| [backtest-scale](backtest-scale.md) | MERGED | — | — | — |
| [backtest-perf](backtest-perf.md) | IN_PROGRESS | feat-backtest | — | rolling-start v2 merged (#1536: jittered starts, edge-vs-SPY matrix, fork-per-start); next: run matrix on composition-policy universe |
| [rolling-start-lens](rolling-start-lens.md) | IN_PROGRESS | feat-backtest | — | realized-edge + forward-index-DD lens columns MERGED (#1586); next: 3 data-gated factor cols (macro-stage, Stage-2 count, sector-RS) + 31-start causal analysis |
| [sweep-perf](sweep-perf.md) | IN_PROGRESS | harness-maintainer | — | Win #4 production wiring MERGED (#1574, opt-in default-off); next: manual ghcr.io flambda rebuild + enable prune opt-in in sweeps |
| [cost-model](cost-model.md) | MERGED | — | — | — |
| [data-panels](data-panels.md) | MERGED | — | — | — |
| [hybrid-tier](hybrid-tier.md) | MERGED | — | — | — |
| [trade-audit](trade-audit.md) | MERGED | — | — | — |
| [optimal-strategy](optimal-strategy.md) | MERGED | — | — | — |
| [all-eligible](all-eligible.md) | MERGED | — | — | — |
| [support-floor-stops](support-floor-stops.md) | MERGED | — | — | — |
| [short-side-strategy](short-side-strategy.md) | IN_PROGRESS | feat-weinstein | — | Phase-2 margin_call dedup ALREADY FIXED (#1274 — status stale); next: WF-CV short_min_price axis 0.0 vs ~17.0 (data-gated) |
| [spy-only-reference](spy-only-reference.md) | IN_PROGRESS | feat-weinstein | — | WF-CV on sector-rotation testbed; top-1000 bankability gate; long-short verification (human session) |
| [stage-accuracy](stage-accuracy.md) | IN_PROGRESS | feat-weinstein | — | force_exit_off grid REJECTED (#1503); cascade-selection inversion documented (#1509 merged); broad-universe WF-CV re-run data-gated |
| [harvest-rotate](harvest-rotate.md) | MERGED | — | — | WF-CV REJECT (#1532) — dispersion-amplifying noise, not Sharpe edge; mechanism stays default-off, axis not promoted |
| [strategy-wiring](strategy-wiring.md) | MERGED | — | — | — |
| [sector-data](sector-data.md) | MERGED | — | — | — |
| [harness](harness.md) | IN_PROGRESS | harness-maintainer | — | Tier 1 fully checked off; T3-H low-priority; no active dispatch surface |
| [orchestrator-automation](orchestrator-automation.md) | IN_PROGRESS | harness-maintainer | — | Phase 1 stable (PR-D'c #1332 merged); Phase 2 deferred; no outstanding work |
| [cleanup](cleanup.md) | IN_PROGRESS | code-health | — | no active backlog; next finding via weekly deep scan or Step 2e |
| [cost-tracking](cost-tracking.md) | MERGED | — | — | — |
| [data-layer](data-layer.md) | MERGED | — | — | — |
| [portfolio-stops](portfolio-stops.md) | MERGED | — | — | — |
| [screener](screener.md) | MERGED | — | — | — |
| [simulation](simulation.md) | IN_PROGRESS | feat-backtest | — | stale-exit promotion grid now runnable via WF-CV (#1491/#1494); M5 walk-forward + tuner catch-all items |
| [trade-autopsy](trade-autopsy.md) | MERGED | — | — | — |
| [stage3-hysteresis](stage3-hysteresis.md) | MERGED | — | — | — |
| [experiment-platform](experiment-platform.md) | IN_PROGRESS | feat-backtest | — | force-exit-off grid REJECTED for promotion (#1503); single-dial surface exhausted; next: continuation-buy recheck on top-3000 (data-gated) |
| [experiments](experiments.md) | MERGED | — | — | — |
| [tuning-methods](tuning-methods.md) | PENDING | feat-backtest | — | Step 0 done; steps 1-3 demoted (surface is the bind); component-decomposition objective next |
| [tuning](tuning.md) | IN_PROGRESS | feat-backtest | — | M1 complete (5/5 deliverables); M2 qNEHVI next (awaiting maintainer enable-commit per #1327) |
| [weekly-snapshot](weekly-snapshot.md) | IN_PROGRESS | feat-weinstein | — | M6.1–M6.5 + M6.6 generate_weekly_snapshot bin SHIPPED (#1588, orchestrator); next: baseline pick record + live-cycle (DATA_SOURCE/cron/alerts, human-gated) |
| [walk-forward-cv](walk-forward-cv.md) | MERGED | feat-backtest | — | — |
| [data-foundations](data-foundations.md) | IN_PROGRESS | feat-data | — | P1'.1 $-volume wiring MERGED (#1542); next: emit composition-policy universe artifact + weekly ADV screener gate |

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

The `Next task` cell must be **one line** (<=160 chars). History and
rationale belong in the per-track status file, not here.
`trading/devtools/checks/index_size_linter.sh` enforces the cap at CI.

Orchestrator reconciliation: `lead-orchestrator` diffs this index
against the per-track status files at end-of-run and flags drift.

Adding a new track means creating the status file AND adding a row
here in the same commit.
