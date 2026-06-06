# Macro-bearish held-exposure trim — grid, cliff, trade-by-trade, verdict

**Date:** 2026-06-06/07
**Mechanism:** PR #1464 (merged, default-off). On a Bearish-macro screening day,
cap held LONG exposure at `macro_bearish_max_long_exposure_pct` of portfolio
value, trimming weakest-RS first. `cap=0` = full flat (all cash) on Bearish.
**Intuition tested (user):** exit early on a confirmed bear tape → preserve
capital + reserve dry powder for re-entry (via the normal Stage-2 screen),
betting that beats the missed-gain opportunity cost.
**Verdict: REJECT for default promotion** — not robust across breadth/horizon;
the apparent SP500 win was a no-V window + survivorship inflation. Mechanism is
now well-understood (below). Stays default-off as a `Variant_matrix` axis.

## 1. SP500 core grid (CSV mode, 510-sym)

DEEP = PIT-2000 SP500 2000-2026; BULL = PIT-2010 SP500 2010-2026.

| cap | DEEP ret% / MaxDD% / Calmar | BULL ret% / MaxDD% / Calmar |
|-----|-----|-----|
| baseline | 917.9 / 37.3 / 0.25 | 237.6 / 17.5 / 0.44 |
| 0.0  | 1233.8 / 27.1 / 0.38 | 327.6 / 21.8 / 0.43 |
| 0.175| 665.1 / **64.6** / 0.12 | 350.1 / **58.3** / 0.17 |
| 0.35 | 1021.3 / 29.0 / 0.33 | 312.0 / 20.2 / 0.45 |
| 0.525| 720.7 / 37.4 / 0.22 | 247.5 / 17.9 / 0.44 |

On SP500, cap=0 looked like a deep Pareto win (return↑ + DD↓) — this is what we
later showed to be misleading (§4).

## 2. Cliff map (DEEP SP500, intermediate caps) — the force-liq resonance

| cap | ret% | MaxDD% | force-liq | ulcer |
|-----|-----|-----|-----|-----|
| 0.0/0.05 | 1233.8 | 27.1 | 3 | 7.8 |
| 0.10 | 973.7 | 25.4 | — | — |
| 0.15 | 1301.7 | 27.9 | — | — |
| **0.175** | 665.1 | **64.6** | **70** | **41.3** |
| 0.20 | 853.5 | 27.4 | — | — |
| 0.25 | 502.8 | 31.2 | — | — |
| 0.30 | 482.3 | 28.4 | — | — |
| 0.35 | 1021.3 | 29.0 | 2 | 10.4 |

**Driver = force-liquidation resonance.** At intermediate caps the trim holds
*just enough* residual long to keep breaching the ~60%-portfolio-drawdown
circuit breaker → liquidate → rebuild on the macro flip → breach again. 0.175 hit
**70 force-liquidations** (vs 2-3 elsewhere), ulcer 41 vs ~10. Full-flat (0.0)
avoids it by exiting cleanly; loose caps (0.35) barely bind. Reproduces on BULL
(0.175 → 58% DD). The cap surface is **jagged and non-robust** — return swings
482→1302 over small cap steps; no smoothly-tunable region.

## 3. top-1000 PIT breadth/horizon (snapshot mode, survivorship-correct)

PIT composition `top-1000-<year>` (delisted-aware; contains the names that later
died). **This is the honest universe** — see §5.

| window | baseline ret/MaxDD/Calmar | cap=0 ret/MaxDD/Calmar | cap=0 |
|---|---|---|---|
| 15y (2011-26) | 29.6 / 42.2 / 0.04 | 730.9 / 65.0 / 0.23 | huge return gain |
| 20y (2006-26) | 228.7 / 22.8 / 0.26 | 111.2 / 26.1 / 0.14 | **strictly worse** |
| 25y (2001-26) | 1683.4 / 33.3 / 0.36 | 1230.8 / 27.1 / 0.40 | mild defensive (ret↓ DD↓) |

cap=0's effect is **not robust** — three start dates, three different signs:
massive win (15y), strictly worse (20y), mild defensive trade (25y). (SP500-deep
showed a Pareto win — a fourth answer.) The baseline ITSELF swings 29.6 → 228.7
→ 1683.4% on the same end date purely by start year — start-date sensitivity
dominates everything (→ the methodology reframe).

## 4. Trade-by-trade — why the impact differs

**15y (cap=0 helps):** the entire swing is the **stop_loss bucket** —
baseline −$1.94M (rides positions down through Bearish tapes into losing stops)
vs cap=0 **+$1.43M** (52 `macro_bearish_trim` exits to cash, +$1.04M, avoid that
losing cohort; the positions it *does* hold exit as *winning* trailing stops).
Trims cluster at real risk-off: 2011 (Euro/downgrade), 2015-16 (China/oil),
2018-Q4, 2022 — sensible, not lucky.

