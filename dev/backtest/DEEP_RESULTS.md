# Deep backtest results-of-record (multi-decade, broad + sp500)

Headline numbers for the **heavy, multi-decade** backtests that are too large to
regenerate in the README auto-block (`readme_toplines` runs only the light
single-instrument / sector reference strategies). These are **experiment-only /
GHA-skipped** runs — reproducible **locally** against the production deep data
dir, not part of any CI/nightly tier. Each row pins its exact scenario sexp +
config + the commit it was measured at.

**How to read these:** broad-universe absolute returns are heavily **mark-to-market
(MTM)** on a few concentrated fat-tail winners and include untradeable illiquid
names — they are NOT bankable as realized P&L. See the caveats column + the
liquidity-overlay row. The honest comparison is *vs the index over the same window*
and *realized vs MTM*, not the raw absolute.

## Broad — top-3000 PIT-1998, 1998-01-01 .. 2026-04-30 (28.3y), Cell-E 0.14 concentration

| Sleeve / config | Total return | CAGR | Sharpe | MaxDD | Worst day | Scenario sexp | Notes |
|---|---|---|---|---|---|---|---|
| **Long-only** | +721.4% | 7.72% | 0.488 | 43.8% | −13.75% | `broad-top3000-1998-longonly.sexp` | baseline, no short leg; NAV never < $1.0M; worst day is a real 2020-05-01 COVID move |
| **Long-short**, margin OFF | +1421.9% | 10.1% | 0.554 | 55.5% | −48.05% | `broad-top3000-1998-longshort-margin-off.sexp` | free-leverage baseline; the −48% day is the ELCO illiquid-junk artifact |
| **Long-short**, margin ON | +1358.1% | 9.9% | 0.552 | 55.4% | −48.05% | `broad-top3000-1998-longshort-margin-on.sexp` | margin non-deflating (issue #859); NAV never < $0.89M |
| **Long-short**, margin ON + **liquidity overlay armed** | +773.6% | 7.9% | — | 41.5% | **−8.45%** | `broad-top3000-1998-longshort-margin-on.sexp` + `liquidity_config (min_entry 1e6 min_hold 5e5)` | ELCO gated, 6 liquidity_exits; removes fake illiquid MTM both directions → honest tradeable number (PR #1760) |

**Two honest readings of this block:**
1. **The short leg adds almost nothing once junk is stripped.** Long-only **+721%** ≈
   liquidity-armed long-short **+774%**. The un-armed long-short **+1358%** was inflated
   by ELCO-class fake illiquid MTM on *both* sides (a fake −$1.84M short loss on ELCO
   AND fake +$1.1M penny-long "wins" like APPB at $0.42 / $9.5K ADV). Strip the
   untradeable names and the two sleeves converge.
2. **Both honest numbers underperform the index.** Same-window **SPY total return
   +1088.7% / 9.13%/yr** (dividend-adjusted) beats both the long-only (7.72%/yr) and the
   liquidity-armed long-short (7.9%/yr). Only the *junk-inflated* +1358% beat SPY. So
   the deep broad top-3000 at 0.14 concentration, measured honestly, is **below
   SPY buy-and-hold** — consistent with the structural-bar finding (Weinstein is
   winner-touching → expect ≈index, and the broad MTM "edge" was an artifact). At the
   production 0.30 concentration the number is higher (more fat-tail MTM) but the
   realized/tradeable picture is the same shape.

## sp500-515 PIT-2000, 2000-01-01 .. 2026-04-30 (26.3y), Cell-E 0.14 concentration

| Sleeve / config | Total return | CAGR | Sharpe | MaxDD | Min NAV | Scenario sexp |
|---|---|---|---|---|---|---|
| Long-short, margin OFF | +2023.1% | 12.0% | 0.893 | 25.2% | $968,932 | `sp500-2000-longshort-margin-off.sexp` |
| Long-short, margin ON | +2074.6% | 12.2% | 0.914 | 25.2% | $968,932 | `sp500-2000-longshort-margin-on.sexp` |

Caveat: sp500-2000 is PIT-as-of-2000 → **survivorship-tinted** (the 515 names in the
S&P at 2000 that survived); inflates vs a delisting-complete universe.

## Reproduce locally

Scenarios live in `dev/experiments/short-realism-deep-2026-06-26/scenarios/`.
N=3000 (broad) requires snapshot mode (CSV OOMs the container); sp500 (515) runs in
CSV mode. From the dev container:

```bash
# broad (snapshot mode) — build the warehouse first if absent:
#   build_scenario_snapshots over top-3000-1998 incl. the ~15 macro/index/sector-ETF
#   context symbols (else the macro gate blocks all entries).
TRADING_DATA_DIR=/workspaces/trading-1/data \
  scenario_runner.exe --dir <scenarios-subset> \
    --fixtures-root trading/test_data/backtest_scenarios \
    --snapshot-dir /tmp/snap_top3000_1998_2026_v2 --no-emit-all-eligible --parallel 1

# sp500 (CSV mode): same minus --snapshot-dir.
```

Raw outputs (`trades.csv`, `equity_curve.csv`, `actual.sexp`) land under
`dev/backtest/scenarios-<timestamp>/` which is **gitignored / ephemeral** — re-run
from the sexp to regenerate. The forensic `.snap` inspector is
`trading/backtest/snapshot_warehouse/dump_snap`.

## Provenance

- Measured 2026-06-26 on `main` post-A-D-live-flip (#1725), post-concentration-0.30
  re-pin (#1753, but these cells pin 0.14 for long-only↔long-short comparability).
- Long-short cells + caveats: `dev/notes/short-realism-deep-broad-2026-06-26.md`,
  `dev/notes/short-realism-reconcile-2026-06-26.md`.
- Liquidity overlay (the armed row): PR #1760, `dev/notes/liquidity-realism-overlay-2026-06-26.md`.
