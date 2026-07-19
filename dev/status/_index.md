# Status Index

Single-source view of all tracked work. Detail belongs in the per-track
status files linked in column 1. Keep every "Next task" cell to one line
(<=160 chars); the `index_size_linter.sh` CI check enforces this.

Last updated: 2026-07-19 (orchestrator run 29683964833 — run-1 of 07-19: main GREEN, HEAD `73fd37a0` (#2007 track-pacer). Local `dune build` exit 0 + `dune runtest` exit 0 (no FAIL/LAPACKE/SIGILL), integrity exit 0, index_size exit 0 (10200/20480); GHA CI on `73fd37a0` build-and-test/perf-tier1/both-5y+custom goldens all success. Since 07-18-run3: #2002 (virgin hist-empty clearance arm) MERGED, #2004 (resistance-v2 28y docs) + #2007 (weekly track-pacer) merged. **1 open PR — #2005** (`feat/margin-m1b2-portfolio-debit`, author dayfine, maintainer LOCAL): M1b-2 portfolio long-margin debit; CI GREEN (build-and-test+perf-tier1 success), maintainer self-posted behavioral QC **APPROVED** (quality 5) at tip `9fe677c5`. Deferred to LOCAL — active-LOCAL collision-avoidance + A1 core-module (portfolio) human-decision gate; orchestrator does NOT auto-merge (maintainer authored+reviewed+will merge). Reconciled resistance-v2 (#2002 merged) + margin-realism (#2005 open) rows. Dispatched 1 harness-maintainer for the LAPACKE GP-Cholesky nugget-escalation fix — INCOMPLETE (GHA shared-checkout dune-lock contention; good partial diff preserved as a patch, re-dispatch in isolation). No feat/cleanup/ops-data dispatch (frontier deep-warehouse-data-gated [no EODHD_API_KEY] / human-gated / active-LOCAL; cleanup §Backlog 0 real `[ ]`; ops-data no API key + data-gaps.md unchanged since #814). PRIOR HEADER: 2026-07-18 (orchestrator run 29658279536 — run-3 of 07-18: main GREEN — local `dune build` exit 0 + `dune runtest` exit 0 (no FAIL/LAPACKE/SIGILL; fmt_check OK, magic_numbers OK), integrity exit 0, index_size exit 0 (10033/20480). HEAD `010ad196` (#2001, docs-only resistance-v2 promotion inputs); GHA CI on `010ad196` build-and-test/perf-tier1/both-goldens all success. **1 open PR — #2002** (`feat/virgin-crossing-hist-empty`, author dayfine, maintainer LOCAL): CI GREEN, but the maintainer self-posted a **behavioral QC NEEDS_REWORK** (doc-only `.mli` accuracy defect — histogram basis is mid-price gated on intraweek-high, not closing basis). Deferred to LOCAL: NOT rework-dispatched (collision avoidance — maintainer authored + self-QC'd + will fix their own doc) and NOT merged (NEEDS_REWORK). Reconciled resistance-v2 row → open PR #2002. No feat/harness/cleanup/ops-data dispatch (frontier deep-warehouse-data-gated [no EODHD_API_KEY] / human-gated [M6.6, R3 promotion, M1b-2 A1] / active-LOCAL; harness milestone/human/PAT/golden-gated + LAPACKE flake LOCAL; cleanup §Backlog 0 real `[ ]`; ops-data no API key + data-gaps.md unchanged since #814).)

## Active + complete tracks

Each row: one line; deeper task detail in the linked status file.
"Next task" = top-of-queue concrete item from that file's Next Steps.

| Track | Status | Owner | Open PR(s) | Next task |
|---|---|---|---|---|
| [resistance-v2](resistance-v2.md) | IN_PROGRESS | dayfine (maintainer LOCAL) | — | #2002 virgin hist-empty fix MERGED; grid 3/3 ACCEPT robust w=30; R3 promotion human-gated (28y terminal-wealth flag); WF-CV vs w30 data-gated |
| [margin-realism](margin-realism.md) | IN_PROGRESS | dayfine (maintainer LOCAL) | #2005 | M1a(#1990)+M1b-1(#1998) MERGED default-off; M1b-2 portfolio debit OPEN #2005 (CI green, behavioral APPROVED self-QC, A1 core-module LOCAL); then M2–M4 |
| [capital-management-scale-in](capital-management-scale-in.md) | MERGED | — | — | PROGRAM CLOSED: v1 (#1840) + v2 (#1860) both REJECTED; mechanisms merged default-off, searchable; class exhausted (2026-07-06) |
| [cash-reserve](cash-reserve.md) | MERGED | — | — | CLOSED: mechanism MERGED default-off (#1867); WF-CV surface {0,.1,.2,.3} REJECT (ledger 2026-07-06, #1872); envelope program closed both directions (2026-07-06) |
| [backtest-infra](backtest-infra.md) | IN_PROGRESS | dayfine (maintainer) | — | trades.csv export-join fix MERGED (#1942, position_id column); next: validator audit-join fix (C6b, dispatched) then P2 matrix (data-gated) |
| [rename-twin-dedup](rename-twin-dedup.md) | IN_PROGRESS | feat-backtest | — | v1(#1940)+v2(#1946) MERGED; dedup warehouse rebuilt + 28y record re-run landed (#1949, 83 groups/91 legs dropped); next: none (optional V6 report-consult tweak) |
| [post-run-validation](post-run-validation.md) | IN_PROGRESS | feat-backtest | — | v1 harness (#1937) + C6b audit-join-by-position_id (#1947) MERGED; next: golden-run integration test for V3/V4/V7 (data-gated) |
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
| [extension-stop](extension-stop.md) | IN_PROGRESS | dayfine (maintainer LOCAL) | — | arming + insurance-ACCEPT MERGED (#1960, ext_stop 2.0/0.25, default-off); next: default-flip only on further insurance-ACCEPT (R3, human-gated) |
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
| [screener](screener.md) | MERGED | — | — | resistance Insufficient_history label MERGED (#1941, default-off); next: arm min_history_bars for live weekly-review + record convention |
| [simulation](simulation.md) | IN_PROGRESS | feat-backtest | — | #1847 sibling round-trip pairing fix MERGED (761c30cf); per-trade scale-in reporting now trustworthy. Next: stale-exit grid via WF-CV (data-gated) |
| [trade-autopsy](trade-autopsy.md) | MERGED | — | — | — |
| [stage3-hysteresis](stage3-hysteresis.md) | MERGED | — | — | — |
| [experiment-platform](experiment-platform.md) | IN_PROGRESS | feat-backtest | — | force-exit-off grid REJECTED for promotion (#1503); single-dial surface exhausted; next: continuation-buy recheck on top-3000 (data-gated) |
| [experiments](experiments.md) | MERGED | — | — | — |
| [tuning-methods](tuning-methods.md) | PENDING | feat-backtest | — | Step 0 done; steps 1-3 demoted (surface is the bind); component-decomposition objective next |
| [tuning](tuning.md) | IN_PROGRESS | feat-backtest | — | M1 complete (5/5 deliverables); M2 qNEHVI next (awaiting maintainer enable-commit per #1327) |
| [weekly-snapshot](weekly-snapshot.md) | IN_PROGRESS | feat-weinstein | — | snapshot fast-input path (#1784) + corrected 5-wk picks (#1781) MERGED; next: large-warehouse multi-week sweep (data-gated); live-cycle human-gated |
| [walk-forward-cv](walk-forward-cv.md) | MERGED | feat-backtest | — | — |
| [data-foundations](data-foundations.md) | IN_PROGRESS | feat-data | — | asset-type blocklist MERGED (#1939, default-off); next: arm ATB.curated for live universe build + General::Type enrichment feed |
| [floor-quality](floor-quality.md) | IN_PROGRESS | dayfine (maintainer LOCAL) | — | P1b step2 SPY-sleeve MERGED #1913; next = step 3 lens screen vs TR-SPY (deep-warehouse, maintainer LOCAL / S5) |

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
