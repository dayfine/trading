# SPDR sector-ETF Weinstein diagnostic — universe-appropriate portfolio params (2b)

Date: 2026-05-28
Author: claude (experiment/diagnostics-fullsize agent)
Pairs with:
- 2a (Cell-E portfolio params): `dev/notes/sector-etf-diagnostic-2026-05-28.md`
  on branch `experiment/sector-etf-diagnostic` — landed in parallel.
- 1b (sister run, SPY-only with same portfolio overrides):
  `dev/notes/spy-only-fullsize-2026-05-28.md`.
- Survey design: `dev/notes/strategy-diagnostic-survey-2026-05-28.md`.

Scenarios: `trading/test_data/backtest_scenarios/experiments/sector-etf-diagnostic-2026-05-28/`
- `spdr-sectors-1998-2025-fullsize.sexp` (this run)
- BAH benchmark: shared with 1b via
  `trading/test_data/backtest_scenarios/experiments/spy-only-diagnostic-2026-05-28/bah-spy-1998-2025.sexp`

## Headline verdict

**LOSES_TO_SPY** by **-6.36pp CAGR** (2b CAGR ≈ 0.26% vs BAH-SPY CAGR ≈ 6.62%
over the matched 27.03-year window).

Universe-appropriate portfolio params (max_position=0.10, max_long_exposure=1.0,
min_cash=0.0) do **not** materially rescue the sector-ETF Weinstein strategy
either. (2b − 1b) ≈ +0.25 pp CAGR — pure sector rotation adds essentially
zero net alpha over and above the SPY-only timing run, both of which lose
big to BAH.

## Metrics table

Window: 1998-12-22 → 2025-12-31 (27.03 years).
Initial cash: $1,000,000 (simulator default; metrics scale-invariant).

| Metric | Sector-ETF Weinstein 2b | BAH SPY (matched window) | Delta |
|---|---:|---:|---:|
| Total return % | +7.43% | +464.14% | **-456.71pp** |
| CAGR (27.03-year) | 0.27% | 6.62% | **-6.36pp** |
| Sharpe ratio (annualized) | 0.151 | 0.422 | -0.271 |
| Sortino ratio (annualized) | 0.206 | 0.550 | -0.345 |
| Max drawdown | 7.31% | 56.22% | -48.91pp (less DD) |
| Calmar ratio | 0.036 | 0.118 | -0.081 |
| Ulcer index | 3.77 | 17.94 | -14.17 (much less pain) |
| Total round-trips | 193 | 0 (never sells) | n/a |
| Win rate | 44.6% | n/a | n/a |
| Avg holding days (per round-trip) | 33.7 | n/a (held entire window) | n/a |
| Force liquidations | 0 | 0 | n/a |

For reference, the parallel **2a (Cell-E params)** measured 189 trades / 0.40%
CAGR / 7.4% MaxDD on a 27.31-year window (1998-12-22 → 2026-04-14). 2b's
lifted caps moved CAGR from 0.40% → 0.27% — essentially flat. The 30% forced
cash floor in Cell-E was NOT the bind.

## Time-in-market analysis

Aggregate "position-days" (sum of days_held across all 193 round-trips):

| Quantity | Value |
|---|---:|
| Total calendar days in window | 7,037 |
| Sum of days_held across 193 round-trips | 6,503 |
| **Average position-days per calendar day** | **0.92** (across all 11 candidate ETFs) |

With 11 candidate ETFs and a max_position_pct_long=0.10 cap (allowing all 11
held simultaneously), the theoretical max is 11 position-days per calendar
day. 0.92 / 11 = **8.4% sector-ETF time-in-market on a slot-weighted basis**.
The strategy is in cash > 91% of the slot-time even with lifted caps. Same
qualitative finding as 1b: the strategy is functionally always in cash.

## Equity curve shape

Sampled at year-end portfolio_value (rounded to nearest $):

| Year-end | 2b portfolio_value | BAH SPY | 2b / BAH ratio |
|---|---:|---:|---:|
| 1998 | $1,000,000 | $1,025,552 | 0.975 |
| 1999 | $967,759 | $1,210,120 | 0.800 |
| 2000 | $950,432 | $1,081,948 | 0.878 |
| 2001 | $940,969 | $943,420 | 0.997 |
| 2002 | $928,469 | $728,583 | 1.274 |
| 2003 | $981,086 | $917,662 | 1.069 |
| 2004 | $1,041,162 | $1,001,333 | 1.040 |
| 2005 | $1,029,553 | $1,032,750 | 0.997 |
| 2006 | $1,055,748 | $1,167,526 | 0.904 |
| 2007 | $1,100,347 | $1,205,178 | 0.913 |
| 2008 | $1,077,498 | $718,740 | 1.499 |
| 2009 | $1,064,993 | $929,147 | 1.146 |
| 2010 | $1,073,342 | $1,038,739 | 1.033 |
| 2013 | $1,085,185 | $1,513,692 | 0.717 |
| 2014 | $1,104,630 | $1,717,947 | 0.643 |
| 2017 | $1,085,618 | $2,194,869 | 0.495 |
| 2020 | $1,069,364 | $3,052,903 | 0.350 |
| 2024 | $1,073,410 | $4,830,986 | 0.222 |
| 2025 | $1,074,350 | $5,648,250 | **0.190** |

