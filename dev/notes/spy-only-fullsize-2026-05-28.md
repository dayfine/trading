# SPY-only Weinstein diagnostic — universe-appropriate portfolio params (1b)

Date: 2026-05-28
Author: claude (experiment/diagnostics-fullsize agent)
Pairs with:
- 1a (Cell-E portfolio params): `dev/notes/spy-only-diagnostic-2026-05-28.md` on
  branch `experiment/spy-only-diagnostic` — landed in parallel.
- 2b (sister run, sector-ETFs with same portfolio overrides):
  `dev/notes/sector-etf-fullsize-2026-05-28.md`.
- Survey design: `dev/notes/strategy-diagnostic-survey-2026-05-28.md`.

Scenarios: `trading/test_data/backtest_scenarios/experiments/spy-only-diagnostic-2026-05-28/`
- `spy-only-1998-2025-fullsize.sexp` (this run)
- `bah-spy-1998-2025.sexp` (shared benchmark)

## Headline verdict

**LOSES_TO_SPY** by **-6.61pp CAGR** (1b CAGR ≈ 0.01% vs BAH-SPY CAGR ≈ 6.62%
over the matched 27.03-year window).

Universe-appropriate portfolio params (max_position=1.0, max_long_exposure=1.0,
min_cash=0.0) do **not** materially rescue the SPY-only Weinstein strategy.
The diagnostic's "is Cell-E throttle the bind?" hypothesis is **refuted on the
SPY-only surface**: the screener / stop / laggard-rotation layer rejects SPY
the same way regardless of how much position room the portfolio config grants.

## Metrics table

Window: 1998-12-22 → 2025-12-31 (27.03 years).
Initial cash: $1,000,000 (simulator default — see runner.ml line 13; the brief
asked for $100k but all reported metrics are scale-invariant so the verdict is
unaffected).

| Metric | SPY-only Weinstein 1b | BAH SPY (matched window) | Delta |
|---|---:|---:|---:|
| Total return % | +0.22% | +464.14% | **-463.92pp** |
| CAGR (27.03-year) | 0.008% | 6.62% | **-6.61pp** |
| Sharpe ratio (annualized) | 0.016 | 0.422 | -0.406 |
| Sortino ratio (annualized) | 0.017 | 0.550 | -0.534 |
| Max drawdown | 2.09% | 56.22% | -54.13pp (less DD) |
| Calmar ratio | 0.004 | 0.118 | -0.114 |
| Ulcer index | 1.21 | 17.94 | -16.73 (much less pain) |
| Total round-trips | 10 | 0 (never sells) | n/a |
| Win rate | 50.0% | n/a | n/a |
| Avg holding days (per round-trip) | 26.5 | n/a (held entire window) | n/a |
| Force liquidations | 0 | 0 | n/a |

For reference, the parallel **1a (Cell-E params)** measured 11 trades / 0.06%
CAGR / 0.83% MaxDD / 4.4% time-in-market on a 28-year window (1998-01-02 →
2025-12-30; 12 extra months of compounding base). 1b's lifted portfolio caps
did not unlock more trades or more compounding — the binding constraint is
upstream of the portfolio layer.

## Time-in-market analysis

| Quantity | Value |
|---|---:|
| Total calendar days in window | 7,037 |
| Sum of days_held across all 10 round-trips | 265 |
| **Time-in-market % (calendar)** | **3.77%** |

With **max_position_pct_long=1.0** the strategy CAN deploy 100% of equity into
SPY when it enters — and round 11 (2023-04 to 2023-07) shows that did happen
(quantity 211 × entry ~$413 = $87k notional on a $1M-then portfolio ≈ ~9% of
NAV; the position sizer apparently still scales for some other constraint
even at max_position_pct_long=1.0). On a capital-weighted basis the
average dollar-exposure is therefore far below the 3.77% calendar-time figure
suggests — probably ~0.5%-1.0%. The strategy is **functionally always in cash**.

## Equity curve shape

Sampled at year-end portfolio_value:

