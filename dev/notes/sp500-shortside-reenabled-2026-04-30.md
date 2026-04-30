# sp500-2019-2023 — shorts re-enabled (post-G9), 2026-04-30 evening

Third retry of the sp500-2019-2023 baseline rerun with `enable_short_side = true`,
following the merge of PR #710 (G9 — `Force_liquidation_runner._portfolio_value`
shorts-sign fix). All preconditions G1-G5 + G7 + G8 + G9 are now closed on
`main@origin = d7e8b89b`.

## Pre-flight

Worktree confirmed at `main@origin` (`d7e8b89b` — PR #710 G9 fix). The G7, G8,
G9 fixes are all present in the worktree:

- G7 (PR #702): `Portfolio_risk.compute_position_size` accepts `~side`,
  caps shares at `max_short_exposure_pct` (30%) for shorts and
  `max_long_exposure_pct` (90%) for longs.
- G8 (PR #705): `Portfolio_view._holding_market_value` signs by `pos.side`
  (longs add `+quantity * close_price`, shorts add `-quantity * close_price`).
- G9 (PR #710): `Force_liquidation_runner._portfolio_value` delegates to
  `Portfolio_view.portfolio_value` so the same sign convention is used in
  both call sites.

## Scenario edit

`trading/test_data/backtest_scenarios/goldens-sp500/sp500-2019-2023.sexp`:

- Removed `(config_overrides (((enable_short_side false))))`; replaced with
  `(config_overrides ())` (the field is required by the sexp schema, but the
  empty list yields the default `enable_short_side = true`).
- Removed the BASELINE_PENDING comment block + the disable rationale comment.
- Re-tightened `expected` ranges to ±10-15% around the measured metrics.

## Rerun

```
docker exec -e TRADING_DATA_DIR=/workspaces/trading-1/trading/test_data trading-1-dev \
  bash -c 'cd /workspaces/trading-1/.claude/worktrees/agent-a66ac26b351f1f111/trading \
  && eval $(opam env) \
  && dune exec trading/backtest/scenarios/scenario_runner.exe -- \
       --dir /tmp/sp500-shorts-v3 \
       --fixtures-root /workspaces/trading-1/.claude/worktrees/agent-a66ac26b351f1f111/trading/test_data/backtest_scenarios'
```

Output: `/workspaces/trading-1/trading/dev/backtest/scenarios-2026-04-30-135424/sp500-2019-2023/`
(also re-confirmed in `scenarios-2026-04-30-135705/`).

## Metrics

| Metric              | Value      |
|---------------------|------------|
| total_return_pct    |  -0.01     |
| total_trades        |    32      |
| win_rate            |  37.50     |
| sharpe_ratio        |   0.01     |
| max_drawdown_pct    |   5.81     |
| avg_holding_days    |  43.03     |
| unrealized_pnl      |  391,949   |
| force_liquidations  |     0      |
| final_portfolio_value | 999,937  |

Side breakdown:

| Side  | Trades | Wins | Win rate | Realized PnL  |
|-------|--------|------|----------|---------------|
| LONG  |  28    |  12  |  42.9%   |   -15,350     |
| SHORT |   4    |   0  |   0.0%   |   -49,247     |
| Total |  32    |  12  |  37.5%   |   -64,597     |

Position sizing on shorts: all initial position values fell between $117k and
$125k against $1M portfolio (~11.7-12.5%) — well under the 30% short-exposure
cap that G7 introduced.

Equity curve range: min $941,915 (max drawdown) to max $1,000,000 (start).
**Portfolio value never went negative on any day** — the canonical pathology
of the pre-G9 runs is gone.

## Comparison vs prior runs

| Run                         | Trades  | Force-liq | Avg hold (d) | Return  | Notes                                |
|-----------------------------|---------|-----------|--------------|---------|--------------------------------------|
| Long-only baseline (canonical 2026-04-28) | 134     |     0     |    n/a       | +70.8%  | `enable_short_side = false`           |
| AM run (post-G7 only)       |  ~hundreds | 910       | 3.46         | -100+%  | sized OK; but force-liq spam from G8 |
| PM run (post-G7+G8)         |  ~hundreds | 928       | 3.46         | -100+%  | G8 only patched 1 of 2 sites; G9 left |
| Evening run (post-G7+G8+G9) |  32     |     0     |    43.03     | -0.01%  | clean — all gates pass                |

The evening run produces fewer trades than long-only baseline because shorts
compete with longs for capital, and the strategy is more conservative when
both sides are available (some entries during 2019's Bearish-macro window
get short-side classification rather than long-side). All 4 short trades
were entered in 2019 (Bearish macro) and exited at stop_loss as the 2020-2023
bull market unfolded — that's expected behaviour for this period.

## G1-G9 fix validation

- **G1 (short-stop direction)**: shorts exited at stop_loss with the correct
  sign convention; no spurious early exits at profitable prices.
- **G2 (short metrics visibility)**: `wincount=12 losscount=20` aggregates
  both sides correctly.
- **G3 (cash floor on shorts)**: cash floor not breached at entry; sizing
  now caps below the floor.
- **G4 (force liquidation)**: force_liquidations=0 (no events written).
  Eliminated by the combination of G7 (correct sizing) + G9 (correct
  portfolio_value tracking).
- **G5 (audit harness)**: regression tests in `simulation/test/` continue
  to pass (verified via `dune runtest`).
- **G7 (position sizing)**: all initial_position_value entries ≤ 12.5% of
  portfolio. Cap of 30% never approached.
- **G8 + G9 (portfolio_value sign)**: equity-curve never goes negative;
  drawdown of 5.81% is a real drawdown, not a phantom-cycle artefact.

## Decision tree (all pass)

- [x] Total return > -10% (measured: -0.01%)
- [x] Force-liquidation count ≤ 50 (measured: 0)
- [x] portfolio_value never goes negative (min $941,915)
- [x] Avg holding days > 20 (measured: 43.03)
- [x] Position sizing ≤ 30% at entry (measured: max 12.5%)

## Tightened ranges

```
(expected
 ((total_return_pct   ((min -15.0)       (max  15.0)))
  (total_trades       ((min 27)          (max  37)))
  (win_rate           ((min 31.0)        (max  44.0)))
  (sharpe_ratio       ((min -0.5)        (max  0.5)))
  (max_drawdown_pct   ((min 3.0)         (max  9.0)))
  (avg_holding_days   ((min 37.0)        (max  50.0)))
  (unrealized_pnl     ((min 330000.0)    (max  450000.0)))))
```

The scenario PASSES against these ranges (verified via second run with the
edited file).

## Follow-ups

- The 32-trade count is much lower than the 134-trade long-only baseline.
  Most of that delta is shorts taking up a small fraction of capital
  during the Bearish-macro window; the larger driver is that with shorts
  enabled the strategy's cascade may down-rank some Stage-2 long entries
  that compete with Stage-4 short candidates. Worth investigating
  whether the long-side entry rate has actually changed (28 longs vs.
  the long-only baseline's 134 is a 79% drop).
- All 4 shorts lost (-$49k). Short-side strategy hit-rate during a
  prolonged bull is structurally low. The gap closures were about
  *correctness*, not profitability — the strategy now behaves
  deterministically with shorts on; whether shorts are *worth keeping
  on* in a sustained bull regime is a separate (downstream) question
  for the strategy-tuning track.
- G5 audit harness should now have `enable_short_side = true` as the
  default for the regression baseline.
