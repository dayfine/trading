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