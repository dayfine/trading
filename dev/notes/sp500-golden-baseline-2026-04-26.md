# S&P 500 golden — baseline metrics (2026-04-26)

First measured run of the new `goldens-sp500/sp500-2019-2023` scenario.
Locks in the numbers that subsequent feature work measures against.

## Setup

- **Universe**: `trading/test_data/backtest_scenarios/universes/sp500.sexp`
  — 491-symbol S&P 500 snapshot (joined from `data/sp500.csv` against
  the local bar-data inventory; 12 symbols missing data).
- **Period**: 2019-01-02 → 2023-12-29 (5 years; n_steps = 1,257).
- **Initial cash**: $1,000,000.
- **Config overrides**: none (defaults from `Weinstein_strategy.config`).
- **Build**: post-#604 main (`33a0a031`) — Stage 4 + 4.5 PR-A + 4.5 PR-B
  + #602 Price_cache.
- **GC tuning**: `OCAMLRUNPARAM=o=60,s=512k`.
- **Container**: `trading-1-dev`.

## Result

### Trading metrics

| Metric | Value |
|---|---:|
| Final portfolio value | $1,184,919 |
| Realized total P&L | −$72,237 |
| Unrealized P&L (8 open positions) | $1,178,026 |
| **Total return** | **+18.49%** |
| Round trips | 133 |
| Wins | 38 |
| Losses | 95 |
| Win rate | 28.57% |
| Avg holding days | 82.4 |
| Sharpe ratio | 0.26 |
| Max drawdown | 47.64% |
| Profit factor | 0.89 |
| CAGR | 3.10% |
| Calmar ratio | 0.07 |
| Open positions at end | 8 |

### Performance

| | Value |
|---|---:|
| Peak RSS | **2,133 MB** |
| Wall | **2:33** |
| Calendar days loaded | 1,453 |
| Symbols loaded (universe + indices + sector ETFs) | 506 |

### Predicted vs measured RSS

Fit `RSS ≈ 68 + 4.3·N + 0.2·N·(T − 1)` (post-Stage-4.5 + #602 + GC tuned)
predicts **2,572 MB** at N=491, T=5y. Measured **2,133 MB** — ~17%
below prediction.

Two factors:

1. **Broader universe is cheaper per symbol than small-302.** The
   small-302 fit was on the curated blue-chip 302 set; per the
   pre-Stage-4 sweep
   (`dev/notes/bull-crash-sweep-2026-04-25.md`), broad data is
   ~3× cheaper per symbol than small-302. S&P 500 is closer to
   broad-data shape.
2. **Run-to-run noise** at this scale is ~50–100 MB.

## Verdict on metrics

The strategy's current behaviour on the 5-year S&P 500 cycle:

- **Realized P&L is slightly negative.** Most of the $185K headline
  return is unrealized in 8 still-open positions at end-of-period.
- **Win rate 28%** is below Weinstein's expected 40–50% — suggests
  stops are tripping too aggressively or breakouts are being entered
  at suboptimal points.
- **Max drawdown 48%** is high. The strategy didn't go to cash
  cleanly during 2020 H1 / 2022.
- **Sharpe 0.26 / Calmar 0.07** are poor.

This is **not** a tuned strategy. It is, however, a **stable baseline**
— exactly what a regression-pinned golden needs. Future PRs (short-side
strategy, segmentation-based stage classifier, stop-buffer tuning)
move these numbers; the golden test catches regressions vs this point.

## Expected ranges in the scenario sexp

The scenario file's `expected` block is tightened to ±10–15% around
this baseline:

```
(expected
  ((total_return_pct   ((min 15.0)        (max 22.0)))     ;; ±15% around 18.5
   (total_trades       ((min 125)         (max 145)))      ;; ±~10 around 133
   (win_rate           ((min 24.0)        (max 33.0)))     ;; ±~15% around 28.6
   (sharpe_ratio       ((min 0.05)        (max 0.50)))     ;; small absolute, wider relative
   (max_drawdown_pct   ((min 40.0)        (max 55.0)))     ;; ±~10% around 47.6
   (avg_holding_days   ((min 75.0)        (max 90.0)))     ;; ±~10% around 82.4
   (unrealized_pnl     ((min 1000000.0)   (max 1300000.0))))) ;; ±15% around 1.18M
```

These ranges accept normal optimisation noise but FAIL on:

- Strategy logic regressions (stops trigger differently, signal
  generation shifts) — would move multiple metrics out of band
  simultaneously.
- Universe / data drift — caught by the universe being a fixed snapshot.
- Random seed introduction — the strategy is currently deterministic;
  any future randomness must preserve these metrics within band.

## How to use this golden

1. **Before merging a non-trivial strategy / engine PR**, run:
   ```bash
   OCAMLRUNPARAM=o=60,s=512k \
   dune exec trading/backtest/scenarios/scenario_runner.exe -- \
     --dir trading/test_data/backtest_scenarios/goldens-sp500
   ```
2. Confirm all 7 metrics land in `expected` ranges. If a metric moves
   intentionally (e.g. short-side strategy adds new trades, raising
   `total_trades`), update the range in the sexp + document the reason
   in the PR body.
3. When the strategy gets meaningfully better (Sharpe > 0.5, etc),
   re-pin the ranges to the new operating point. Document the
   re-pinning as a deliberate baseline shift.

## Comparison to small-302 N=292 T=6y

| | small-302 (N=292×T=6y) | S&P 500 (N=491×T=5y) |
|---|---:|---:|
| Peak RSS | 1,453 MB | 2,133 MB |
| Wall | 2:51 | 2:33 |
| Universe expense | high (3.2× broad-data) | typical |
| Sharpe | unmeasured (no scenario file) | 0.26 |
| Max drawdown | unmeasured | 47.6% |

S&P 500 is **the canonical benchmark**; small-302 was a perf workhorse
with no associated trading metrics. From here on, both are useful:
small-302 for tight RSS/wall regression on the same cell; S&P 500 for
the trading-quality benchmark.

## References

- Universe sexp: `trading/test_data/backtest_scenarios/universes/sp500.sexp`
- Scenario sexp: `trading/test_data/backtest_scenarios/goldens-sp500/sp500-2019-2023.sexp`
- Run output: `dev/backtest/scenarios-2026-04-27-024706/sp500-2019-2023/`
- Memory fit reference: `dev/plans/columnar-data-shape-2026-04-25.md` §Memory expectations
- GC tuning matrix: `dev/notes/panels-rss-matrix-post602-gc-tuned-2026-04-26.md`
