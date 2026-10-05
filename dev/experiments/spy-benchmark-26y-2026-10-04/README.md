# SPY benchmarks on the 26y investor window (2026-10-04)

User decision 2026-10-04: rerun the SPY 30-week-MA reference strategy once on the current build as a benchmark
for the 26y investor baseline, then close the `spy-only-reference` track. Not an experiment with a verdict —
a reference row. Build: `main` at 63b14a8a7 (workspace `jjws-spy`), CSV mode, bars from the full data store
(`TRADING_DATA_DIR=/workspaces/trading-1/data`; the `trading/test_data` SPY file starts 2009-01-02 and must not
be used for this window — a first attempt did and silently ran 2009–2026).

## Specs

- `specs/spy30w-26y.sexp` — `Spy_only_weinstein (symbol SPY) (ma_period_weeks 30)`, long/flat.
- `specs/spybah-26y.sexp` — `Bah_benchmark (symbol SPY)`.
- Window 2000-01-01 → 2026-06-26, the same as `inv26sc-investor` (the 26y broad investor baseline).

## Results (`results/<spec>-actual.sexp`)

| strategy | total return | max DD | Calmar | Sharpe | trades |
|---|---:|---:|---:|---:|---:|
| SPY 30-week MA, long/flat | 326.8 % | 25.8 % | 0.219 | 0.535 | 21 |
| SPY buy-and-hold (sim, price only) | 400.8 % | 56.0 % | 0.112 | 0.408 | 0 |
| Investor preset 26y s0 / s1 / s2 (`inv26sc-investor`, build 6d84ff1c3) | 623.6 / 401.3 / 621.3 % | 31.1 / 31.0 / 31.0 % | 0.250 / 0.202 / 0.250 | 0.601 / 0.514 / 0.602 | — |

Basis: the simulator values every position at the raw close and credits no dividends, so all three rows are
price-only. SPY's dividend-reinvested return over the window is +706 % (adjusted close 91.13 → 734.30), i.e.
dividends are worth ~1.9 %/yr that none of these rows earn. The review pack's "SPY total return" line uses the
adjusted series, so it is the harder benchmark.

Reading: on Calmar the investor preset beats SPY-30w at s0/s2 (0.25 vs 0.22) and trails it at s1 (0.20); both
roughly double buy-and-hold. The investor's edge over a one-instrument timing rule is therefore modest and
salt-dependent; its drawdown is ~5 pp deeper. The investor numbers include the #3109 dividend-split phantom
(−4.9 to −10.9 pp of total return; issue comment 2026-10-04) and predate #3100/#3075/#3101.

SPY-30w trade list: 21 round trips, 11 losers (most in 2000–02, −6.95 %, −11.98 % …); the winners are the long
holds (2003-05 → 2004-07 +17.6 %, 2012-07 → 2015-08 etc.).

## Files

`results/` — actual, summary, params, trades, equity curve, open positions, macro trend per spec; `run.log`.
