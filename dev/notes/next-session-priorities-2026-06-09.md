# Next-session priorities — 2026-06-09

**Supersedes** `next-session-priorities-2026-06-07.md`. Read this + check main CI
green (`.claude/rules/session-rampup.md`) before dispatching anything.

## TL;DR — the lever finally turned up, and it's a *removal*

This session built the broad-universe WF-CV infrastructure and used it to run the
first properly-controlled strategy experiments on the honest broad universe. The
standout result:

> **`enable_stage3_force_exit=false` (defer exits to the trailing stop instead of
> the whipsaw-prone Stage-3 force-exit) is the SOLE Pareto-frontier cell on a
> top-3000 2×2 WF-CV** — Sharpe 0.679/Calmar 1.631/MaxDD 14.74/DSR 0.9977 vs
> baseline Cell-E 0.643/1.382/14.79/0.9964. **The first net-positive mechanism
> change on the broad universe in months — and it's turning a mechanism OFF.**

It is **not yet promotable** (modest, concentrated edge — only 1/15 per-fold
Sharpe wins; gate fails). → **P0 below.**

## This session's shipped work (8 PRs, main green throughout)
- **#1491** snapshot-WF runner (`--snapshot-dir`) + **#1494** fork-per-fold for
  N=3000 parallel=1 — together **unblock broad-PIT WF-CV locally** (the recurring
  "data-gated → maintainer-local" blocker on 3+ tracks). N=3000 WF-CV now runs
  ~3 min/fold at ~5.2GB.
- **#1493** laggard re-check top-1000 (Inconclusive) → **#1495** top-3000 (REJECT):
  laggard rotation robustly helps; the top-1000 "reversal" was fat-tail noise.
- **#1499** Stage-2 MA-hold classifier refinement (default-off, from the
  stage_chart oscillation diagnosis).
- **#1500** stage 2×2 WF-CV verdicts: **`enable_stage2_ma_hold` REJECT** (cleans
  the chart but degrades returns — visual coherence ≠ returns);
  **`enable_stage3_force_exit=false` INCONCLUSIVE-POSITIVE** (the lever above).
- **#1497** terse `_index.md` (150KB→5KB) + `index_size_linter` CI cap; **#1498**
  content reconcile.

## Priorities for next session

**P0 — Confirmation grid for `enable_stage3_force_exit=false`.** This is the most
promising strategy change in months and the disciplined next step is the grid
(`.claude/rules/promotion-confirmation.md`): re-run the on/off surface across **≥3
independent period×universe contexts**, including **a deep pre-2009 window
(dot-com + GFC)** and a different universe/snapshot. If `false` beats baseline
(frontier / positive-DSR) across the grid and is never badly dominated → it earns
an ACCEPT and becomes the **first promotable default flip** (the macro/sector gate
+ stop carry the exit; the S3 force-exit is removed). If it's regime-fragile →
keep default-on, record the regime caveat. Recipe: the 2×2 spec
`/tmp/wf_2x2_t3k.sexp` is the template; reuse fork-per-fold WF-CV. Mechanistically
this likely explains **why the 6 S3-exit-timing dials were all rejected** — they
tuned a whipsaw-prone exit instead of deleting it.

**P1 — Continuation-buy re-check on top-3000** (the last breadth-sensitive verdict
from the §4 audit; same WF-CV recipe as laggard).

**Defer / closed:**
- `enable_stage2_ma_hold` — REJECTED (#1500); closed. Chart-cleanness doesn't pay.
- Further single-dial *additions* — the through-line holds: breadth + simplicity
  (removing whipsaw mechanisms) beats adding dials.

## Key artifacts / memory
- `dev/notes/stage-2x2-2026-06-09.md` — the 2×2 detail.
- `dev/notes/laggard-broad-recheck-2026-06-09.md` — laggard breadth ladder.
- `dev/notes/p0-verify-broad-universe-790-2026-06-08.md` — the +790.5% MTM caveat.
- memories: `project_stage_chart_visual_diagnostic` (now carries the WF-CV outcome),
  `project_laggard_broad_recheck`, `project_broad_universe_790_mtm_inflated`,
  `feedback_poll_15min_long_tasks`.

## Live tracks (owners) — see terse `dev/status/_index.md`
- **stage-accuracy / spy-only-reference** (feat-weinstein) — P0 force-exit grid sits here.
- **experiment-platform / backtest-perf / simulation / tuning** (feat-backtest).
- **data-foundations** (feat-data) — bars-retention gap.
- **harness / orchestrator / sweep-perf / cleanup** (harness-maintainer).
