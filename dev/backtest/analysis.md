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

## Key Findings

### 1. Huge unrealized gains, negative trade P&L

The most striking pattern: the portfolio gains massively (+27% to +305%) but
closed trade P&L is negative in 2 of 3 scenarios. This means:
- The strategy enters positions that appreciate significantly while held
- But when it exits (via trailing stops), the exits happen at a loss
- The system's value comes from **holding winners**, not from the trading itself

This is consistent with Weinstein's methodology — trailing stops let winners
run. But it means the exit mechanism (stops) is triggered too early on many
trades, locking in small losses.

### 2. 74% of trades held < 7 days (whipsaw)

**258 of 375 total trades** (across all scenarios) were held 0-1 days. This is
the critical weakness. The strategy enters on a breakout signal, but the
trailing stop fires almost immediately. This suggests:
- Initial stop is too tight relative to normal volatility
- Or the entry happens at a point where the stock immediately retraces
- The `initial_stop_buffer` of 1.02 (2%) may be insufficient for daily noise

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

### 1. Exit timing (trailing stops) — HIGHEST IMPACT

258/375 trades exit within 1 day. The trailing stop fires too quickly. Options:
- Increase `initial_stop_buffer` from 2% to 5-8%
- Use ATR-based stops instead of fixed percentage
- Add a minimum holding period before stops activate
- Widen the trailing stop threshold

### 2. Entry quality — MEDIUM IMPACT

Many entries happen at points where the stock immediately retraces. Could be:
- Breakout detection triggers on noise, not real breakouts
- Volume confirmation threshold too low
- Entering at market open after a breakout day means buying the gap-up

### 3. Drawdown circuit breaker — NOT IMPLEMENTED

The 34-39% drawdowns would be reduced by Weinstein's 20-25% rule.
Implementing the circuit breaker would cap drawdown but also miss recovery.

### 4. Position sizing — WORKING AS DESIGNED

1% risk per trade keeps individual losses small ($100-$3K). The issue is
frequency of losses, not their size.

## Recommendations

1. **Immediate**: Investigate why 74% of trades exit within 1 day. Add
   intermediate logging — record entry price, initial stop level, and
   first few days of price action per trade.

2. **Short-term**: Experiment with wider initial stops (5%, 8%) and compare
   win rates and holding periods. This is the single highest-impact change.

3. **Medium-term**: Implement the drawdown circuit breaker (20% threshold).

4. **Investigate**: The gap between portfolio return (+57%) and trade P&L
   (-$15K) means most value is from unrealized positions at period end.
   Understand whether this is sustainable or just survivorship of long holds.

## Performance Notes

- Runtime: ~40 min per 6-year scenario with 1,654 stocks
- Memory: 6-7 GB peak for 6-year runs
- Non-deterministic: Hashtbl ordering in strategy internals causes slight
  variation between runs (PR #298)
- Total runtime for 3 scenarios: ~90 min
