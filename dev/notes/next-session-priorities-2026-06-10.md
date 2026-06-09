# Next-session priorities — 2026-06-10

**Supersedes** `next-session-priorities-2026-06-09.md`. Read this + check main CI
green (`.claude/rules/session-rampup.md`) before dispatching anything.

## TL;DR — the "force-exit-off lever" did NOT survive the confirmation grid

The 2026-06-09 priorities doc's P0 was the confirmation grid for
`enable_stage3_force_exit=false` — the INCONCLUSIVE-POSITIVE lever the 2×2 called
"the first net-positive broad-universe mechanism change in months." **The grid
REJECTS it for promotion.** Full record: `dev/notes/stage3-force-exit-grid-2026-06-09.md`,
ledger `2026-06-09-stage3-force-exit-off-confirmation-grid.sexp` (Reject).

> Ran the on/off surface across 3 cells. **force_exit_off wins only 1 of 3**
> (need ≥2/3): **A** top-3000 2011-26 it dominates — but on only ~1/15 folds;
> **B** sp500-510 deep 2000-10 (dot-com+GFC) it is a **complete no-op**
> (bit-identical across all 11 folds — the S3 force-exit never fires differently
> in a bear-heavy regime); **C** top-1000 2011-26 (same period as A, narrower
> universe) it **reverses** (Sharpe 0.394<0.418, DSR 0.9268<0.9378, 0/15 wins).
> The Cell-A win is **top-3000-breadth-specific + fat-tail-concentrated** — the
> exact single-context-winner pattern the grid exists to catch, and the same
> breadth-reversal signature that sank the laggard re-check.

`enable_stage3_force_exit` **stays default-ON**. force_exit_off remains a
default-off axis (on the frontier in all 3 cells, never *badly* dominated — so
available for future breadth-conditional study, just not a global default).

## What this means strategically
Three consecutive broad-universe mechanism experiments — laggard-disable,
stage2-ma-hold, stage3-force-exit-off — have now all **failed to promote**, each
because the apparent edge was **fat-tail-concentrated on the broadest universe
(top-3000) and did not survive a narrower universe or a deep regime.** The
recurring lesson hardens: **top-3000 aggregate edges are mostly 1-2 monster folds;
the per-fold/cross-breadth evidence is what matters.** Single-dial *additions and
removals* on the Cell-E base are exhausted as a source of durable wins.

## Priorities for next session

**P0 — Continuation-buy re-check on top-3000** (carried from 2026-06-09 §P1; the
last breadth-sensitive ledger verdict not yet re-checked on the broad universe).
Same WF-CV recipe as laggard/force-exit: `enable_continuation_entry {false}` vs
baseline on top-3000-2011 PIT 2011-2026, fork-per-fold. Given the pattern above,
**budget for a likely no-promote** and, if it wins on top-3000, **go straight to
the confirmation grid** (don't record it as a lever first). Recipe template:
`dev/experiments/stage3-force-exit-grid-2026-06-09/spec_cellC.sexp`.

**P1 — Pivot the search away from single-dial Cell-E tweaks.** Three rejections
in a row say the dial-by-dial surface is mined out. The Weinstein-faithful-core
rule (`.claude/rules/weinstein-faithful-core.md`) points at **testing coherent
PRESETS as wholes** (trader vs investor bundles) rather than grafting one dial at
a time — `dev/plans/weinstein-trader-investor-presets-2026-05-31.md` +
`dev/plans/population-search-2026-05-31.md`. Consider standing up the
population-search arm (N parallel preset arms, worst-case-regime objective).

**Defer / closed:**
- `enable_stage3_force_exit=false` — REJECTED for promotion (grid). Closed.
- Further single-dial additions/removals on Cell-E — deprioritize per P1.

## Infra notes that held up
- Confirmation grid is now cheap + repeatable: deep CSV cell (sp500-510, 11 folds)
  runs in **~270s**; top-1000 snapshot cell (15 folds, parallel=2) in **~24 min**;
  top-3000 cell reuses the existing 2×2 + the `snap_top3000_2011` warehouse
  (1.5G, 3015 sym, still on container `/tmp`). Specs/base-scenarios committed under
  `dev/experiments/stage3-force-exit-grid-2026-06-09/` as templates.
- A snapshot warehouse is a **superset** — a narrower-universe cell (top-1000)
  reuses the top-3000 warehouse by just swapping `universe_path`. No rebuild.
- The deep cell needs **no warehouse** (510 sym fits CSV mode; GSPC.INDX covers
  1927+ so the macro gate is live pre-2009).
- Container `/tmp` accumulates `panel_runner_csv_snapshot_*` + `panel_snapshot_test_*`
  orphans (the documented leak) — purge before/after deep runs.

## Live tracks (owners) — see terse `dev/status/_index.md`
- **stage-accuracy / spy-only-reference** (feat-weinstein) — force-exit grid CLOSED here; continuation re-check (P0) sits here.
- **experiment-platform / backtest-perf / simulation / tuning** (feat-backtest).
- **data-foundations** (feat-data) — bars-retention gap.
- **harness / orchestrator / sweep-perf / cleanup** (harness-maintainer).
