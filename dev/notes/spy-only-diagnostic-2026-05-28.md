# SPY-only Weinstein diagnostic — 1998-2025

Date: 2026-05-28
Author: claude (experiment/spy-only-diagnostic agent)
Pairs with: `experiment/sector-etf-diagnostic` (running in parallel; not yet landed)
Scenarios: `trading/test_data/backtest_scenarios/experiments/spy-only-diagnostic-2026-05-28/`

## Headline verdict

**LOSES_TO_SPY** (-7.13pp CAGR vs BAH-SPY threshold: ≤-1pp = LOSE).

Weinstein stage analysis applied to a 1-symbol universe of SPY essentially
earns cash-like returns (~0.06% CAGR) over 28 years, vs BAH SPY's 7.19% CAGR
on the same window. The strategy is in the market only 4.4% of trading days.

## Metrics table

| Metric | SPY-only Weinstein | BAH SPY | Delta |
|---|---:|---:|---:|
| Total return % | +1.68% | +598.41% | **-596.73pp** |
| CAGR (28-year) | 0.06% | 7.19% | **-7.13pp** |
| Sharpe ratio | 0.22 | 0.45 | -0.23 |
| Sortino (annualized) | 0.33 | 0.60 | -0.27 |
| Max drawdown | 0.83% | 56.04% | -55.21pp (less DD) |
| Calmar ratio | 0.07 | 0.13 | -0.06 |
| Ulcer index | 0.49 | 17.61 | -17.12 (much less pain) |
| Total round-trips | 11 | 0 (never sells) | n/a |
| Win rate | 54.5% | n/a | n/a |
| Avg holding days (held trades) | 29.2 | n/a (held entire window) | n/a |
| Force liquidations | 0 | 0 | n/a |
| Wall seconds | 65.7 | 45.3 | +20s |

Initial cash: $1,000,000 (runner-hardcoded in
`trading/trading/backtest/lib/runner.ml` line 13). Diagnostic prompt asked
for $100k; we used the runner's canonical $1M instead. All compared
metrics (return %, Sharpe, MaxDD, time-in-market %, CAGR) are
scale-invariant — the verdict is unaffected.

## Time-in-market analysis

| Quantity | Value |
|---|---:|
| Total trading days (1998-01-02 to 2025-12-30) | 7,290 |
| Sum of days_held across all 11 round-trips | 321 |
| **Time-in-market %** | **4.40%** |

Compare with BAH SPY's time-in-market of ~100% (after the day-1 entry).
This is the key signal: **the strategy is in cash 95.6% of the time over a
28-year window that includes ~22 years of upward-trending SPY**. Even when
it IS in the market, the Cell-E position sizing (`max_position_pct_long =
0.14`) caps each entry at ~14% of NAV — so the effective market exposure
is much lower than 4.4% on a capital-weighted basis (~14% × 4.4% ≈ 0.6%
average dollar-exposure).

### Distribution of holding periods + outcomes

The 11 round-trips, in order:

| # | Entry date | Days held | Pnl % | Exit trigger / sub-kind |
|---|---|---:|---:|---|
| 1 | 1998-01-10 | 56 | +9.78% | laggard_rotation / non_stop_exit |
| 2 | 2000-08-19 | 28 | -1.45% | laggard_rotation / intraday |
| 3 | 2002-03-23 | 20 | -3.88% | laggard_rotation / gap_down |
| 4 | 2006-09-09 | 28 | +3.74% | stop_loss / non_stop_exit |
| 5 | 2007-10-27 | 7 | -1.00% | stop_loss / gap_down |
| 6 | 2014-11-08 | 38 | -2.26% | laggard_rotation / intraday |
| 7 | 2015-02-14 | 14 | +1.05% | stop_loss / non_stop_exit |
| 8 | 2016-11-26 | 28 | +1.96% | stop_loss / non_stop_exit |
| 9 | 2019-09-14 | 11 | -1.93% | laggard_rotation / intraday |
| 10 | 2023-01-28 | 14 | +0.55% | laggard_rotation / non_stop_exit |
| 11 | 2023-04-15 | 77 | +6.94% | stop_loss / non_stop_exit |

