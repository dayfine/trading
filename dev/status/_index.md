# Status Index

Single-source view of all tracked work. Detail belongs in the per-track
status files linked in column 1. Keep every "Next task" cell to one line
(<=160 chars); the `index_size_linter.sh` CI check enforces this.

Last updated: 2026-07-09 (orchestrator run 29035859700 [**run-2**]: **reconcile + health pass**, active-LOCAL-session observed. Main (locally-tested HEAD `75014575`) **GREEN**: `dune build` exit 0, `dune runtest` exit 0 (fmt_check/magic_numbers/mli_coverage/file_length OK, no FAIL; cc_linter advisory only). Remote main advanced to `19bb8b0f` via #1903 merge (docs/experiment, CI-green pre-merge, no code) — still green. **Live LOCAL PR churn by maintainer this run:** #1903 (Portfolio_floor floor-off ablation) MERGED 17:20Z; #1902 (delete dead `check_limits`, user-mandated) OPEN + CI-green; #1904 (P1b circuit-breaker pure lib, adds `floor-quality.md` track) OPEN + CI-in-progress. **No orchestrator dispatch / QC / merge** — the 3 code/docs PRs are the maintainer's live LOCAL frontier (QC needs LOCAL docker `trading-1-dev`+jj isolation absent in GHA; maintainer QCs+merges LOCALLY — #1903 merged 11 min after opening); collision-avoidance. No per-track row drift (no `dev/status/*.md` changed since run-1; #1899=run-1 summary exempt; #1904 adds its own `floor-quality` row on merge). Every IN_PROGRESS track's next task still data-gated (EODHD_API_KEY absent), human-gated, maintainer-enablement, or LOCAL; harness lone `[~]` ci.yml ENOSPC #1636 human-PAT-blocked; cleanup backlog drained; ops-data sentinel unchanged since #814. Prior: run-1 (29024237769) reconcile+health.

## Active + complete tracks

Each row: one line; deeper task detail in the linked status file.
"Next task" = top-of-queue concrete item from that file's Next Steps.

| Track | Status | Owner | Open PR(s) | Next task |
|---|---|---|---|---|
| [capital-management-scale-in](capital-management-scale-in.md) | MERGED | — | — | PROGRAM CLOSED: v1 (#1840) + v2 (#1860) both REJECTED; mechanisms merged default-off, searchable; class exhausted (2026-07-06) |
| [cash-reserve](cash-reserve.md) | MERGED | — | — | CLOSED: mechanism MERGED default-off (#1867); WF-CV surface {0,.1,.2,.3} REJECT (ledger 2026-07-06, #1872); envelope program closed both directions (2026-07-06) |
| [backtest-infra](backtest-infra.md) | IN_PROGRESS | dayfine (maintainer) | — | readme_toplines top-line numbers MERGED (#1617, 3-gate auto-merge); next: P2 matrix on composition-policy universe (data-gated) |
| [cash-floor-correctness](cash-floor-correctness.md) | IN_PROGRESS | feat-weinstein | — | NS1 impl+flip ON (#1567/#1582 correctness), NS2 design+NS3 MERGED (#1569/#1575); next: NS2 impl (human-gated), NS4 optional DD-validation (data-gated) |
| [backtest-scale](backtest-scale.md) | MERGED | — | — | — |
| [backtest-perf](backtest-perf.md) | IN_PROGRESS | feat-backtest | — | snapshot-format-v2 S4 PROVEN (warehouses v2, top-3000 fits at cache<=1024); S5/v1-cleanup deferred (oversight); next: regime-diverse lenses on v2 (LOCAL) |
| [rolling-start-lens](rolling-start-lens.md) | IN_PROGRESS | feat-backtest | — | t3k factor-lens matrix SHIPPED LOCAL (#1639 2000-26 H1 r=-0.744; #1642 2011-26 confirm); next: regime-gated deploy proxy validation (LOCAL/data-gated) |
| [barbell-overlay](barbell-overlay.md) | MERGED | — | — | Gate-#2 overlay (#1683) + scenario wiring (#1689) + floor_weight searchable axis (#1697, R2 complete) all MERGED default-off; no remaining follow-ups |
| [sweep-perf](sweep-perf.md) | IN_PROGRESS | harness-maintainer | — | Win #4 production wiring MERGED (#1574, opt-in default-off); next: manual ghcr.io flambda rebuild + enable prune opt-in in sweeps |
| [cost-model](cost-model.md) | MERGED | — | — | — |
| [data-panels](data-panels.md) | MERGED | — | — | — |
| [hybrid-tier](hybrid-tier.md) | MERGED | — | — | — |
| [trade-audit](trade-audit.md) | MERGED | — | — | — |
| [decision-audit](decision-audit.md) | MERGED | feat-backtest | — | #1799/#1806/#1811 MERGED (report+counterfactual+weekly-picks adapter); selection FAITHFUL; live-picks pipeline ready (#1812); next: matured weekly counterfactual |
| [optimal-strategy](optimal-strategy.md) | MERGED | — | — | — |
| [all-eligible](all-eligible.md) | MERGED | — | — | — |
| [support-floor-stops](support-floor-stops.md) | MERGED | — | — | — |
| [short-side-strategy](short-side-strategy.md) | IN_PROGRESS | feat-weinstein | — | #1760 liquidity overlay MERGED (default-off); #1659 short-sleeve MERGED; next: short-leg regime-P&L decomposition (Thread C, LOCAL/data-gated) |
| [decline-character](decline-character.md) | IN_PROGRESS | dayfine (maintainer LOCAL) | — | All builds + A-D flip merged; arming-speed A-D-live WF-CV REJECTED (#1729 ledger 06-24); decline mechanisms stay default-off axes; exhausted (#1739) |
| [spy-only-reference](spy-only-reference.md) | IN_PROGRESS | feat-weinstein | — | WF-CV on sector-rotation testbed; top-1000 bankability gate; long-short verification (human session) |
| [stage-accuracy](stage-accuracy.md) | IN_PROGRESS | feat-weinstein | — | force_exit_off grid REJECTED (#1503); cascade-selection inversion documented (#1509 merged); broad-universe WF-CV re-run data-gated |
| [harvest-rotate](harvest-rotate.md) | MERGED | — | — | WF-CV REJECT (#1532) — dispersion-amplifying noise, not Sharpe edge; mechanism stays default-off, axis not promoted |
| [strategy-wiring](strategy-wiring.md) | MERGED | — | — | — |
| [sector-data](sector-data.md) | MERGED | — | — | — |
| [harness](harness.md) | IN_PROGRESS | harness-maintainer | — | CI disk-headroom diagnosis MERGED (#1636, harness.md `[~]`); ci.yml ENOSPC fix BLOCKED on human with `workflow`-scoped PAT — exact YAML in #1636 body |
| [orchestrator-automation](orchestrator-automation.md) | IN_PROGRESS | harness-maintainer | — | Phase 1 stable (PR-D'c #1332 merged); Phase 2 deferred; no outstanding work |
| [cleanup](cleanup.md) | IN_PROGRESS | code-health | — | no active backlog; next finding via weekly deep scan or Step 2e |
| [cost-tracking](cost-tracking.md) | MERGED | — | — | — |
| [data-layer](data-layer.md) | MERGED | — | — | — |
| [portfolio-stops](portfolio-stops.md) | MERGED | — | — | — |
| [screener](screener.md) | MERGED | — | — | — |
| [simulation](simulation.md) | IN_PROGRESS | feat-backtest | — | #1847 sibling round-trip pairing fix MERGED (761c30cf); per-trade scale-in reporting now trustworthy. Next: stale-exit grid via WF-CV (data-gated) |
| [trade-autopsy](trade-autopsy.md) | MERGED | — | — | — |
| [stage3-hysteresis](stage3-hysteresis.md) | MERGED | — | — | — |
| [experiment-platform](experiment-platform.md) | IN_PROGRESS | feat-backtest | — | force-exit-off grid REJECTED for promotion (#1503); single-dial surface exhausted; next: continuation-buy recheck on top-3000 (data-gated) |
| [experiments](experiments.md) | MERGED | — | — | — |
| [tuning-methods](tuning-methods.md) | PENDING | feat-backtest | — | Step 0 done; steps 1-3 demoted (surface is the bind); component-decomposition objective next |
| [tuning](tuning.md) | IN_PROGRESS | feat-backtest | — | M1 complete (5/5 deliverables); M2 qNEHVI next (awaiting maintainer enable-commit per #1327) |
| [weekly-snapshot](weekly-snapshot.md) | IN_PROGRESS | feat-weinstein | — | snapshot fast-input path (#1784) + corrected 5-wk picks (#1781) MERGED; next: large-warehouse multi-week sweep (data-gated); live-cycle human-gated |
| [walk-forward-cv](walk-forward-cv.md) | MERGED | feat-backtest | — | — |
| [data-foundations](data-foundations.md) | IN_PROGRESS | feat-data | — | eligibility builder (#1594) + live refresh (#1595) + staleness guard (#1790) MERGED; next: ADR $-vol policy artifact (human-gated; largely subsumed) |
| [floor-quality](floor-quality.md) | IN_PROGRESS | feat-weinstein | feat/circuit-breaker-lib | P1b step 1: pure index circuit-breaker lib (default-off, axis-ready, no consumers); next: thin SPY sleeve consumer, then lens screen vs TR-SPY |

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
