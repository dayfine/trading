# Status Index

Single-source view of all tracked work. Detail belongs in the per-track
status files linked in column 1. Keep every "Next task" cell to one line
(<=160 chars); the `index_size_linter.sh` CI check enforces this.

Last updated: 2026-06-15 (orchestrator run 27536849711 [run 3]: NO feat-dispatch — GHA-eligible surface still drained. Main GREEN on 7e96220b (since run 2: #1594 eligibility builder, #1598 first live weekly-picks baseline 2026-06-12, #1599 2026-06-15 handoff+memory all MERGED by dayfine local session). Reconciled data-foundations (#1594 merged → no open PR) + weekly-snapshot (#1598 baseline shipped) rows. Only open PR #1596 is LOCAL maintainer (dayfine) C2-test work — fenced per gha-local-coordination.md (do not QC/merge; "auto-merging" per handoff). 2026-06-15 locked priority order [0 recs-baseline DONE #1598] → [1] policy universe (human-gated, no threshold) → [2] factor-lens 5b → [3] WF-CV 28y → [4] margin; all routed LOCAL or data/human-gated. Health CLEAN (linters exit 0). 0 subagents. [run 2]: NO feat-dispatch — drained surface; #1589/#1593/#1595 merged, ci-red #1591 closed. [run 1]: RED-MAIN RECOVERY — a05d9479 disk-exhaustion infra flake cleared by merging CI-green #1590 → GREEN 567d7760. 2026-06-14 [run 4]: AUTO-MERGED #1588 (M6.6 generator).)

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
| [weekly-snapshot](weekly-snapshot.md) | IN_PROGRESS | feat-weinstein | #1596 (local) | M6.6 bin (#1588) + first live baseline (#1598, 2026-06-12) SHIPPED; #1596 (local) C2 test auto-merging; next: live-cycle (DATA_SOURCE/cron/alerts, human-gated) |
| [walk-forward-cv](walk-forward-cv.md) | MERGED | feat-backtest | — | — |
| [data-foundations](data-foundations.md) | IN_PROGRESS | feat-data | — | Thread-1 (#1589) + eligibility builder (#1594) + live data refresh (#1595) MERGED; next: policy artifact (ADR $-vol human-gated) — largely subsumed by eligibility builder |

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