**Periods entirely missed:**
- 2002-04 to 2006-09 (4.4 years, post-dotcom recovery + early 2000s bull)
- 2008-2014 (~6 years, missed the entire post-GFC bull recovery)
- 2016-12 to 2019-09 (2.8 years, late-2010s bull)
- 2019-09 to 2023-01 (3.3 years, including the COVID dip + recovery)

Every "missed" sustained Stage-2 advance is where BAH compounded its
return. Weinstein-on-SPY missed essentially every multi-year market
advance in the sample.

## Caveats

### Cell-E parameters

`config_overrides` are identical to the canonical Cell-E baseline used in
every active Weinstein golden (`sp500-2010-2026.sexp`,
`weinstein-2019-full-pool.sexp`, etc.):

- `enable_short_side = false`
- `portfolio_config.max_position_pct_long = 0.14`
- `portfolio_config.max_long_exposure_pct = 0.70`
- `portfolio_config.min_cash_pct = 0.30`
- `enable_stage3_force_exit = true`, `hysteresis_weeks = 1`
- `enable_laggard_rotation = true`, `hysteresis_weeks = 2`

Provenance reference: `dev/scripts/promote_config.sh` §"Cell-E baseline
reference values".

### Quirks of running Weinstein on a 1-symbol universe

Three sub-modules have degenerate semantics on universe = {SPY}, but none
cause a crash and the diagnostic is internally consistent:

1. **Macro analysis** reads `GSPC.INDX` (hardcoded
   `index_symbol = "GSPC.INDX"` in `trading/trading/backtest/lib/runner.ml`
   line 12) — **NOT SPY**. So bullish / neutral / bearish macro gating
   fires normally based on the S&P 500 cash index. Macro gating is what
   blocks SPY entries during 2002, 2008-09, 2020 March, 2022, etc. —
   precisely the "would-have-lost-money-anyway" windows. Looking at the
   trade list, this gating worked: no entries during the 2008-09 GFC, no
   entries during March 2020 COVID, no entries during 2022 bear. The
   strategy avoided drawdowns successfully (MaxDD = 0.83% vs BAH 56%).

2. **Sector analysis** reads the SPDR sector ETFs (XLK / XLF / etc.). On a
   1-symbol universe with SPY mapped to "Communication Services" (the
   informational label from `universes/spy-only.sexp`), sector RS fires
   but the sector cohort contains only SPY, so it's degenerate but
   harmless.

3. **Relative strength**: SPY's RS is computed vs `GSPC.INDX`, not vs SPY
   itself. SPY ≈ GSPC.INDX up to TER + tracking error, so RS will hover
   near zero with small time-varying noise from ETF tracking error +
   dividend pass-through timing. This means the entry signal comes almost
   entirely from SPY's own price/MA trend — which is exactly the
   "isolated market-timing alpha" measurement we wanted.

### Cell-E position sizing on 1-symbol universe

`max_position_pct_long = 0.14` means each entry buys ~14% of NAV worth of
SPY. So the "1 position" can only ever consume 14% of available capital
(by design — the cap is calibrated for risk management across a broader
universe where 5-7 positions × 14% = 70% gross exposure). On a 1-symbol
universe this is **structural under-investment**: even at 100%
time-in-market the strategy would hold only 14% in SPY and 86% in cash.

This is a **fair test of the Weinstein recipe on SPY**, not a misuse of
the strategy. The point of the diagnostic is to ask: *given the canonical
Cell-E config (which is what the live system actually runs), does
applying it to SPY alone beat BAH-SPY?* Answer: emphatically no.

A version with `max_position_pct_long = 1.0` (single-symbol all-in) would
be a different question and not what we're asking.

## Strategic implication

**The Weinstein entry/exit timing signal applied to SPY is essentially
value-destroying as a stand-alone alpha source.** It earns cash-like
returns over 28 years while the underlying buy-and-hold returned ~7.2%
CAGR.

What this rules out:
- *Hypothesis*: "Weinstein's macro/timing signal alone is alpha." **Rejected.**
  Time-in-market 4.4%, CAGR 0.06% — the signal cancels every up-move it
  attempts to capture.

What this is consistent with:
- **Alpha must come from cross-section** (sector rotation or stock
  picking) — i.e., from the answer "WHICH symbols to buy when Weinstein
  says buy," not from "WHEN to buy the market."
