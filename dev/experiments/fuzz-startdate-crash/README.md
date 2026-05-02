# fuzz-startdate-crash — start-date jitter on the COVID crash window

First end-to-end use of the `--fuzz` parameter-jitter mode (PR #780) plus the
`--fuzz-window` universe constrainer (PR #783). This experiment answers a
robustness question that the canonical 2019–2023 sp500 backtest cannot answer
on its own: **is the COVID-crash performance summary a single-run lottery, or
does the strategy survive a small perturbation in start date?**

## Run

- Spec: `start_date=2020-01-02±5w:11` — center on the crash window's start,
  weekly steps from 5 weeks before to 5 weeks after, 11 variants total
- Window: `--fuzz-window crash` → sp500 universe (491 symbols), all variants
  end on 2020-06-30 (`Smoke_catalog.crash.end_date`)
- Code version: `4b49eae5` (`fix(backtest): --fuzz-window flag`)
- Command:
  ```
  backtest_runner.exe fuzz 2020-06-30 \
    --fuzz "start_date=2020-01-02±5w:11" \
    --fuzz-window crash \
    --experiment-name fuzz-startdate-crash
  ```
- Wall time: ~28 minutes for all 11 variants (sequential), no OOM in the 8 GB
  dev container — well under the projected 35–40 min budget

## Hypothesis

**Strategy results on the COVID crash are dominated by where you happen to
start the simulation.** A swing of ±5 weeks in start date is small relative to
the 26-week window length, and the screener's 30-week MA + cascade logic
should converge on similar trade decisions regardless of where you bootstrap.
If the distribution is **tight**, the metrics we publish from a single canonical
backtest are trustworthy. If it is **wide**, every reported COVID-crash number
is essentially one draw from a wide lottery and should be reported with a
confidence band, not a point estimate.

The negation worth taking seriously: in a fast-moving crash window, the warmup
boundary may sit on either side of a critical sector regime change, producing
qualitatively different screener outputs across nearby start dates.

## Headline distribution

Pulled from `fuzz_distribution.md`:

| Metric | Median | IQR (p25–p75) | Range (min–max) |
|---|---|---|---|
| `total_return_pct` | **-12.45%** | -13.90 to -8.83 | -20.26 to -2.08 |
| `sharpe_ratio` | **-0.96** | -1.11 to -0.59 | -1.70 to -0.06 |
| `max_drawdown` | **22.63%** | 20.89 to 23.44 | 12.30 to 28.01 |
| `cagr` | -22.46% | -28.24 to -15.37 | -41.75 to -3.75 |
| `num_trades` | 21 | 19.5 to 22.5 | 17 to 26 |
| `win_count` | 0 | 0 to 1 | 0 to 3 |
| `loss_count` | 18 | 17 to 21 | 15 to 23 |
| `loss_rate` (%) | 100% | 92.7 to 100 | 85 to 100 |
| `avg_loss_pct` | -7.10 | -7.80 to -6.64 | -9.16 to -5.15 |
| `max_drawdown_duration_days` | 131 | 131 to 136 | 130 to 158 |

Center variant (var-06, `2020-01-02`): total_return -12.91%, max_dd 22.71%,
sharpe -1.03, 21 trades, 0 wins — sits essentially at the median.

## Interpretation

**Direction of result is robust; magnitude has meaningful spread.**

- The **sign** of every metric is identical across all 11 variants. Every
  start date produces a losing run. There is **no variant where the strategy
  was net-profitable on the COVID crash** — the worst is -20.26%, the best is
  -2.08%, both losses.
- `loss_rate` is at-or-near 100% in 6/11 variants and ≥85% in all 11. The
  win-count median is 0 and the max is 3 (out of ~21 trades). The strategy's
  inability to find Stage-2 longs into a crash is the dominant signal, not
  jitter.
- `max_drawdown` is **tight**: IQR width 2.55 percentage points around a
  ~22.6% median. Drawdown duration is essentially constant (130–158 days, IQR
  131–136). The crash dominates drawdown regardless of when you bootstrap —
  every variant rides the same March 2020 bottom.
- `total_return_pct` is **moderately wide**: IQR width ~5.1 pp, range width
  ~18.2 pp. A strategy reporter quoting "-12.5%" as the canonical COVID-crash
  return should attach an IQR band of roughly ±2.5 pp.
- `sharpe_ratio` is **the widest** in relative terms: median -0.96, range
  -1.70 to -0.06. The best variant comes within a hair of break-even sharpe;
  the worst is genuinely terrible. This is what we would expect when
  total_pnl moves and volatility is roughly stable — sharpe ratio amplifies
  the pnl spread.
- `num_trades` IQR 19.5–22.5 is reassuringly tight: signal generation is
  consistent across variants. The strategy is making roughly the same set of
  decisions; the variance is in **which side of the regime change** those
  decisions catch.

**Conclusion.** The "strategy loses on the COVID crash" claim is **robust** to
±5w start-date jitter — that result is not a single-run lottery. The
**magnitude** of the loss should be reported as a band, not a point estimate.
For the canonical sp500-2019-2023 baseline (which spans 5 years, not just the
crash sub-window), this experiment cannot directly speak to robustness — that
needs a separate fuzz across the full window, which would be the natural next
step before pinning the M5.5 baseline.

## Files

- `fuzz_distribution.{sexp,md}` — per-metric stats across all 11 variants
- `variants/var-NN/summary.sexp` — per-variant metric block (sufficient to
  recompute the distribution table)
- `variants/var-NN/params.sexp` — per-variant configuration (start_date,
  end_date, code_version, universe_size, commission)

Per-variant `trade_audit.sexp`, `equity_curve.csv`, `trades.csv`,
`open_positions.csv`, `force_liquidations.sexp`, `macro_trend.sexp`,
`universe.txt` were excluded from the commit to keep the PR scoped (would
add ~1.4 MB and ~80 files). They remain reproducible from the spec at the
top of this README via the same command.

## Follow-ups

1. Same fuzz on the bull and recovery windows (`--fuzz-window bull` /
   `--fuzz-window recovery`) — does start-date sensitivity differ by regime?
2. Numeric-key fuzz on `stops_config.initial_stop_buffer` over the same crash
   window — does loosening the stop salvage any variants, or does the macro
   gate matter more than stop placement during a crash?
3. Wider grid (M5.5): combine `start_date` jitter with `initial_stop_buffer`
   jitter and look at the joint distribution.
