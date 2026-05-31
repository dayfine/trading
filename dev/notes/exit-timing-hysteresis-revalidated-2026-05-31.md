# Exit-timing + hysteresis REJECTs re-validated on repaired data — 2026-05-31

**TL;DR.** Both stage3 exit-timing REJECTs (the 9-cell surface of
2026-05-30, and the autopsy-recommended `h2-m02` hysteresis point of
2026-05-29) were originally measured while the `GSPC.INDX` golden floored at
2017, so folds 000-012 (2010-2016) silently traded nothing. With the golden
repaired to 2009 (#1383, issue #1380), all 31 folds now trade — and **both
REJECTs hold and strengthen.** No exit-timing cell that changes behaviour beats
baseline. The GSPC-floor asterisk is removed from both prior ledger entries.

## Why re-validate

`memory/project_gspc_index_golden_2017_floor`: the macro gate blocks all buys
when the index has no data for a date. The golden only covered 2017-2026, so
every `sp500-2010-2026` walk-forward silently tested **2017-2026 only** — folds
000-012 were zero-trade. The exit-timing surface (#1375) and hysteresis (#1366)
REJECTs were both measured on that truncated window. PR #1383 extended the
golden to 2009; this run re-tests the identical surface on the full window.

## Setup

- Spec: `test_data/walk_forward/exit-timing-surface-2026-05-30.sexp` — the
  9-cell surface `hysteresis_weeks {1,2,3} × stage3_exit_margin_pct
  {0.0,0.02,0.05}` + auto-baseline. The hysteresis `h2-m02` point is the
  `(h=2, m=0.02)` cell of this surface (config_hash `9dfc464…`), so **one run
  re-validates both prior entries.**
- Base: `goldens-sp500-historical/sp500-2010-2026.sexp`, Rolling
  test_days=365 step_days=182 → 31 OOS folds.
- Data: container synced to main `d194e79f5` (golden floor 2009-01-02, 4344
  rows). Run `/tmp/sweeps/exit-revalidate`, parallel=4, ~64 min.

## Result — REJECT confirmed and strengthened

**Early folds now trade** (the repair worked): fold-000 (2010)
avg_holding_days 39.2, fold-001 40.7, fold-002 28.0, fold-003 28.4 — all
non-zero, real returns (previously zero-trade). Baseline Sharpe rose
**0.540 (truncated) → 0.6225 (full window)** as the early folds contribute.

| Variant | Sharpe | Calmar | MaxDD % | Frontier |
|---|--:|--:|--:|:--:|
| **baseline** | **0.6225** | **1.479** | **12.42** | **yes** |
| h1 · m=0.0 (no-op) | 0.6225 | 1.479 | 12.42 | yes |
| h1 · m=0.02 (no-op here) | 0.6225 | 1.479 | 12.42 | yes |
| h2 · m=0.0 | 0.6208 | 1.477 | 12.44 | no |
| h2 · m=0.02 *(the autopsy point)* | 0.6208 | 1.477 | 12.44 | no |
| h3 · m=0.0 | 0.6208 | 1.477 | 12.44 | no |
| h3 · m=0.02 | 0.6208 | 1.477 | 12.44 | no |
| h1/h2/h3 · m=0.05 | 0.6206 | 1.476 | 12.44 | no |

**Every cell that changes behaviour is strictly worse than baseline.** The best
non-trivial cell (h2/h3, m=0.0/0.02) is Sharpe 0.6208 vs baseline 0.6225; the
worst (m=0.05) 0.6206. Only the no-op-equivalent cells sit on the frontier with
baseline. Deflated Sharpe is 1.0 for every cell (the surface is essentially flat
and ≤ baseline — the deflation doesn't even bind because nothing *beats*
baseline to deflate).

Stage3 hysteresis + exit-margin are pure drag. On the truncated window the
penalty was 0.54→0.519 (~4%); on the full window it's 0.6225→0.6208 (~0.3%) —
smaller in relative terms because the bull-heavy early folds dilute the stage3
exit events, but still **uniformly negative**. There is no window on which these
knobs help.

## Ledger

New entry `dev/experiments/_ledger/2026-05-31-exit-timing-hysteresis-revalidated.sexp`
(window_id `rolling-2010-2026-365-182-31fold-gspc-repaired`, verdict Reject),
index updated. This **removes the GSPC-floor asterisk** from:
- `2026-05-30-exit-timing-surface.sexp` (the 9-cell surface — superset)
- `2026-05-29-stage3-hysteresis-wf-cv.sexp` (the `h2-m02` point — a cell here)

Both prior verdicts stand: the only thing the truncation changed was the
*magnitude* of the penalty, never its sign.

## Deep 2000-2026 confirmation — the rejection is multi-regime

The 2010-2026 window above is one macro era (post-GFC bull + COVID dip). To meet
the `.claude/rules/promotion-confirmation.md` macro-regime standard, the same
9-cell surface was re-run on the **full 2000-2026 cycle** (dot-com bust + GFC,
point-in-time-2000 universe incl. delistings, 51 folds — early folds 2000-2002
traded, avg_holding_days 32.5/43.9/17.8). Ledger
`2026-05-31-exit-timing-deep-2000-2026.sexp`.

| Variant | Sharpe | Calmar | MaxDD % | Frontier |
|---|--:|--:|--:|:--:|
| **baseline** (= h1·m=0.0) | **0.6806** | **2.038** | **11.14** | **yes (only)** |
| h1 · m=0.02 | 0.6798 | 2.037 | 11.15 | no |
| h1 · m=0.05 | 0.6723 | 2.032 | 11.15 | no |
| h2 · m=0.0/0.02/0.05 | 0.6662 | 2.019 | 11.15 | no |
| h3 · m=0.0/0.02/0.05 | 0.6649 | 2.015 | 11.16 | no |

Baseline is the **only** frontier cell, and the drag is **larger** than on the
bull window: h2/h3 lose ~2.3% of Sharpe (0.6806→0.665) where 2010-2026 lost only
~0.3%; the result is monotone — more hysteresis and more margin both hurt more.
This is the mechanism working as expected: stage3 false-exit costs are largest in
bear regimes (2000-02, 2008), so deferring the exit (hysteresis) or widening the
margin hurts most exactly when the slow 30-week MA is most protective. The logical
prediction below held empirically — **the deep cell deepened the rejection.**

(Baseline Sharpe 0.6806 reconciles with the early-admission deep baseline 0.68063
— same deep dataset, same baseline config, an independent cross-check.)

## Caveat — now closed

A mechanism that loses on the easy bull window was never going to be rescued by
adding the dot-com bust + GFC; the deep run confirms it directly. Both REJECTs
(exit-timing #1375, hysteresis #1366) now stand on a genuinely multi-regime
basis.
