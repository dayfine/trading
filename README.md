# trading

[![CI](https://github.com/dayfine/trading/actions/workflows/ci.yml/badge.svg)](https://github.com/dayfine/trading/actions/workflows/ci.yml)

A semi-automated trading system implementing Stan Weinstein's stage-analysis
methodology. See `docs/design/` for the system design and the Weinstein book
reference.

The headline numbers below are regenerated mechanically by
`trading/backtest/readme_toplines` — the period is derived from actual bar
coverage in the CSV store, and the two Weinstein figures come from running the
reference strategies end-to-end. The block between the markers is overwritten on
each regeneration; do not hand-edit it.

<!-- toplines:start -->
## Top-line results

Pinned testing period: **1998-12-22 -> 2026-06-12** (common bar coverage of SPY, BRK-B, and the nine original SPDR sector ETFs).

| Strategy | Total return | CAGR (%/yr) | Notes |
|---|---|---|---|
| SPY buy-and-hold | +888.9% | +8.7% | buy & hold, dividend-adjusted close |
| BRK-B buy-and-hold | +1132.4% | +9.6% | buy & hold, dividend-adjusted close |
| SPY-only Weinstein | +408.0% | +6.1% | Spy_only_weinstein, 30-week investor MA, long/flat |
| Sector-ETF Weinstein | +528.9% | +6.9% | Sector_rotation_weinstein k=3, 30-week investor MA, RS vs SPY |

Regenerate: `dune exec trading/backtest/readme_toplines/bin/readme_toplines.exe -- --readme README.md` (run inside the dev container).
<!-- toplines:end -->

### Deep multi-decade backtests

The table above is the light reference set (auto-regenerated). For the **heavy
multi-decade broad-universe runs** (top-3000 PIT-1998 and sp500-515, 1998/2000–2026,
long-only + long-short, with the realized-vs-MTM and liquidity caveats), see
[`dev/backtest/DEEP_RESULTS.md`](dev/backtest/DEEP_RESULTS.md) — the results-of-record,
each row pinned to its scenario sexp and measurement commit. Those runs are
experiment-only (reproducible locally against the deep data dir; skipped on GHA).