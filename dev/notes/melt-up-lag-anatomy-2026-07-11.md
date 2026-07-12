# Melt-up-lag anatomy — yearly NAV vs SPY TR, trade-level (2026-07-11 PM)

User-driven drill-down on the honest-tradeable record run (top-3000 PIT
2000-2026, end 2026-06-26, scenarios-2026-07-11-195158). Methodology: yearly
return = year-end `portfolio_value` ratio from `equity_curve.csv` (NAV = cash
+ open MTM, so unrealized appreciation counts in-year); SPY = adjusted-close
year-end ratio (total return).

## Yearly gap table (strategy − SPY TR, pp)

Worst: **2024 −21.8, 2019 −21.6, 2023 −20.9**, 2013 −14.2, 2016 −13.4,
2012 −12.8, 2010 −12.4, 2006 −11.0.
Best: 2026 +108.3, 2020 +56.6, 2007 +36.0, 2025 +26.9, 2008 +25.1,
2004 +23.0, 2015 +22.6, 2002 +15.9. (Full table reproducible from the
equity curve; strategy wins every SPY-down year.)

## Decomposition of the worst three

- **2019 (+9.6 vs +31.2)** — churn, no monster: 65 entries, 37/64 exits were
  ≤3-week stop-outs (−$1.2M ≈ −15% of NAV); biggest winner ARQL +$0.64M.
- **2023 (+5.3 vs +26.2)** — monsters unrealized: realized book NET −$3.0M
  (39 whipsaws, −$3.4M); year saved by ~+$4.1M unrealized MTM on SKYW
  (entered Mar) + BVN (entered Aug).
- **2024 (+3.1 vs +24.9)** — payback year: realized +$5.6M is just banking
  SKYW/BVN/MKSI whose marks were already in year-start NAV (MTM residual
  −$4.75M); −$3.4M fresh whipsaw tax; no new monster.
- Cross-year check (the user's attribution concern): 2023+2024 combined =
  strat +8.6% vs SPY TR +57.6% — fixing year attribution moves pnl between
  the years but does not rescue the lag; the SKYW+BVN pair (+$8.3M gross)
  barely covered two years of churn tax (−$6.8M).
- **Control 2021 (won +12.6pp)**: same churn structure (33 stop-outs,
  −$3.6M) but winners paid +$16.1M in-year.

## Second-tier lag years — same law, milder dose

2010/2012/2013/2016 all print the no-monster signature: biggest banked
winner +$0.06-0.7M, 13-21 whipsaw stop-outs, realized ≈ 0, NAV ≈ flat.

**Unified law: yearly sign vs SPY = (did a fat-tail monster pay this
calendar year?) − (constant whipsaw premium: ~30-39 stop-outs, −6 to −16%
of NAV, EVERY year).** Monsters pay episodically; the premium is annual.

## Why mega-caps never carry the strategy in melt-ups

Mag7 participation over 26y: 9 trades, all scratches (MSFT 6 days in 2023;
NVDA never held through its 2023-24 10×). Two mechanisms, both verified in
`trade_audit.sexp` (which logs skipped near-misses with `reason_skipped`):

1. **When mega-caps DO print textbook fresh signals, they pass the screen
   and die at `Insufficient_cash`.** NVDA made the final candidate cut 6
   times (2003, 2010, 2012, 2021; score 70-75, grade A, Stage-2 week 1-2) —
   cash-skipped every time. MSFT 2023 same. The book runs 89-99% deployed;
   mid-cycle mega-cap signals find the cash already committed. This is
   capture-monster #2 (capacity at signal) with named specimens.
2. **NVDA-2023 (the 10×) never made the cut at all — faithfully.** Stage 2
   from 2023-01-20 (stage_dump, prior-chained), so the fresh window
   (early_stage2_max_weeks ≤4) was late-Jan→mid-Feb. In that window volume
   showed NO expansion (Jan-23 avg daily 472M vs 505-625M prior months,
   ratio ~0.9-1.1 — mega-cap accumulation grinds, it doesn't spike) and the
   2022 decline left heavy overhead resistance (anti-virgin-territory). Both
   core cascade criteria scored it below the tied-at-70/75 post-bottom
   small-cap cohort. By the May earnings gap it was Stage-2 week 17 = stale.

**The melt-up lag is not a screener bug**: Weinstein's criteria (volume
expansion, virgin territory, freshness) are calibrated for explosive
small/mid breakouts — a signature mega-caps essentially never print. The
strategy owns a different asset class than cap-weighted SPY; in
narrow-leadership tapes that difference IS the gap.

## Forward guidance

- Re-confirms the **P1b barbell/sleeve direction** as the answer to melt-up
  years (their carry years are exactly 2019/2023/2024) — NOT screener
  changes (entry-selection is closed with power).
- Strengthens the open **decision_audit Phase-2** follow-up (forward-return
  counterfactual of cash-rejected vs funded): NVDA×6 + MSFT sit in the
  cash-rejected pile; the earlier "selection FAITHFUL" verdict measured
  captured-feature predictability, not the forward returns of the rejected.
- The whipsaw premium (~30-39 stop-outs/yr) is the strategy's insurance
  cost; stop-tuning is closed (structural, not fixable) — do not reopen.
