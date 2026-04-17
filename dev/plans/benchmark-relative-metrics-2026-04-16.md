# Plan: benchmark-relative metrics (alpha, beta, info ratio)

**Date:** 2026-04-16
**Status:** DRAFT — for human review before dispatch
**Track:** backtest-infra (feat-backtest)

## Goal

Add benchmark-relative performance metrics to the simulation/backtest reporting surface so runs can be compared to a market benchmark (default SPY), not just to themselves. Current metrics in `trading/trading/simulation/lib/types/metric_types.ml` are strategy-absolute only (CAGR, Sharpe, drawdown, win rate, profit factor) — there is no answer to "did the strategy actually beat the market?"

## Metrics to add

All computed over the full backtest window; no rolling windows in this pass.

| Metric | Formula | Annualized? |
|---|---|---|
| **Beta** | `cov(r_p, r_m) / var(r_m)` | no (pure sensitivity) |
| **Alpha (Jensen's)** | `mean(r_p) - beta * mean(r_m)` (with rf=0 for v1) | yes (× 252) |
| **Correlation** | `cov(r_p, r_m) / (stdev(r_p) * stdev(r_m))` | no |
| **Tracking error** | `stdev(r_p - r_m)` | yes (× √252) |
| **Information ratio** | `mean(r_p - r_m) / tracking_error` | yes (× √252) |

`r_p` = daily portfolio returns (from `step.portfolio_value` sequence). `r_m` = daily benchmark returns (from benchmark bars close-to-close).

## Approach

Pure-function module, same shape as `sharpe_computer.ml`:

```
trading/trading/simulation/lib/benchmark_computer.ml{,i}
  val compute : portfolio_values:float list -> benchmark_values:float list ->
                trading_days_per_year:int -> benchmark_metrics record

trading/trading/simulation/lib/types/metric_types.ml
  new variants: Alpha | Beta | Correlation | TrackingError | InformationRatio

trading/trading/simulation/lib/metric_computers.ml
  register new computers; all depend on benchmark_values (new input seam)
```

**Benchmark loading:** extend the simulation driver (`trading/trading/backtest/lib/runner.ml` or equivalent) to accept a `benchmark_symbol` config param (default `"SPY"`), load its bars via the existing `Historical_source`, align to portfolio date range, resample to daily closes matching the portfolio value series.

**Data availability:** SPY bars for 2018-2023 — check `data/inventory.sexp` first. If missing, dispatch `ops-data` with a fetch task before feat-backtest starts this work.

**Regression:** simple closed-form OLS on float arrays. No external library. Mirror the arithmetic style of `sharpe_computer.ml` (mean, stdev, annualize by √252).

**Config:** add `benchmark_symbol : string option` to simulation/backtest config. `None` skips benchmark metrics entirely (no-op path). Default in the Weinstein backtest config: `Some "SPY"`.

## Test plan

1. **Synthetic returns.** Portfolio = `2 * benchmark + noise(0, small)` → assert beta ≈ 2, alpha ≈ 0 within ε. Portfolio = benchmark exactly → assert correlation = 1, tracking_error = 0, info_ratio = undefined (handle div-by-zero as `None`).
2. **Degenerate inputs.** Empty returns, 1-point returns, constant benchmark → return `None` or well-defined zeros. Document which.
3. **Integration.** Run existing golden 2018-2023 backtest with benchmark enabled; pin beta/alpha/IR to expected values. Make the pins wide enough to tolerate minor stop-buffer tuning churn.

## Out of scope

- Fama-French multi-factor regressions.
- Rolling-window beta/alpha (e.g., trailing 60d). Useful later for regime analysis.
- Risk-free rate beyond 0 — proper Jensen's alpha uses a short-rate series. Revisit once an rf-rate source is picked.
- Multi-benchmark blends (e.g., 60/40 SPY/AGG). The `benchmark_symbol` is a single string for v1.
- Benchmark-aware stop logic or position sizing. Metrics only.

## Open questions (need human decision before dispatch)

1. **SPY vs ^GSPC.** SPY includes dividends-reinvested in total-return series on EODHD; ^GSPC is price-only. For a fair alpha comparison against a strategy that reinvests dividends, SPY total-return is correct. Default to SPY unless specified otherwise?
2. **Risk-free rate.** Start with rf=0 for alpha, or fetch a short-rate (e.g., ^IRX 13-week T-bill)? Former is simpler, latter is more correct.
3. **`None` vs 0** for degenerate cases (flat benchmark, div-by-zero IR). Preference?
4. **Minimum observations.** How many trading days needed before benchmark metrics are meaningful? `sharpe_computer.ml` has no minimum today — consider at least 20 days for regression to be non-noise.

## Size estimate

~400-500 lines total:
- `benchmark_computer.{ml,mli}` — 120 lines
- metric_types additions + formatting — 50 lines
- metric_computers wiring — 40 lines
- runner/config integration — 60 lines
- tests — 200 lines (synthetic + degenerate + integration)

Single PR, one commit, targets `feat-backtest` track.

## Downstream

Once this lands, `dev/status/backtest-infra.md` gains a new class of comparison tests. The stop-buffer experiment (currently blocked on support-floor merge) would become much more evaluable — "does this tuning produce positive alpha" is a sharper question than "does this tuning produce higher absolute Sharpe."