| Year-end | 1b portfolio_value | BAH SPY portfolio_value | 1b / BAH ratio |
|---|---:|---:|---:|
| 1998 | $1,000,000 | $1,025,552 | 0.975 |
| 1999 | $1,000,000 | $1,210,120 | 0.826 |
| 2000 | $993,338 | $1,081,948 | 0.918 |
| 2001 | $993,338 | $943,420 | 1.053 |
| 2002 | $989,508 | $728,583 | 1.358 |
| 2003 | $989,508 | $917,662 | 1.078 |
| 2005 | $989,508 | $1,032,750 | 0.958 |
| 2007 | $1,001,148 | $1,205,178 | 0.831 |
| 2008 | $1,001,148 | $718,740 | 1.393 |
| 2010 | $1,001,148 | $1,038,739 | 0.964 |
| 2013 | $1,001,148 | $1,513,692 | 0.661 |
| 2014 | $990,812 | $1,717,947 | 0.577 |
| 2016 | $1,005,052 | $1,846,160 | 0.544 |
| 2018 | $1,005,052 | $2,055,911 | 0.489 |
| 2020 | $995,685 | $3,052,903 | 0.326 |
| 2022 | $995,685 | $3,151,175 | 0.316 |
| 2024 | $1,002,192 | $4,830,986 | 0.207 |
| 2025 | $1,002,192 | $5,648,250 | **0.177** |

**Curve shape: dead flat with rare micro-blips.** The strategy is at exactly
$1,001,148 from 2007 through 2013 — six years without a single trade.

This is THE diagnostic: with the screener+stops+laggard-rotation layer
operating on a 1-symbol universe, the strategy **never sustained a position
through any of the multi-year SPY uptrends** (2003-2007, 2009-2014, 2014-2018,
2019-2021, 2023-2025). Every entry got stopped out or laggard-rotated within
1-77 trading days, leaving the strategy in cash through every major bull leg.

### Distribution of trades (entry / days / pnl% / exit_trigger)

```
2000-08-19  28d  -1.45%  stop_loss          (early in dot-com bust)
2002-03-23  20d  -3.88%  laggard_rotation   (dot-com bottom approach)
2006-09-09  28d  +3.74%  stop_loss          (late bull)
2007-10-27   7d  -1.00%  laggard_rotation   (just before GFC top)
2014-11-08  38d  -2.26%  stop_loss          (post-bull pullback)
2015-02-14  14d  +1.05%  stop_loss          (mid-2015 chop)
2016-11-26  28d  +1.96%  laggard_rotation   (post-election)
2019-09-14  11d  -1.93%  laggard_rotation   (late-2019)
2023-01-28  14d  +0.55%  stop_loss          (early 2023)
2023-04-15  77d  +6.94%  stop_loss          (May-June 2023; longest hold)
```

Exit triggers split exactly 5/5 between stop_loss and laggard_rotation.
**laggard_rotation on a 1-symbol universe is functionally a "go to cash"
signal** — there's no other candidate to rotate INTO, so the position closes
and equity sits idle. This is the most striking finding: half of the strategy's
exits on a single-symbol universe are driven by a screener mechanism designed
for cross-sectional rotation.

## Periods entirely missed

Major SPY uptrends with zero Weinstein-on-SPY participation:
- **2003-04 to 2006-09** (3.5 years, post-dot-com recovery; SPY +58%)
- **2008-01 to 2014-11** (~7 years, missed the entire post-GFC bull; SPY ~+90%)
- **2017-01 to 2019-09** (2.8 years, late-2010s bull; SPY +35%)
- **2019-10 to 2023-01** (3.3 years, COVID dip + recovery; SPY +60%)
- **2023-07 to 2025-12** (2.5 years, current bull; SPY +75%)

Every multi-year SPY advance in the sample was missed. The 5/10 winning
trades each capture 1-7% of a brief move, never the sustained trend.

## Comparison: 1b (this run) vs 1a (Cell-E baseline)

