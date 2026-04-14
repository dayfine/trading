# Stop-Buffer Tuning Experiment: Hypothesis

## Date
2026-04-14

## Hypothesis

Widening `initial_stop_buffer` from the current default of 1.02 (2% below
support) to values in the 1.05-1.15 range will:

1. **Reduce whipsaw exits** -- fewer trades exiting within 0-1 days
2. **Increase average holding period** -- positions survive normal volatility
3. **Improve win rate** -- fewer small-loss stop-outs
4. **Maintain or improve total returns** -- reduced churn compensates for
   larger per-trade losses when stops do trigger

## Rationale

Baseline results across three golden scenarios (2018-2023, 2015-2020,
2020-2024) show 74% of trades exit within 1 day. This is textbook whipsaw
behavior caused by stops set too tightly.

Per Weinstein Ch. 6, initial stops should sit below the "significant support
floor (prior correction low)" which is typically 5-15% below entry. The
current 2% buffer is far tighter than what the book prescribes.

## Expected trade-off

Wider stops increase per-trade risk when they trigger. The `max_drawdown_pct`
may increase. The experiment measures whether reduced churn outweighs the
larger individual losses.

## What would falsify this hypothesis

- If win rate does NOT improve with wider buffers (indicating whipsaws are
  not the primary driver of losses)
- If total returns degrade monotonically with wider buffers (indicating the
  strategy genuinely cannot hold positions profitably beyond 1 day)
- If variance between runs exceeds the signal between buffer values (due to
  known Hashtbl non-determinism, #298)

## Variants

| Variant | `initial_stop_buffer` | Buffer meaning |
|---------|----------------------|----------------|
| 1.02 (control) | 1.02 | 2% below support |
| 1.05 | 1.05 | 5% below support |
| 1.08 | 1.08 | 8% below support |
| 1.12 | 1.12 | 12% below support |
| 1.15 | 1.15 | 15% below support (book max) |

## Period

Primary: recovery-2023 (2023-01-02 to 2023-12-31) -- highest trade count
in baseline (109 trades), most statistical signal per run.

Validation: golden six-year-2018-2023 for winning 2-3 variants.
