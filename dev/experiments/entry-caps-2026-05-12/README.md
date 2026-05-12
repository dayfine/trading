# Entry-caps 3-arm sweep on 15y Cell E

Tests two actionable levers from `dev/notes/entry-signal-quintiles-2026-05-11.md`:

| Arm | Config delta | What it tests |
|---|---|---|
| A | (none) | Baseline = current Cell E default |
| B | `max_score_override=79` | Q5 score ≥80 cap |
| C | B + `initial_stop_pct=0.10` | Q5 cap + wider initial stop |

The `volume_ratio_exclude_range` arm is deferred until PR #1043 merges.

## Universe + window

sp500-historical 510 symbols, 2010-01-01 → 2024-12-31 (15y).

## Run

```
dev/lib/run-in-env.sh dune exec backtest/scenarios/scenario_runner.exe -- \
  --dir dev/experiments/entry-caps-2026-05-12 \
  --parallel 3
```

Expected wall: ~14 min.

## Hypothesis

- B vs A: Sharpe + WR up ~2-3pp without significant return drag.
- C vs B: Sharpe up additional ~0.5-1pp from letting winners breathe.
- C vs A: net positive on both axes.

Falsification: if B reduces return by >20pp without Sharpe lift, Q5 hypothesis is wrong (extreme-score trades carry alpha after all). If C cuts trade count below ~500 over 15y, wider stops are over-tight and the sample is too thin.
