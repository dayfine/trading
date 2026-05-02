# Fuzz: start_date jitter on canonical sp500-2019-2023 (full window)

Companion to PR #785. That experiment fuzzed the 6-month COVID crash
sub-window; this one fuzzes the full 5-year canonical baseline so we can
answer: **is the published sp500-2019-2023 result a single-run lottery, or
a robust signal?**

## Hypothesis

The canonical sp500-2019-2023 baseline (`trading/test_data/backtest_scenarios/goldens-sp500/sp500-2019-2023.sexp`)
is the foundation benchmark for downstream feature work — short-side
strategy, segmentation classifier, stop tuning, M5.5 grid search. Every
follow-on PR measures itself against this number. If the number itself
moves materially under a small jitter of the start date, then the band
matters more than the point.

`±2w` (5 variants spaced 1 week apart, 2018-12-19 .. 2019-01-16) is small
relative to the 5-year (260-week) window length — the screener should
converge on similar trade decisions across nearby start dates. Tight
distribution → trust the canonical metric. Wide distribution → publish a
band.

## Run

```
backtest_runner fuzz 2023-12-29 \
  --fuzz "start_date=2019-01-02±2w:5" \
  --fuzz-window crash \
  --experiment-name fuzz-startdate-canonical-full
```

`--fuzz-window crash` constrains the universe to the sp500 snapshot
(491 symbols) without substituting the window's dates — variants run the
full 5y, end 2023-12-29 fixed by the positional. Wall time: ~15 min for
all 5 variants on the dev container (much faster than the predicted ~2 h
because per-day cost dominates panel-build cost; once panels are warmed,
the 5y run is only ~10× the 6-month crash run, not 10× per variant).

`code_version` recorded in `variants/var-N/params.sexp`:
`95b9a015...` (docs-only commit downstream of `ebee2262`, strategy code
identical to current `origin/main`).

## Headline distribution

From `fuzz_distribution.md`:

| Metric | Median | IQR (p25–p75) | Range (min–max) |
|---|---|---|---|
| `total_return_pct` | **+55.44%** | +41.21 to +60.39 | +37.92 to +60.86 |
| `sharpe_ratio` | **0.52** | 0.43 to 0.55 | 0.41 to 0.56 |
| `max_drawdown` | **34.15%** | 34.15 to 34.17 | 31.28 to 35.99 |
| `cagr` | 9.21% | 7.13 to 10.00 | 6.61 to 10.11 |
| `num_trades` (round-trips) | 87 | 86 to 89 | 82 to 99 |
| `win_rate` (%) | 22.35 | 22.09 to 23.17 | 21.95 to 25.25 |
| `loss_rate` (%) | 77.91 | 77.53 to 78.05 | 74.75 to 78.16 |
| `max_drawdown_duration_days` | 779 | 742 to 779 | 617 to 779 |
| `avg_holding_days` | 82 | 79 to 97 | 78 to 104 |

## Sanity check vs. the canonical baseline

The center variant (var-3, start=2019-01-02) reproduces the canonical
configuration. Its result lands at:

| | Center variant (var-3, this run) | Stale pin in `sp500-2019-2023.sexp` (2026-04-30) |
|---|---|---|
| `total_return_pct` | **+60.86** | -0.01 |
| `max_drawdown` | **34.15** | 5.81 |
| `num_trades` | **86** | 32 |
| `sharpe_ratio` | **0.55** | 0.01 |
| `win_rate` | **22.09** | 37.50 |

**The dispatch's stated baseline (-0.01% / 5.81% MaxDD / 32 trades) is
stale.** The scenario file's pin was measured on 2026-04-30, before
PRs #744 (per-position cap), #745 (clamp for negative portfolio), #746
(asymmetric long/short caps), #771 (benchmark-returns plumbing) landed.
Those changes materially shifted the strategy's sizing + entry mechanics.

The center variant exactly matches an independent canonical run from
earlier today (`dev/backtest/scenarios-2026-05-02-002149/sp500-2019-2023/summary.sexp`,
+60.86% / 34.15 / 86 RTs / Sharpe 0.55) — confirming the runner is wired
correctly and the divergence vs. the stale pin is the strategy code, not
the harness. See also `dev/notes/optimal-strategy-sp500-2019-2023-validated-2026-05-02.md`
which independently captured the same +60.86% / 34.15 / 86 number.

## Interpretation

**Direction is robust; magnitude has meaningful spread.**

