# Status Index

Single-source view of all tracked work. Detail belongs in the per-track
status files linked in column 1. Keep every "Next task" cell to one line
(<=160 chars); the `index_size_linter.sh` CI check enforces this.

Last updated: 2026-06-26 (orchestrator run 28212309813: ACTIVE PASS — 2 subagents (qc-structural + qc-behavioral). The maintainer (dayfine) opened **PR #1753** (`feat/concentration-0.30-goldens`, +160/-58, 9 files) at 01:49Z — re-pins the **8 long-only regression goldens** from `max_position_pct_long 0.14 → 0.30` (the production default), aligning the research basis with production; authorized by the user on the broad top-3000 WF-CV **ACCEPT** (ledger `2026-06-25-capacity-concentration-broad`). Not a live-behavior change — production already runs 0.30; the goldens had been overriding *down*, mis-stating production. No code change (8 `.sexp` + 1 docs note). Full QC pipeline: qc-structural **APPROVED** (H1–H3 exit 0, 303 checks; P1–P6 mostly NA (no `.ml/.mli`), A1–A3 PASS — scope = exactly the 8 goldens + 1 doc, no core/drift; quality 5), qc-behavioral **APPROVED** (production default 0.30 confirmed at `portfolio_risk.ml:45`; all 8 golden diffs consistent with the documented per-window table; 3 sp500 goldens GHA-reproducible (CSV store), 5 broad goldens honestly flagged author-verified/warehouse-gated; S*/L*/C*/T* NA — data re-pin, spine untouched; quality 5; 1 non-blocking follow-up: `goldens-small/*` smoke variants still at 0.14). All 3 merge gates green at tip `aac9c283` (CI build-and-test + perf-tier1-smoke SUCCESS; mergeable_state clean) → **auto-merged via squash (#1753 → main `3660ff38`)**. Audit `dev/audit/2026-06-26-concentration-0.30-goldens.json` (overall APPROVED, score 5, rework 0). No track row drifted (the PR touched no `dev/status/*` file). Since the 06-25-run2 index update the maintainer also merged docs/experiment/ops PRs #1745–#1752 (broad top-3000 concentration WF-CV ACCEPT at 0.30 #1751, capacity-basis reframe, laggard-cadence surface, memory refreshes) — all `dev/notes`/`dev/experiments`/`dev/agent-memory`, no track-status drift. No other orchestrator-dispatchable work: harness/cleanup backlogs empty; ops-data EODHD-absent + data-gaps unchanged → sentinel skip; remaining feature tracks data-/human-/LOCAL-gated. Health CLEAN (status-integrity + index-size + no-python exit 0 live); main CI GREEN; 0 open ci-red issues. Prior run note (28149400545, 06-25 run 2): ACTIVE PASS, 2 subagents — QC'd + auto-merged #1743 (snapshot-dir mode), score 4; main was GREEN on `1455beec`.)

## Active + complete tracks

Each row: one line; deeper task detail in the linked status file.
"Next task" = top-of-queue concrete item from that file's Next Steps.

| Track | Status | Owner | Open PR(s) | Next task |
|---|---|---|---|---|
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
| [optimal-strategy](optimal-strategy.md) | MERGED | — | — | — |
| [all-eligible](all-eligible.md) | MERGED | — | — | — |
| [support-floor-stops](support-floor-stops.md) | MERGED | — | — | — |
| [short-side-strategy](short-side-strategy.md) | IN_PROGRESS | feat-weinstein | — | #1659 short-sleeve budget (default-off) MERGED; next: LOCAL sleeve-fraction screen → WF-CV → grid before default flip `[non-blocking]` |
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
| [simulation](simulation.md) | IN_PROGRESS | feat-backtest | — | stale-exit promotion grid now runnable via WF-CV (#1491/#1494); M5 walk-forward + tuner catch-all items |
| [trade-autopsy](trade-autopsy.md) | MERGED | — | — | — |
| [stage3-hysteresis](stage3-hysteresis.md) | MERGED | — | — | — |
| [experiment-platform](experiment-platform.md) | IN_PROGRESS | feat-backtest | — | force-exit-off grid REJECTED for promotion (#1503); single-dial surface exhausted; next: continuation-buy recheck on top-3000 (data-gated) |
| [experiments](experiments.md) | MERGED | — | — | — |
| [tuning-methods](tuning-methods.md) | PENDING | feat-backtest | — | Step 0 done; steps 1-3 demoted (surface is the bind); component-decomposition objective next |
| [tuning](tuning.md) | IN_PROGRESS | feat-backtest | — | M1 complete (5/5 deliverables); M2 qNEHVI next (awaiting maintainer enable-commit per #1327) |
| [weekly-snapshot](weekly-snapshot.md) | IN_PROGRESS | feat-weinstein | — | M6.6 bin (#1588) + first baseline (#1598) + C2 test (#1596) all MERGED; next: live-cycle (DATA_SOURCE/cron/alerts/state-durability, human-gated) |
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