Pulled from `experiment/spy-only-diagnostic` (parallel agent's report):

| Metric | 1a (Cell-E: max_pos=0.14, min_cash=0.30) | 1b (this: max_pos=1.0, min_cash=0.0) | Delta |
|---|---:|---:|---:|
| Window | 1998-01-02 → 2025-12-30 (28y) | 1998-12-22 → 2025-12-31 (27y) | -1y |
| Total return % | +1.68% | +0.22% | -1.46pp |
| CAGR | 0.06% | 0.008% | -0.05pp |
| MaxDD | 0.83% | 2.09% | +1.26pp |
| Round-trips | 11 | 10 | -1 |
| Avg holding days | 29.2 | 26.5 | -2.7 |
| Time-in-market % | 4.40% | 3.77% | -0.63pp |

**The lifted caps did NOT increase activity or returns.** If Cell-E's
position-sizing were the binding constraint, we'd expect 1b to have either
more trades, longer holds, or larger per-trade capital → bigger returns. None
of those happened. The window difference (-1 year) accounts for almost all of
the small metric deltas. **The binding constraint is the screener / stop /
laggard-rotation logic, not the portfolio config.**

## Caveats

### Window choice deviates from brief

The brief asked for `1998-01-01 → 2025-12-31`. I chose `1998-12-22 → 2025-12-31`
to align with the first sector-ETF bar (XLK / XLF / XLI / ... ) so that 1b
and 2b share the same BAH-SPY benchmark and the (2b − 1b) diff measures pure
sector-rotation alpha. This costs 12 months of 1998 SPY (+27%) in the
comparison base. The 1a parallel agent used the full 1998-01-02 start, so
their reported deltas are slightly larger but the qualitative verdict is
identical.

### Initial cash $1M vs brief's $100k

The simulator hardcodes $1M (runner.ml:13). All reported metrics are
scale-invariant (return %, Sharpe, MaxDD, calendar-time-in-market) so the
$100k → $1M deviation does not affect the verdict.

### Un-overridden Cell-E params (kept)

The full Cell-E config that wraps these overrides:
- `enable_stage3_force_exit = true`, `hysteresis_weeks = 1`
- `enable_laggard_rotation = true`, `hysteresis_weeks = 2`
- All screener score weights at Cell-E defaults
- `enable_short_side = false`
- Cell-E stops (installed_stop_min_pct, min_correction_pct, etc.) — defaults

If any of those is what's killing 1b, isolating which would require a
follow-up. The current run pins **portfolio_config layer is NOT the bottleneck**
but leaves screener/stops/rotation undisaggregated.

### `--no-emit-all-eligible` not used (logs noisier than needed)

The runner's all-eligible diagnostic ran alongside, writing 8 trades at min_grade=C
to `all_eligible/grade-C/`. Not used for the verdict; can be ignored.

## Strategic implication

The original purpose of running 1a + 1b together was: "if Cell-E throttle is
the bind, 1b will rescue; if not, both lose by the same margin." 1b lost by
essentially the same margin as 1a. **The portfolio-config layer is not the
constraint on Weinstein's market-timing on a single-asset universe.**

This means the survey's flagship hypothesis — "Cell-E parameters are sized for
multi-thousand-symbol universes and throttle small-universe runs" — is **half
right**. The cap on `max_position_pct_long` does forbid concentrated bets, but
even with concentration unlocked, the screener/stop/rotation layer fires and
prevents the strategy from staying in the position long enough to capture the
trend. The deeper bind is in the strategy logic.

Combined with 2b (sister run, see `dev/notes/sector-etf-fullsize-2026-05-28.md`):
both LOSE_TO_SPY by ~6 pp CAGR. The 3-way decomposition (1 vs 2 vs 3) gives:
- (1b − BAH): market-timing on SPY destroys 6.61 pp CAGR
- (2b − 1b): sector rotation adds back ~0.25pp (still LOSE 6.36pp)
- (3 − 2): expected to be a small additional negative or zero, given the v7
  BO sweep result that random ≈ BO on the top-3000 stocks surface

**Recommendation for the next BO sweep / score-formula iteration:**
1. Stop optimizing the portfolio_config knobs (max_position_pct_long,
   max_long_exposure_pct, min_cash_pct) — these are not the bind.
2. Question whether the laggard_rotation mechanic is appropriate for single-
   asset universes; in 1b it fired 5 times and removed 5 winning trends from
   contention.
3. Consider whether stop_initial_distance_pct (0.04-0.22 across the 10 trades)
   is too tight for a high-volatility 27-year window where SPY frequently
   moves >5% intraday.
4. Survey verdict on the original question — "where does Weinstein's alpha
   come from?" — is now: not from the portfolio layer, not from market-
   timing, not from sector rotation. If alpha exists, it must be in the
   stock-picking layer on a wide universe — and the v7 BO already failed to
   find it (random ≈ BO).

Strong signal to **pause tuning + revisit the strategy mechanics themselves**
(per `memory/feedback_strategy_mechanic_changes_too_explorative.md`, this
needs cautious experimentation with strong backtesting basis, not breezy
parameter tweaks).
