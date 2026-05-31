# SPY stage-timing — trade-by-trade analysis (2009-2026, investor preset)

The realized trades of the SPY-only Weinstein strategy (PR #1397, 30-week MA,
long/flat, 2009-06-01→2025-12-31), vs buy-and-hold SPY. This is the empirical test
of the capital-preservation/compounding thesis: *does avoiding drawdowns compound
into a higher final NAV?* Answer: **only when the strategy re-enters lower than it
exited — which the 30-week MA achieves on sustained bears but not on fast V-dips.**

## Headline

| | BAH-SPY | Stage-timing (investor) |
|---|--:|--:|
| Total return | 619.1% | 317.9% |
| Final NAV ($1M start) | $7.19M | $4.18M |
| CAGR | 12.63% | 9.01% |
| Sharpe | 0.78 | 0.77 |
| Sortino (ann.) | 1.15 | 1.08 |
| **Calmar** | 0.37 | **0.48** |
| **MaxDD** | 34.0% | **18.8%** |
| Trades | 0 | 10 closed (+1 open), **70% win** |

Nearly identical Sharpe; stage-timing wins drawdown/Calmar decisively but trails
on final NAV. (Note: the round-trip win rate is **70%**, not the 10% first
reported — that was a misread of the metric.)

## The trades (portfolio all-in, so NAV ≈ shares × SPY price)

| # | Entry→Exit | SPY in→out | P&L | Note |
|---|---|---|--:|---|
| 1 | 2009-08→2010-06 | 98.65→108.19 | +9.7% | stopped out |
| 2 | 2010-10→2011-08 | 114.99→114.07 | −0.8% | |
| 3 | 2012-01→2015-08 | 128.20→198.50 | +54.8% | big bull leg |
| 4 | 2016-04→2018-12 | 204.35→269.46 | +31.9% | |
| 5 | 2019-03→2020-03 | 280.44→284.64 | +1.5% | exited into COVID |
| 6 | 2020-07→2022-02 | 314.31→443.73 | +41.2% | |
| 7 | 2022-12→2022-12 | 402.25→379.23 | −5.7% | 17-day whipsaw |
| 8 | 2023-01→2023-03 | 403.66→390.50 | −3.3% | SVB whipsaw |
| 9 | 2023-04→2023-10 | 412.81→425.98 | +3.2% | |
| 10 | 2023-11→2025-03 | 455.07→562.83 | +23.7% | |

7 winners / 3 losers. Final NAV $4.18M (incl. an 11th position held long into
year-end 2025).

## The gap analysis — exit price vs the NEXT entry price (the 80/60 test)

Re-enter **lower** = captured the round-trip (capital compounds). Re-enter
**higher** = whipsaw: gave up the gap AND sat in cash through the recovery.

| Gap | Exit→next Entry | Result | Regime |
|---|---|--:|---|
| 1→2 | 108.19→114.99 | +6.9% higher ✗ | 2010 flash crash |
| 2→3 | 114.07→128.20 | +12.4% higher ✗ | 2011 debt ceiling |
| 3→4 | 198.50→204.35 | +2.9% higher ✗ | 2015-16 correction |
| 4→5 | 269.46→280.44 | +4.1% higher ✗ | 2018-Q4 selloff |
| 5→6 | 284.64→314.31 | +10.4% higher ✗ | COVID: dodged −22% (bottom 222) but missed the 222→314 snap-back |
| 6→7 | 443.73→402.25 | **−9.3% LOWER ✓** | **2022 bear — thesis works** |
| 7→8 | 379.23→403.66 | +6.4% higher ✗ | late-2022 chop |
| 8→9 | 390.50→412.81 | +5.7% higher ✗ | SVB Mar-2023 |
| 9→10 | 425.98→455.07 | +6.8% higher ✗ | 2023 summer dip |

**8 of 9 re-entries were higher (whipsaw); 1 was lower (the sustained 2022 bear).**

## Interpretation

The compounding thesis is correct in principle and fires exactly once — the 2022
*sustained* bear, the regime Weinstein designed for. The other 8 dips were **fast
V's**; the 30-week MA lags ~7 months, so it confirmed re-entry *after* the bounce
→ re-entered higher and missed the recovery from cash. COVID is the canonical
failure: correctly dodged the −22% fall but missed the entire 222→314 rebound. In
a bull-with-fast-dips window, that missed-upside-in-cash costs more than the
drawdown protection saves → final NAV trails BAH despite half the MaxDD.

## What this motivates (pre-registered hypotheses)

1. **10-week trader preset.** A faster MA confirms re-entry sooner → re-enters
   closer to the V-bottom → should flip several of the 8 whipsaws toward the
   favorable round-trip. Test investor (30wk) vs trader (10wk) on this same SPY
   testbed. (`dev/plans/weinstein-trader-investor-presets-2026-05-31.md`)
2. **Deep 2000-2026 window.** Two *sustained* 100→50→100 bears (dot-com −49%, GFC
   −57%) — the 1-of-9 favorable case should become the norm there. Predict the
   final-NAV gap vs BAH narrows hard or flips.

Run dir (reproducible): `scenario_runner --dir <{spy-only-stage2, -bah}>` on the
`feat/spy-only-strategy` build.