**20y (cap=0 hurts):** same avoided-loss benefit (stop losses −$2.32M→−$1.74M,
+ trims +$0.48M) — BUT the **laggard-rotation winner bucket halved**
($3.35M→$1.86M). Smoking gun in the NAV path:

| date | baseline | cap=0 |
|---|---|---|
| 2009-03-31 (bottom) | $1.09M | $1.07M |
| **2009-12-31** | **$1.49M (+37% off bottom)** | **$1.08M (flat — in cash)** |
| 2021-12-31 | $3.03M | $2.22M |

cap=0 correctly went to cash into 2008 (trims Nov-07→Jun-08) but **missed the
March-2009 V-recovery** — re-entry requires a fresh Stage-2 breakout, which lags
a V-bottom. That single missed rally compounded into the *entire* 20y shortfall.

**The mechanism, definitively:**
- **avoided-loss benefit** — consistent (saves the bear-tape stop-loss cohort in
  every window).
- **missed-recovery cost** — regime-dependent: catastrophic after a sharp V
  (2009), negligible after choppy declines (2011/2015/2018/2022).
- **root weakness:** re-entry is a fresh Stage-2 breakout → structurally lags
  V-bottoms. Going to cash is only "free" when the recovery is slow enough for
  the breakout screen to catch it.
- Net = avoided-loss − missed-V. Positive only when there is no sharp V to miss.
  You cannot know that ex-ante → **not a promotable global default.**

**Path-dependence is even deeper than "regime-dependent" (25y):** on the 25y
path cap=0 was *ahead* through 2002-2010 (the defensive trim helped through
dot-com + GFC) then lost the lead in the 2010-2020 bull (2009-12: cap0 $2.69M vs
baseline $2.12M; 2020-03: $3.87M vs $4.23M). The **same 2009 episode HELPED cap=0
on the 25y path but HURT it on the 20y path** — opposite sign, purely because the
2001-vs-2006 start changed the account state going into 2008. The mechanism's
effect on a specific historical crash is not even sign-stable across start dates.
That is textbook non-robustness and the strongest argument for making start-date
dispersion the primary evaluation lens (§6).

## 5. Survivorship bias — the bigger finding
Same Cell-E config, same 15y window:
- SP500-survivor universe: **237% / 17.5% MaxDD**
- PIT top-1000 (survivorship-correct): **29.6% / 42.2% MaxDD**

Most of the apparent Weinstein "alpha" on SP500-composition/sectors universes is
**survivorship inflation**. The PIT composition series
(`test_data/goldens-custom-universe/composition/top-{500,1000,3000}-{1998..2025}`,
delisted-aware: contains SIVB/FRC/BBBY/LEH/AIG) is the honest substrate, now
tractable via snapshot mode. **Follow-up: re-baseline core strategies + re-check
past ACCEPT/REJECT verdicts on PIT** — some may be artifacts. (Higher value than
the trim itself.)

## 6. Evaluation-methodology learning
MaxDD% misled the cap=0 read (65% off a 12× peak, never below 4.4× stake, vs a
"milder" 42% that dipped below the initial stake). MaxDD is scale-dependent, a
single noisy worst-point, and conflates opportunity-cost vs psychological pain.
Full reframe + scorecard + build plan:
`dev/plans/evaluation-objective-and-metrics-2026-06-07.md`. Headline: make
**start-date robustness** the primary lens; add **capital-relative drawdown**;
demote raw %MaxDD to one input.

## 7. Infra learning — the N=3000 wall is a 1-line cache constant
N=3000 snapshot runs thrash (never finished in 6h locally) because the working
set (1.5 GB on disk) exceeds the decode cache. The cache is
`trading/trading/backtest/lib/panel_runner.ml:22 — let _snapshot_cache_mb = 1024`
(hardcoded 1 GB). N=1000 (544 MB) fits → tractable (~23 min/run). **Cheap fix
(vs the Phase-F mmap rewrite): make `_snapshot_cache_mb` configurable + bump to
~4096 + add a cache hit/miss/decode counter** (clean instrumentation points:
`daily_panels.ml` `_hit_path` / `_load_and_insert` / `_evict_one`; decisive
thrash metric `misses/n_symbols` ≈1 healthy vs ≈n_cycles thrash). Unlocks
PIT-3000 local eval for §5. See `feedback_large_n_needs_snapshot_mode`.

## Status / artifacts
- SP500 grid + cliff: 16 cells, CSV mode, complete.
- top-1000 PIT: 15y + 20y complete; 25y running at writeup time.
- Mechanism PR #1464 merged default-off; **no default flip** (REJECT).