- **Sign is identical across all 5 variants** — every start date produces
  a profitable run. There is no variant where the strategy lost money on
  the 5y window. Sharpe is positive in all 5 (0.41–0.56). Compare to PR
  #785's COVID-crash fuzz where every variant lost — this is the
  recovery + 2023 leadership rotation pulling the full window net
  positive even when 2020 H1 mauls every variant equivalently.
- **`max_drawdown` is exceptionally tight** (IQR 34.15–34.17, range
  31.28–35.99). All 5 variants hit the same Mar-2020 (or 2022) bottom
  regardless of when the run started — the drawdown is a property of the
  market, not the entry timing.
- **`max_drawdown_duration_days` median 779 (≈2.1 years)** is sobering.
  Every variant spends most of 2022 underwater. The IQR collapses to a
  single value (779) because the dominant trough is the same calendar
  event for every start date.
- **`total_return_pct` IQR is 19.2 pp (41.2–60.4), range 23 pp
  (37.9–60.9)**. Wider in absolute terms than the COVID-crash fuzz's
  5.1 pp IQR, but smaller in relative-to-mean terms (~35% of median vs.
  ~40% for the crash window). Quote canonical sp500-2019-2023 as
  `+55% ± ~10 pp IQR`, not as a point estimate.
- **The earliest start (2018-12-19) is the negative outlier** at
  +37.92% — visible in `total_pnl` (-16.4K) and `cagr` (6.61% vs.
  median 9.21%). One extra week of cash exposure before the screener
  finds Stage-2 entries pulls 18 pp off the return. Entries that the
  earlier-start variant *does* take fail more often (n_round_trips 99
  vs. median 87, and win_rate 25% but with lower-quality picks
  evidenced by lower expectancy). This is **early-window
  cash-deployment noise**, not regime mis-classification — the screener
  burns trades searching for stage-2 starts in a quiet pre-2019
  setup.
- **`num_trades` IQR (86–89) and `win_rate` IQR (22.1–23.2) are tight.**
  Signal generation is consistent across variants; the variance is in
  *which* trades land profitable, not in *how many* the screener
  triggers.

## Conclusion

The canonical sp500-2019-2023 baseline is **direction-robust** — every
±2w jitter produces a profitable, positive-Sharpe 5y run. The
**magnitude** has meaningful spread (~10 pp IQR on total return), so the
single-run pin should be reported as a band, not a point estimate.

For M5.5 grid search: target the **distribution band**, not the point.
A grid-search candidate that improves the center variant but degrades
the early-start outlier is not necessarily an improvement. Score
candidates by both median and the worst-of-N variant (or median minus
half-IQR) so the optimizer can't game timing-luck noise.

## Required follow-up

**The scenario file's pinned baseline is stale.** Re-pin
`trading/test_data/backtest_scenarios/goldens-sp500/sp500-2019-2023.sexp`
to the post-#744+#745+#746+#771 reality. Recommended replacement:

```
;; Measured baseline (2026-05-02, post-#744/#745/#746/#771):
;;   total_return_pct  +60.86  total_trades 86   win_rate 22.09
;;   sharpe_ratio       0.55   max_drawdown 34.15  avg_holding_days 78.22
;;   open_positions_value 1,530,796   force_liquidations 0
;;
;; Distribution under start_date=2019-01-02±2w:5 (fuzz-startdate-canonical-full):
;;   total_return_pct median 55.44, IQR 41.21–60.39
;;   max_drawdown median 34.15 (IQR 34.15–34.17, range 31.28–35.99)
;;   num_trades median 87 (IQR 86–89)
```

And widen the `expected` envelope correspondingly (current envelope of
`total_return_pct (-15..15)` will fail every run on current main).

Pinning + envelope refresh is out of scope for this PR (per the
"experiment artefacts only" scope rule); separate PR recommended,
referencing this report.

## Files (12)

- `fuzz_distribution.{sexp,md}` — distribution stats across 5 variants
- `README.md` — this file
- `variants/var-{1..5}/summary.sexp` + `params.sexp` — per-variant
  metrics + provenance

Per-variant `trade_audit.sexp`, `equity_curve.csv`, `trades.csv`,
`stop_log.sexp`, etc. are excluded to keep the PR diff scoped (~1.5 MB,
~80 files). Reproducible from the `backtest_runner` command above; full
artefacts live at `dev/experiments/fuzz-startdate-canonical-full/` in
the dev container's filesystem (not committed).