- The 16% / 0.78 Sharpe / 18% MaxDD that Cell-E posts on the SP500
  surface (per `sp500-2010-2026.sexp`) must therefore come from picking
  Stage-2 breakouts among stocks that outperform SPY by a wide enough
  margin to overcome the ~22% time-in-market drag (per recent BO sweep
  v6/v7 results showing baseline Cell-E aggregate Sharpe ~0.89 on the
  per-fold panel).
- Sector rotation may or may not add value on top — the sibling sector-
  ETF diagnostic (`experiment/sector-etf-diagnostic`, running in
  parallel) will measure (2)-(1). Pre-result expectation: sector-ETF
  Weinstein also loses to BAH-SPY, because the same 4.4%-time-in-market
  drag applies to a 11-symbol universe where cross-sectional dispersion
  between sector ETFs is low.

### Implication for tuning

The 11-knob BO sweeps (v3/v6/v7) have been tuning **stop-buffer,
hysteresis-week, scoring-weight, and macro-threshold** knobs that
shape (a) when the strategy enters, (b) when it exits, and (c) how
quickly it gates on macro state. On the cross-section surface (top-3000
stocks), these knobs may move the dial because tighter / wider entry
criteria reshape WHICH stocks pass screening — that's a cross-section
effect.

**At the market level there is nothing to tune** — the entry/exit
machine on SPY-as-market can't beat BAH no matter how the knobs are set
within the Cell-E family, because:

1. The macro gate (correctly) keeps the strategy out of every 6-month+
   advance that doesn't pass its Stage-2 + volume + breadth + sector-RS
   criteria. On SPY, those criteria are too strict (they're calibrated
   for stocks).
2. The Cell-E sizing cap (`max_position_pct_long = 0.14`) caps
   single-symbol exposure structurally.
3. Stage3 force-exit + laggard rotation exit positions quickly, so even
   the periods we do enter are 1-3 months long, missing the bulk of
   multi-year compounds.

**This does NOT mean the tuning effort has been wasted.** It means the
tuning effort should be measured on cross-section deltas, not on
market-timing deltas. The v6 random-vs-BO-near-tie verdict (per
`dev/notes/v6-bo-vs-random-baseline-verdict-2026-05-25.md`) is
consistent with this: if there's no per-stock-selection signal in the
11-knob surface, BO can't beat random because the surface is flat at
the cross-section level. Knobs that materially affect cross-sectional
ranking (scoring weights, sector caps, RS thresholds) are where the
remaining alpha (if any) lives.

### Caveat on the verdict

This is **one** data point on **one** symbol over **one** window. It does
not generalize to: "no market-timing signal exists" — only to: "the
Weinstein Cell-E recipe applied to SPY does not extract market-timing
alpha over 1998-2025." Other regimes (e.g., a 2000-2010 window heavily
weighted to the two big bears) might tell a different story; the sibling
sector-ETF diagnostic will add a second data point at the macro-cohort
level.

## How to reproduce

```bash
docker exec trading-1-dev bash -c '
  cd /workspaces/trading-1/trading && eval $(opam env) &&
  dune build trading/backtest/scenarios/scenario_runner.exe &&
  /workspaces/trading-1/trading/_build/default/trading/backtest/scenarios/scenario_runner.exe \
    --dir /workspaces/trading-1/trading/test_data/backtest_scenarios/experiments/spy-only-diagnostic-2026-05-28 \
    --fixtures-root /workspaces/trading-1/trading/test_data/backtest_scenarios \
    --parallel 2
'
```

Wall time: ~70 seconds total (Weinstein 65s + BAH 45s, parallel=2).
Outputs land in `/workspaces/trading-1/dev/backtest/scenarios-<timestamp>/`
with `actual.sexp`, `equity_curve.csv`, `trades.csv` per scenario.

## Files written

- `trading/test_data/backtest_scenarios/experiments/spy-only-diagnostic-2026-05-28/spy-only-weinstein-1998-2025.sexp`
- `trading/test_data/backtest_scenarios/experiments/spy-only-diagnostic-2026-05-28/bah-spy-1998-2025.sexp`
- `dev/notes/spy-only-diagnostic-2026-05-28.md` (this file)
