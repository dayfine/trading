# Baseline Backtest Analysis

Generated 2026-04-13 from 3 golden scenarios on 1,654 stocks (sectors.csv universe).
Code version: main@origin at commit rqytmwpz (post #291 merge).

## Scenario Summary

| Scenario | Period | Final Value | Return | Trade P&L | Trades | Win Rate | Sharpe | Max DD |
|----------|--------|-------------|--------|-----------|--------|----------|--------|--------|
| 1 | 2018-01 to 2023-12 | $1,569,627 | +57% | -$14,985 | 77 | 28.6% | 1.28 | 34.0% |
| 2 | 2015-01 to 2020-12 | $4,054,483 | +305% | -$5,510 | 84 | 33.3% | 0.79 | 38.7% |
| 3 | 2020-01 to 2024-12 | $1,268,702 | +27% | +$38,836 | 109 | 47.7% | 1.00 | 38.0% |

Initial cash: $1,000,000. Commission: $0.01/share + $1.00 minimum.
30-week warmup applied before each start date.

**Note:** Results are not fully deterministic due to Hashtbl iteration ordering
in strategy internals (PR #298). Metrics may vary slightly between runs.

## Key Findings

### 1. Stop-loss exits too early — 74% of trades held < 7 days

**258 of 375 total trades** (across all scenarios) were held 0-1 days. This is
the critical finding. The strategy enters on a breakout signal, but the
trailing stop fires almost immediately on most positions.

**Book reference (Ch. 6):** Weinstein's initial stop goes "below the significant
support floor (prior correction low)" — which is typically 5-15% below entry.
He also says "if stop requires >15% risk from entry, prefer other candidates."
Our current `initial_stop_buffer` of 1.02 (2%) is much tighter than what the
book prescribes.

However, widening stops is not automatically better:
- Wider stops mean larger individual losses when they trigger
- The current 2% stop limits per-trade risk but causes frequent whipsaws
- Need to test: does widening to 5-8% improve win rate enough to offset
  the larger per-trade losses?
- The book's approach (support-floor-based, not fixed %) may be the right
  direction — stops should be based on chart structure, not arbitrary buffers

### 2. Trade P&L negative but portfolio gains huge

The portfolio gains massively (+27% to +305%) but closed trade P&L is negative
in 2 of 3 scenarios. This means:
- Positions that remain open at period end carry unrealized gains
- The trading system (entry → stop → exit) nets negative when completed
- The value comes from **holding winners** that haven't triggered stops yet

This raises questions about sustainability — are the unrealized gains just
timing luck (where we sample the portfolio) or a real edge?

### 3. P&L distribution: many small losses, few big wins

| Category | Count | % |
|----------|-------|---|
| Deep loss (< -15%) | 11 | 2.9% |
| Moderate loss (-15% to -5%) | 28 | 7.5% |
| Small loss (-5% to 0%) | 192 | 51.2% |
| Small win (0% to 5%) | 120 | 32.0% |
| Moderate win (5% to 15%) | 18 | 4.8% |
| Big win (> 15%) | 6 | 1.6% |

Classic "death by a thousand cuts" — 51% of trades are small losses, while
only 6.4% are moderate-to-big wins. The rare big winners (SITM +220%, ACI
+54%, MSEX +37%) carry the portfolio, but they're 1.6% of trades.

### 4. Max drawdown exceeds 20-25% Weinstein threshold

All 3 scenarios show 34-39% drawdown — well above the 20-25% level where
Weinstein says to "move to the sidelines." The macro signal (Stage 4 → stop
buying) isn't preventing large drawdowns, likely because:
- Drawdowns happen during choppy markets (not clear Stage 4)
- Many small losses accumulate before the macro signal fires

### 5. Win rate improves in stronger bull markets

- 2018-2023 (mixed): 28.6% win rate
- 2015-2020 (strong bull + crash): 33.3%
- 2020-2024 (COVID recovery + bull): 47.7%

The strategy works best in strong trending markets (as expected for
trend-following), but the win rate is low even then.

## Weakest Links (Priority Order)

### 1. Initial stop placement — HIGHEST IMPACT

The 2% `initial_stop_buffer` doesn't match the book's prescription of placing
stops below the support floor (Ch. 6). The book says initial stop goes below
the prior correction low, and if that requires >15% risk, prefer other
candidates. Our fixed 2% is causing immediate stop-outs on normal volatility.

### 2. Entry quality — MEDIUM IMPACT

Many entries may trigger on noise rather than genuine breakouts. Volume
confirmation and breakout detection thresholds may need tuning.

### 3. Drawdown circuit breaker — NOT IMPLEMENTED

34-39% drawdowns would be reduced by Weinstein's 20-25% rule (Ch. 7).

### 4. Portfolio health visibility — MISSING METRIC

No metric for "% of open positions currently profitable." This would help
distinguish a healthy portfolio (many positions in the green) from one that
just happened to have one big unrealized winner at the sample point.

## TODOs

### TODO 1: Investigate and tune initial stop placement

The `initial_stop_buffer` (currently 2%) is much tighter than Weinstein Ch. 6
prescribes (support floor, typically 5-15% below entry). Need to:
- [ ] Test with wider fixed stops (5%, 8%, 12%) and compare win rate,
  holding periods, and total P&L
- [ ] Investigate support-floor-based stops (the book's actual method) —
  the screener already computes `base_low` which could serve as the support
  floor for stop placement
- [ ] Analyze the 258 trades that exited within 1 day — were the stops hit
  by normal intraday volatility, or were these genuine breakout failures?
- [ ] Caution: widening stops increases per-trade risk. Need to verify that
  position sizing (risk_per_trade_pct) still keeps total risk manageable

### TODO 2: Include stop analysis in backtest output

- [ ] Add per-trade initial stop level and distance to entry in trades.csv
- [ ] Add "days to first stop hit" metric
- [ ] Log whether stop triggered on gap-down vs intraday move

### TODO 3: Implement drawdown circuit breaker

Per Weinstein Ch. 7: "if assets drop by 20-25%, move to the sidelines."
- [ ] Add 20% drawdown threshold — halt new entries when breached
- [ ] Design re-entry criteria (wait for macro bullish? drawdown recovery?)
- [ ] Test impact on returns vs drawdown reduction across scenarios

### TODO 4: Add portfolio health metrics

- [ ] Track % of open positions with unrealized P&L > 0
- [ ] Track total unrealized P&L as a separate metric in summary output
- [ ] Track number of open positions over time
- [ ] This distinguishes a portfolio gaining from broad winners vs one
  lucky hold, and helps assess sustainability of returns

### TODO 5: Test segmentation library for stage analysis

The existing `analysis/technical/trend/segmentation.ml` library identifies
trend segments. Test whether using it for Stage classification (instead of
the current MA-slope-based approach) improves entry timing or reduces
false breakouts.

### TODO 6: Build experiment framework

Currently each backtest run is ad-hoc. Need a structured way to:
- [ ] Define a hypothesis (e.g. "wider stops improve win rate")
- [ ] Run A/B backtests with one parameter changed
- [ ] Compare metrics side-by-side in a standardized format
- [ ] Track experiment history (what was tried, what worked)

This could be a CLI extension to `backtest_runner` or a separate tool.

### TODO 7: Add more metrics to backtest output

- [ ] Profit factor (gross profit / gross loss)
- [ ] CAGR (compound annual growth rate)
- [ ] Calmar ratio (CAGR / max drawdown)
- [ ] % of open positions profitable (see TODO 4)
- [ ] Unrealized P&L at period end
- [ ] Number of open positions at period end
- [ ] Trade frequency (trades per month)

### TODO 8: Add fast smoke-test scenarios

The golden scenarios take ~40 min each. For quick iteration, add shorter
representative windows:
- [ ] 2019-06 to 2019-12 (6 months, bull market, ~5 min)
- [ ] 2020-01 to 2020-06 (6 months, COVID crash, ~5 min)
- [ ] 2023-01 to 2023-12 (1 year, recovery, ~10 min)

These could run as CI tests or as a "smoke" mode in the runner.

## Performance Notes

- Runtime: ~40 min per 6-year scenario with 1,654 stocks
- Memory: 6-7 GB peak for 6-year runs
- Non-deterministic: Hashtbl ordering in strategy internals (PR #298)
- Total runtime for 3 scenarios: ~90 min
