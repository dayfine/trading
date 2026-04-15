# Stop-Buffer Tuning Experiment: Report

## Date
2026-04-14

## Summary

**Hypothesis rejected on golden validation.** On the 1-year smoke
(recovery-2023), widening `initial_stop_buffer` from 1.02 to 1.15 looked
strongly positive: +38.9% return vs +20.7% control, Sharpe 1.78 vs 1.09.
On the 6-year golden (2018-2023, covering 2018 Q4 selloff, 2020 crash,
2022 bear), the result reversed: 1.15 returned -7.1% with Sharpe -0.01,
while the 1.02 control returned +36.3% with Sharpe 0.36 and the lowest
drawdown.

**Default stays at 1.02.** Single-regime tuning misled. See Conclusion.

## Smoke results: recovery-2023 (2023-01-02 to 2023-12-31)

Run via `scenario_runner --dir experiments/stop-buffer --parallel 1`.
Output: `dev/backtest/scenarios-2026-04-14-222425/`.

### Comparison table

| Metric              | 1.02 (control) |   1.05 |   1.08 |   1.12 |   1.15 |
|---------------------|---------------:|-------:|-------:|-------:|-------:|
| Total Return %      |          20.7  |  21.0  |  12.3  |  21.6  |  38.9  |
| Total Trades        |            53  |    43  |    39  |    49  |    23  |
| Win Rate %          |          44.5  |  45.4  |  50.0  |  54.8  |  53.6  |
| Sharpe Ratio        |          1.09  |  1.19  |  0.58  |  0.85  |  1.78  |
| Max Drawdown %      |          9.6   |  8.6   | 13.8   | 15.6   |  7.6   |
| Avg Holding Days    |         13.3   |  9.5   |  6.1   |  4.8   |  3.7   |
| Profit Factor       |          1.08  |  0.86  |  0.67  |  1.17  |  1.58  |
| CAGR %              |         12.8   | 12.9   |  7.7   | 13.3   | 23.3   |
| Calmar Ratio        |          1.32  |  1.51  |  0.56  |  0.85  |  3.06  |
| Total PnL (closed)  |      8,749    | -21,541| -101,045| 61,057| 196,673|
| Open Positions (end)|            41  |    35  |    15  |     8  |     6  |

### Key observations

1. **Win rate improves monotonically** from 44.5% (1.02) to 54.8% (1.12),
   with 1.15 at 53.6%. This confirms the hypothesis: tighter stops cause
   more whipsaw exits.

2. **1.15 is the clear best** across risk-adjusted metrics: Sharpe (1.78),
   Calmar (3.06), and Profit Factor (1.58) all substantially beat every
   other variant.

3. **Trade count drops from 53 to 23** with 1.15 -- fewer but dramatically
   more profitable trades. Closed-trade P&L swings from +$8.7K (1.02) to
   +$196.7K (1.15).

4. **Non-monotonic pattern**: 1.08 is the worst performer (return 12.3%,
   PF 0.67, Sharpe 0.58). This suggests a transition zone around 1.05-1.08
   where stops are wide enough to skip the cheapest stop-outs but not wide
   enough to survive real pullbacks.

5. **Average holding days decreases** (13.3 -> 3.7) rather than increasing.
   This is counterintuitive but explained by composition: wider stops reduce
   total entries, so the remaining open positions at year-end (which inflate
   avg_holding_days in the control) are fewer. The metric reflects portfolio
   composition, not per-trade behavior.

6. **Max drawdown is non-monotonic**: 1.02 (9.6%) and 1.15 (7.6%) have low
   drawdowns, while 1.08 (13.8%) and 1.12 (15.6%) have higher drawdowns.
   The 1.15 variant's low drawdown is driven by fewer simultaneous positions
   and higher quality entries.

### Non-determinism note

Comparing this run's 1.02 control against the earlier parallel run (which
completed only the 1.02 before the others OOM'd):
- Return: 20.7% vs 25.9% (5 ppt variance)
- Trades: 53 vs 55
- Win rate: 44.5% vs 42.3%

This variance is due to known Hashtbl ordering non-determinism (#298). The
~5 ppt variance is smaller than the ~18 ppt signal between 1.02 and 1.15,
so the experiment's conclusions are robust despite non-determinism.

## Golden validation: six-year-2018-2023

All three variants completed. Output dir:
`dev/backtest/scenarios-2026-04-14-225929/`.

| Metric              | 1.02 (control) |   1.12 |   1.15 |
|---------------------|---------------:|-------:|-------:|
| Total Return %      |          36.3  |  24.4  |  -7.1  |
| Total Trades        |           105  |    57  |    90  |
| Win Rate %          |          39.6  |  52.0  |  52.8  |
| Sharpe Ratio        |          0.36  |  0.26  | -0.01  |
| Max Drawdown %      |         37.0   | 54.2   | 39.0   |
| Profit Factor       |          1.08  |  1.19  |  0.99  |
| CAGR %              |          4.83  |  3.38  | -1.11  |
| Calmar Ratio        |          0.13  |  0.06  | -0.03  |
| Total PnL (closed)  |      74,973   | 248,075 | -12,750 |

## Conclusion — HYPOTHESIS REJECTED on golden

**Golden reverses the smoke result.** On the 6-year window that includes
the 2018 Q4 selloff, 2020 COVID crash, and 2022 bear:

- **1.15 collapses** from smoke's +38.9% to golden's -7.1%. Sharpe flips
  negative. Profit factor slips below 1.
- **1.02 control wins** on golden across every risk-adjusted measure
  (Sharpe 0.36 > 0.26 > -0.01; Calmar 0.13 > 0.06 > -0.03; positive CAGR
  only for 1.02).
- **1.12 is middle**: higher win rate (52%) and profit factor (1.19) but
  worst max drawdown (54%). Survived but with brutal equity swings.

### Why the reversal

Smoke window (recovery-2023) was a uniformly trending bull year. Wider
stops skipped the cheap whipsaw exits and let good trades run. Across
the 6-year golden, wider stops converted what would be quick whipsaw
losses into larger drawdowns during regime changes — the 2018 and 2020
downdrafts punished wide buffers hardest.

**Do not change the default.** `initial_stop_buffer = 1.02` stays.

## Follow-up experiments

The single-parameter fixed-buffer approach appears brittle across
regimes. Alternatives ranked by expected value:

1. **Support-floor-based stops** (Weinstein's actual prescription):
   place stops at prior correction lows rather than a fixed fraction
   below entry. Adapts to each stock's structure.
2. **Regime-aware stops**: use macro trend to choose buffer width
   (tighter in bear, wider in bull). Testable via `Macro.analyze` output.
3. **Per-trade stop logging**: emit stop level + trigger type to
   trades.csv to diagnose remaining stop-outs.
4. **Finer sweep** (1.03, 1.05, 1.07): dropped in priority after golden
   results — the wide end of the range is clearly worse.

## Follow-up experiments

1. **Finer sweep around 1.15**: test 1.13, 1.15, 1.17, 1.20 to find if
   1.15 is truly optimal or if even wider buffers help
2. **Per-trade stop logging**: add stop level and trigger type to trades.csv
   to diagnose remaining stop-outs at the per-trade level
3. **Support-floor-based stops**: replace fixed buffer with dynamic stop
   placement at prior correction lows (closer to Weinstein's actual
   prescription)