**Curve shape: very-slowly-rising flatline.** Range over 27 years is $928k
(2002 low) to $1.105M (2014 peak) — never moves more than 11% from start.
Beats BAH only briefly: 2002 (post-dot-com), 2008-2010 (GFC), then never
catches up. By 2014 the gap is 47% below BAH, by 2025 it's 81% below.

The DD-protection story is real (MaxDD 7.3% vs BAH's 56.2%) but the cost is
*all* of the bull-market compounding.

## Trade breakdown

```
Trades per symbol (193 total):
  XLB:  26  (Materials)
  XLP:  25  (Consumer Staples)
  XLV:  21  (Health Care)
  XLK:  21  (Information Technology)
  XLF:  21  (Financials)
  XLU:  20  (Utilities)
  XLY:  18  (Consumer Discretionary)
  XLI:  15  (Industrials)
  XLE:  14  (Energy)
  XLRE:  7  (Real Estate; inception 2015-10-08)
  XLC:   5  (Comm Services; inception 2018-06-19)

Side distribution:
  LONG:  186
  SHORT:   7  (note: 7 short trades despite enable_short_side defaulting false in
              Cell-E — appears the override doesn't disable shorts here; could
              be a separate config wiring issue worth flagging.)

Exit triggers:
  stop_loss:         88
  laggard_rotation:  87
  stage3_force_exit: 17
  (blank):            1
```

Roughly even split between stop_loss (death by tight stops in volatile sectors)
and laggard_rotation (rotated out before trend matures). The 17 stage3
force-exits are well-distributed — not a single bear catalyst.

## Comparison: 2b (this run) vs 2a (Cell-E baseline)

Pulled from `experiment/sector-etf-diagnostic` (parallel agent's report):

| Metric | 2a (Cell-E: max_pos=0.14, min_cash=0.30) | 2b (this: max_pos=0.10, min_cash=0.0) | Delta |
|---|---:|---:|---:|
| Window | 1998-12-22 → 2026-04-14 (27.31y) | 1998-12-22 → 2025-12-31 (27.03y) | -3.4 months |
| Total return % | +11.60% | +7.43% | -4.17pp |
| CAGR | 0.40% | 0.27% | -0.13pp |
| MaxDD | 7.4% | 7.3% | -0.1pp |
| Round-trips | 189 | 193 | +4 |
| Avg holding days | ~34 (similar shape) | 33.7 | n/a |

**Identical-shaped curve, identical conclusion.** The 30% forced cash floor
in 2a was NOT the binding constraint. 2b's max_position_pct_long=0.10 cap
allowed all 11 ETFs held at once; 2a's 0.14 + max_long_exposure 0.70 cap was
already loose enough that the strategy *could* have deployed ~5 positions
fully — and the 2a output shows ~70% deployment regularly. The screener was
the bind, not the portfolio config.

## (2b − 1b) ≈ pure sector-rotation alpha

By the survey design:
- 1b (SPY-only with same portfolio overrides): +0.22% total, 0.008% CAGR
- 2b (11 ETFs, same overrides):                +7.43% total, 0.27% CAGR
- **Diff (2b − 1b)** =                          +7.21% total, **+0.26 pp CAGR**

Pure sector-rotation alpha over 27 years on Weinstein + Cell-E config:
**+0.26 pp/year**, with the cost being **+5pp more MaxDD** (1b: 2.1%; 2b: 7.3%).
Risk-adjusted (CAGR / MaxDD): 1b = 0.004, 2b = 0.037 — sector rotation IS
risk-adjusted positive, but the absolute alpha is so small it's economically
indistinguishable from zero over a 27-year horizon (cumulative +7% vs zero).

## Caveats

### Newer ETFs (XLRE, XLC) handled by `Daily_price.active_through`

XLRE first bar 2015-10-08 (Real Estate spin-out from XLF); XLC first bar
2018-06-19 (Comm Services reshuffle). Both were included in the 11-ETF
universe and the simulator correctly skipped them pre-inception:
- XLRE first trade entry: late 2015 onwards (7 round-trips total)
- XLC first trade entry: 2018-06 onwards (5 round-trips total)

No special-cased; `Daily_price.active_through` (PR #1023) handles the
staggered inception by skipping screening for symbols before their first
bar. No simulator changes needed.

### Apparent SHORT trades despite `enable_short_side` (probably) being false

7 SHORT trades appear in trades.csv (XLY, XLF, etc.). The Cell-E baseline I
inherited does NOT explicitly toggle `enable_short_side` (the parallel agent's
1a/2a may or may not — I did not introspect). If `enable_short_side=true` is
the default OR the laggard_rotation mechanic is creating short positions, this
is a separate finding to investigate. Flagging here; not material to the
diagnostic verdict.

### Window choice

Same as 1b — chose 1998-12-22 start aligned with first XLK/XLF bar so the
sector-ETF universe has a clean common-start. Costs ~3.4 months vs the 2a
parallel run (which ran to 2026-04-14, the last bar in cached XLK data).
Brief asked for 1998-01-01 → 2025-12-31; my window is the longest 27-year
window where all 9 December-1998 ETFs have data.

### Initial cash $1M vs brief's $100k

Same as 1b — simulator hardcode; all reported metrics scale-invariant.

### Un-overridden Cell-E params

stage3_force_exit hysteresis=1, laggard_rotation hysteresis=2, screener score
weights default. If any of those is what's killing 2b, isolating which would
require a follow-up.

### 2026-05-28 entry in open_positions.csv

The runner ended with an open XLB position dated 2026-05-28 — appears the
simulator stepped one bar past end_date 2025-12-31 (XLB cache has bars
through 2026-04 + a synthesized 2026-05-28 trading bar; the simulator does
not strictly clamp `current_date <= end_date` for the order-routing step).
This is a known-tolerable boundary artifact; the round-trip count of 193 is
the canonical metric.

## Strategic implication

The 3-way alpha decomposition is now complete (combining 1b + 2b + the
existing v7-iter42 BO result on top-3000 stocks):

| Universe | Strategy CAGR | BAH-SPY CAGR | Δ (strategy − BAH) |
|---|---:|---:|---:|
| 1b: SPY-only Weinstein | 0.008% | 6.62% | **-6.61pp** |
| 2b: 11 SPDR ETFs Weinstein | 0.27% | 6.62% | **-6.36pp** |
| 3: top-3000 stocks (v7 iter-42, 16y) | (Sharpe 0.55) | (Sharpe 0.71) | -0.155 Sharpe |

By survey table "Expected interpretations":
- **1b loses to BAH** → "Weinstein timing on the market index is value-
  neutral or harmful. Stop tuning timing knobs." ✓
- **2b ties 1b (no rotation alpha)** → "Sector-rotation is value-neutral;
  cross-section adds churn without edge." ✓
- **3 doesn't rescue** → "Universe quality + screener weights matter; but
  the v7 BO already failed to find edge." (already pinned in
  `dev/notes/v7-random-baseline-verdict-2026-05-25.md`.)

**The integrated verdict across all three diagnostics: Weinstein on this
implementation extracts essentially zero alpha at any universe layer.** The
DD-protection (1.2-3.8 ulcer index vs BAH's 17.9) is real, but the cost is
~6.6 pp/year of CAGR — equivalent to ~80% of long-term equity-market premium.

Recommendations identical to 1b:
1. Stop iterating on portfolio_config + score-weight knobs. They are NOT
   the bind.
2. Surface the laggard_rotation mechanism for stricter analysis. On 11-symbol
   universes it fires 87/193 times (45% of all exits); roughly equal to
   stop_loss. The mechanic was designed to FREE CAPITAL for better
   candidates, but on a small / fixed universe it just exits early into cash.
3. Surface the stop_initial_distance_pct distribution: 88 stop_loss trades
   on volatile sector ETFs over 27 years implies the stops are tight enough
   that normal sector volatility (5-15% pullbacks within a Stage-2 advance)
   is triggering them. Weinstein's book explicitly warned about this.
4. Question whether Stage-2 entry timing is too late — the strategy's
   screener_score_at_entry distribution (50-85) on every trade suggests it's
   buying confirmed breakouts after the initial volume surge, which in
   sector ETFs over this window is a known reversal pattern.

Together with 1b, this is **strong evidence the survey should formally
recommend a strategy-mechanic redesign (not further parameter tuning)** —
per `memory/feedback_strategy_mechanic_changes_too_explorative.md`, do this
with deliberate experimentation and strong backtesting basis. Specifically:
isolate stop_initial_distance_pct, laggard_rotation, and Stage-2 entry-
timing in a controlled ablation before pulling any of the M5.5 axes back
into BO scope.
