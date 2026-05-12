# Holding-period sweep — 16 cells on 15y Cell E default

## Hypothesis

The cell-e-candidate-supply-bottleneck note (2026-05-11) showed the
`Insufficient_cash : Stop_too_wide` rejection ratio is 3.4:1 — holding-period
capital lock-up is the binding constraint on portfolio fill at the new Cell E
default (`max_position_pct_long=0.14`, `max_long_exposure_pct=0.70`,
`min_cash_pct=0.30`).

This sweep varies the two holding-period levers — `stage3_force_exit.hysteresis_weeks` (h=0..3) × `laggard_rotation.hysteresis_weeks` (h=1..4) — on the 15y Cell E default to find the configuration that minimises `Insufficient_cash` skips without driving MaxDD over 25%.

## Cells (16)

| | laggard_h=1 | laggard_h=2 | laggard_h=3 | laggard_h=4 |
|---|---|---|---|---|
| stage3_h=0 | s0-l1 | s0-l2 | s0-l3 | s0-l4 |
| stage3_h=1 | s1-l1 | s1-l2 (baseline) | s1-l3 | s1-l4 |
| stage3_h=2 | s2-l1 | s2-l2 | s2-l3 | s2-l4 |
| stage3_h=3 | s3-l1 | s3-l2 | s3-l3 | s3-l4 |

`stage3_h=1 / laggard_h=2` is the current Cell E default (control cell).

## Universe + window

- sp500-historical 510 symbols, 2010-01-01 → 2024-12-31 (15y).
- All other knobs at Cell E default (`max_position_pct_long=0.14`, `max_long_exposure_pct=0.70`, `min_cash_pct=0.30`, MaSlope, short side off).

## Run

```
dev/lib/run-in-env.sh dune exec backtest/scenarios/scenario_runner.exe -- \
  --dir dev/experiments/holding-period-sweep-2026-05-12 \
  --parallel 5
```

Expected wall: 16 ÷ 5 × ~14 min ≈ 45 min on the post-#1024 hot path.

## Success metric

For each cell, capture from `trade_audit.sexp`:
- `Insufficient_cash` skip count
- `Stop_too_wide` skip count
- portfolio fill rate (entered / cascade-approved)

From `summary.sexp`:
- total_return / Sharpe / MaxDD / WR / trades

Look for monotonic drop in `Insufficient_cash` as we go from upper-right (slow rotation) to lower-left (fast rotation). Bail if MaxDD > 25% anywhere — that's the concentration cliff.
