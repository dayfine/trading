# Stage-3 force-exit OFF — promotion-confirmation grid — 2026-06-09

**P0 from `next-session-priorities-2026-06-09.md`.** The 2026-06-09 2×2
(`stage-2x2-2026-06-09.md`) flagged `enable_stage3_force_exit=false` (defer exits
to the trailing stop) as the **sole Pareto-frontier cell** on a top-3000 2×2 WF-CV
and the "first net-positive mechanism change on the broad universe in months —
and it's a *removal*." It was recorded **INCONCLUSIVE-POSITIVE**, not promotable:
the per-fold win-count was only 1/15 (the aggregate edge was concentrated). Per
`.claude/rules/promotion-confirmation.md`, a single-surface ACCEPT-candidate must
clear a **confirmation grid** before any default flip.

This note is that grid.

## Grid design (3 cells, period × universe diversity, incl. deep macro regime)

Surface in every cell: **baseline (force-exit ON, canonical Cell-E) vs
`enable_stage3_force_exit=false`**. Rolling annual folds (test=365, step=365),
fork-per-fold WF-CV, ranked with `rank_variants` (Pareto + Deflated Sharpe).

| Cell | Universe | Period | Macro regime | Bars |
|---|---|---|---|---|
| **A** | top-3000-2011 PIT (3015 sym) | 2011-2026 (15 folds) | post-GFC bull | snapshot (reused from the 2×2) |
| **B** | sp500-historical-2000 PIT (510 sym, delisting-aware) | 2000-2010 (11 folds) | **dot-com bust + GFC** | CSV (GSPC.INDX covers 1927+) |
| **C** | top-1000-2011 PIT (1000 sym) | 2011-2026 (15 folds) | post-GFC bull (narrower breadth) | snapshot (reused `snap_top3000_2011` superset) |

Cell B is the mandatory macro-regime-diverse cell. Cell C is the period-matched
breadth contrast to A (same window, ⅓ the universe).

## Results

| Cell | variant | Sharpe | Calmar | Return % | MaxDD % | DSR | folds differing | per-fold Sharpe wins |
|---|---|---|---|---|---|---|---|---|
| **A** top-3000 | baseline | 0.643 | 1.382 | 12.95 | 14.79 | 0.9964 | — | — |
| **A** top-3000 | **force_exit_off** | **0.679** | **1.631** | **13.07** | **14.74** | **0.9977** | ~1/15 | 1/15 |
| **B** deep | baseline | 0.884 | 2.262 | 17.89 | 11.32 | n/a | — | — |
| **B** deep | **force_exit_off** | 0.884 | 2.262 | 17.89 | 11.32 | n/a | **0/11 (identical)** | 0 (all ties) |
| **C** top-1000 | baseline | **0.418** | **0.722** | 10.04 | 18.68 | **0.9378** | — | — |
| **C** top-1000 | force_exit_off | 0.394 | 0.711 | 10.03 | **18.26** | 0.9268 | 2/15 | 0/15 |

### Cell A (top-3000, 2011-2026) — WIN, but thin
`force_exit_off` **dominates** baseline on all four aggregate axes and is the sole
frontier cell (DSR 0.9977 > 0.9964). But this is the original surface, and the
edge rests on **~1 of 15 folds** — the other ~14 tie. Fat-tail-concentrated.

### Cell B (deep dot-com + GFC, sp500-510) — NO-OP
`force_exit_off` is **bit-identical** to baseline across **all 11 folds** (returns
82.6 / -5.1 / 26.4 / … MaxDD 6.1 / 16.6 / …). The runs are non-degenerate (real
trading, varied per-fold P&L), so this is not a zero-trade/data-floor artifact —
it is a genuine no-op: **the Stage-3 force-exit never altered an exit in a
bear-heavy regime.** The trailing stop and the macro gate (SPY Stage-4 during
2000-02 and 2008 blocks buys; positions get stopped out before reaching a
Stage-3 top) do all the exiting. Removing the force-exit is therefore *inert
exactly where you'd worry about crash protection* — reassuring for a removal, but
**no positive vote**.

### Cell C (top-1000, 2011-2026) — REVERSES A
Same window as A, ⅓ the universe → `force_exit_off` is **slightly worse**: lower
Sharpe (0.394 vs 0.418), Calmar (0.711 vs 0.722), DSR (0.9268 vs 0.9378); only
MaxDD is marginally better (18.26 vs 18.68). Both on the frontier. Only **2 of 15
folds even differ** (fold-001, fold-007), and both lean baseline on Sharpe →
**0/15 Sharpe wins, gate FAIL**. In fold-007 the off-variant has *higher* return
(18.1 vs 17.7) and *lower* MaxDD (9.1 vs 15.5) but lower Sharpe (more volatile
path) — i.e. the one fold that moves is a Sharpe artifact, not a clean loss.

## Verdict — REJECT for promotion; keep `enable_stage3_force_exit` DEFAULT-ON

`force_exit_off` wins **1 of 3 cells** — it fails the strong-majority bar (≥2/3).
The decision rule requires a value robust across the grid; this one is **not**:

- The Cell-A win is **top-3000-breadth-specific and fat-tail-concentrated**
  (~1/15 folds).
- Cell B says the mechanism is **inert** in the deep regime — neither helps nor
  hurts.
- Cell C, the period-matched breadth contrast, **reverses** the sign.

This is the exact single-context-winner pattern the grid exists to catch, and the
**same breadth-reversal signature** that sank the laggard re-check
(`project_laggard_broad_recheck`: top-1000 "reversal" was fat-tail noise; the
broad top-3000 result was the outlier). Promoting on the top-3000 surface would
have repeated the continuation-combined-axis (#1366) / early-admission
(2026-05-31) failures.

**`enable_stage3_force_exit` stays default-ON.** `force_exit_off` remains a
default-off **axis** (it's a legit config knob, never *badly* dominated in any
cell — on the frontier in all three — so it's available for future
breadth-conditional study, just not a global default). `experiment-flag-discipline`
R3 is unsatisfied: no grid-robust ACCEPT.

### Honest reframing of the 2×2 headline
The 2026-06-09 note called this "the first net-positive mechanism change on the
broad universe in months." The grid demotes that: it is a net-positive change
**on top-3000 only**, driven by 1-2 folds, and does not survive a universe or
regime change. The through-line from the priorities doc still holds — *breadth +
simplicity beats adding dials* — but "remove the force-exit" is **not** the
durable win it looked like on the single surface. The S3-exit-timing dials were
rejected because that exit is whipsaw-prone; deleting it helps only at top-3000
breadth and only in the tail.

## Artifacts
- `dev/experiments/stage3-force-exit-grid-2026-06-09/` — specs + base scenarios +
  per-cell `walk_forward_report.md` + `aggregate.sexp` (cells B, C). Cell A is the
  existing `dev/experiments/stage-2x2-top3000-2026-06-09/`.
- Ledger: `2026-06-09-stage3-force-exit-off-confirmation-grid.sexp` (Reject).
- Supersedes the promotion path of `2026-06-09-stage3-force-exit-off-top3000`
  (Inconclusive) — that entry stands as the single-surface record.
