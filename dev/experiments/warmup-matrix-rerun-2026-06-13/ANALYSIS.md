# Rolling-start matrix re-run under honest warmup semantics — ANALYSIS

**Date:** 2026-06-14 · **Universe:** PIT top-3000-2011 (`snap_top3000_2011`) ·
**Window:** 2011-01-03 → 2026-04-30, 33 starts (stride 170d, jitter seed 42),
n=31 after the 330-day min-window guard · **Benchmark:** GSPC.INDX (price-only,
no dividends — flatters the strategy ~2pp/yr) · **Config:** Cell-E
(0.14/0.70/0.30, force-exit h=1, laggard h=2) · **Default:**
`suppress_warmup_trading=true` (#1566, the new honest default).

This re-runs the *same surface* as the 2026-06-11 first matrix, changing only the
warmup semantics (warmup-trades ON → suppressed), to replace the now
stale-semantics numbers (`project_rolling_start_matrix_first_run`).

## Headline: the warmup running-start was ~all of the apparent edge

| metric | STALE (OFF / warmup-trades, 2026-06-11) | HONEST (ON / suppress, this run) |
|---|---|---|
| Median edge vs GSPC | **+3.2 pp/yr** | **−2.76 pp/yr** |
| Starts beating benchmark | ~57% | **35.5%** (11/31) |
| p10 edge | −16 pp | **−24.2 pp** |
| Worst-start edge | −28 pp | **−49.5 pp** (2022-06-08) |
| Max edge | (n/a) | +107.5 pp (2025-01-20, MTM-inflated) |
| CAGR median | — | 8.45% |
| MaxDrawdown median | — | 35.9% |

**Removing the warmup-window trading swung the median start-date edge by ~6pp,
from +3.2 to −2.76, and cut the beat-rate from 57% to 35%.** The apparent
start-date edge in the first matrix was substantially a measurement artifact —
the strategy entered positions during the 210-day warmup (with warm indicators)
and carried that bull "running start" into the measured window
(`project_warmup_trading_running_start`). Measured honestly (window = window
only), there is **no start-date return edge over buy-and-hold SPX** on the
2011-2026 bull.

Dividend-adjusted (GSPC price-only flatters ~2pp), honest median edge vs
**total-return SPX ≈ −4.8 pp/yr**. This confirms `project_index_beating_structural_bar`
(no robust bull-regime CAGR edge — Weinstein is definitionally winner-touching)
from a cleaner angle than the contaminated first matrix could.

## The dispersion max is not real return (MTM inflation persists)

The +107% edge outlier (2025-01-20: CAGR 117%) has **realized return −21%** — the
AXTI-style terminal-mark inflation (`project_broad_universe_790_mtm_inflated`)
generalizes across recent starts:

| start | MTM CAGR | edge | **realized %** |
|---|---|---|---|
| 2025-01-20 | 117.3% | +107.5 | **−21.0** |
| 2022-06-08 | −35.7% | −49.5 | **−82.1** |
| 2021-02-11 | 8.5% | −2.8 | **−56.5** |
| 2021-10-16 | 13.3% | +3.7 | **−50.3** |
| 2024-08-17 | −15.0% | −27.1 | **−34.7** |

Every post-2020 start has positive-ish MTM but **deeply negative realized** —
the recent-start "wins" are open marks, not banked P&L. The honest banked picture
of recent starts is worse than even the −2.76 median edge suggests.

## Structure

- **Negative-edge starts** now span 2011-12, 2016-18, and 2021-24 (was
  concentrated 2013-2018 in the contaminated matrix). The positive starts
  (2017-04 +8.4, 2018-04 +6.3, 2019-01 +11.5, 2023-01 +14.3, 2023-04 +20.8) are
  scattered, and the largest (2025-01 +107) is MTM-inflated.
- **TimeUnderwater ≈ 84-99.7% everywhere** — NAV spends nearly all its life below
  its running peak (unchanged from the first matrix; not a warmup artifact).
- **MaxDD median 35.9%** (min 26.9, max 82.6) on a bull window with no real bear —
  the strategy's designed DD-defense payoff isn't exercised here.

## Read

This is a **lens, not a verdict**: a single bull window, price-only benchmark, one
universe vintage. But the lens is now honest, and it says the long-only Cell-E
strategy has **no start-date return edge over SPX in a bull regime** — the prior
+3.2pp was warmup contamination. The strategy's case rests on bear-regime tail
defense (the 2000-2011 bear-decade matrix + `project_index_beating_structural_bar`),
NOT bull return-beating. Strategic implication: profit "missing" from long-only is
unlikely to be found by tuning long entries on bull windows; it's on the
short/bear side — motivating the margin & long-short initiative (B in the
2026-06-14 handoff), provided the margin model is built so shorts are measured
honestly.

Artifacts: `matrix-t3k-2011-ON.md` (full per-start table), `PROBE.md` (the
interior-start off/on probe that justified this re-run). Raw log retained in
container `/tmp/warmup-rerun/run.log` (not committed — 335KB of per-tick WARNs).
