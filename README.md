# trading

[![CI](https://github.com/dayfine/trading/actions/workflows/ci.yml/badge.svg)](https://github.com/dayfine/trading/actions/workflows/ci.yml)

A semi-automated trading system implementing Stan Weinstein's stage-analysis
methodology. See `docs/design/` for the system design and the Weinstein book
reference.

The results below are regenerated mechanically by
`trading/backtest/readme_toplines`. Two marker-delimited blocks are maintained,
each overwritten on regeneration — do not hand-edit between the markers:

- the **deep-headline** block — the heavy multi-decade broad-universe
  results-of-record, rendered from the pinned records in
  [`dev/backtest/deep_headline_records.sexp`](dev/backtest/deep_headline_records.sexp)
  (these runs use an out-of-repo warehouse and are **not** recomputed by CI);
- the **light-reference** block — recomputed by running the reference strategies
  end-to-end (period derived from actual bar coverage in the CSV store).

<!-- deep-headline:start -->
### Deep multi-decade headline (results-of-record)

| Result | Total return | Max DD | Trades | Win rate | Period |
|---|---|---|---|---|---|
| Weinstein top-3000 (promoted config) | +8,689% | 30.3% | 1,170 | 38.4% | 2000-01-01 -> 2026-06-26 |
| SPY total return (same window, comparator) | +706% | — | — | — | 2000-01-01 -> 2026-06-26 |
| Pre-bundle record (superseded) | +7,914% | 32.3% | 1,187 | — | 2000-01-01 -> 2026-06-26 |

Provenance (scenario / commit / date):
- **Weinstein top-3000 (promoted config)** — `test_data/backtest_scenarios/staging-leverf-28y/top3000-2000-2026-rcb-f000.sexp` @ 6a2d9b426 (PR #2047 — promoted bundle: w30 + virgin-crossing + floors-zero) (2026-07-23)
- **SPY total return (same window, comparator)** — `n/a — dividend-adjusted SPY buy & hold` @ DEEP_RESULTS.md record-of-record standing comparator (2026-07-14)
- **Pre-bundle record (superseded)** — `test_data/backtest_scenarios/staging-record-convention/top3000-2000-2026-record-convention.sexp` @ 0a2e4562d (PR #1960, Run D, dedup-v2 warehouse; DEEP_RESULTS record-of-record 2026-07-14) (2026-07-14)

_Basis: mark-to-market, including open-position marks on a few concentrated fat-tail winners and (unless a liquidity overlay is armed) untradeable illiquid names — NOT bankable as realized P&L. The honest read is vs the index over the same window and realized-vs-MTM. Full pins + caveats: [`dev/backtest/DEEP_RESULTS.md`](dev/backtest/DEEP_RESULTS.md)._
<!-- deep-headline:end -->

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

### Margin & trade-safety model

Short selling and tradeability are modeled against real broker/regulatory rules
(Reg-T 150% short collateral, FINRA 4210 maintenance, daily borrow fee, a $17
short-price floor for the 30% maintenance tier, force-liquidation/halt, and a
default-off liquidity-realism overlay with an entry $-ADV gate + held-degradation
exit). All controls are **default-off no-ops** — defaults reproduce a frictionless
long-only engine bit-for-bit. See
[`docs/design/margin-safety.md`](docs/design/margin-safety.md) for the full mapping
to broker requirements.
