# Baseline Backtesting Plan

## Goal

Run the Weinstein strategy on a large stock universe across multiple time windows
to answer: "Does this system make money?" and identify missing pieces (drawdown
limits, trade frequency controls, etc).

## Data Assessment (2026-04-12)

**Ready:**
- All 11 SPDR sector ETFs: data through 2026-04-10
- All 4 indices (GSPC.INDX, GDAXI.INDX, N225.INDX, ISF.LSE): through 2026-04-10
- 37,406 stock symbols with data through 2025+
- Major stocks (AAPL, MSFT, AMZN, NVDA, etc.) through 2025-05-16

**Gaps:**
- ADL breadth data stops 2020-02-10 (zeros after). Macro signal still works
  via other indicators (index stage, momentum, global indices). Can compute
  synthetic ADL from universe advances/declines.
- Sector coverage: 1,654 stocks in sectors.csv out of ~37K data files. Most
  of the 37K are non-US equities, mutual funds, and delisted securities.
  Need to filter to active US equities and expand sector mapping.
- TSLA missing from data directory.
- Data ends 2025-05-16 — need to fetch through present for latest runs.

## Phases

### Phase 1: Data Readiness

- [ ] **Filter universe**: Identify active US equities from the 37K data files.
      Use EODHD exchange metadata or heuristics (has recent data, reasonable
      volume, listed on NYSE/NASDAQ).
- [ ] **Expand sector mapping**: Get GICS sectors for stocks beyond the current
      1,654. EODHD fundamentals API has sector data. Or use another source.
- [ ] **Fetch fresh data**: Update all symbols through present via EODHD.
- [ ] **ADL strategy**: Compute synthetic ADL from universe (count daily
      advances vs declines). Self-referential but sufficient for backtesting.
      Alternative: find external breadth data source.

### Phase 2: Backtest CLI Tool

Build an executable that runs backtests and writes structured output.

- [ ] **CLI executable**: `backtest_runner.exe`
  - Inputs: universe file, date range, initial cash, config overrides
  - Deterministic: same inputs → same outputs
- [ ] **Output structure**: Each run writes to `dev/backtest/<run-id>/`:
  ```
  dev/backtest/<run-id>/
    params.json        # inputs (see below)
    summary.json       # Sharpe, max drawdown, win rate, total P&L, trade count
    trades.csv         # all trades: date, symbol, side, qty, price, P&L
    equity_curve.csv   # daily: date, portfolio_value, cash, long_exposure
  ```
- [ ] **Params tracking** (recorded in params.json):
  - Code version: git commit SHA
  - Data version: last data date, number of symbols, sector coverage %
  - Strategy config: all knobs (stage, macro, screener, portfolio risk, stops)
  - Run params: date range, initial cash, commission config

### Phase 3: Baseline Runs

Run backtests across different market regimes.

- [ ] **Run 1**: Full universe, 2018-01-02 → 2023-12-29 (6yr, COVID + recovery)
- [ ] **Run 2**: Full universe, 2015-01-02 → 2020-12-31 (bull + crash)
- [ ] **Run 3**: Full universe, 2020-01-02 → 2024-12-31 (COVID crash + bull)
- [ ] **Run 4**: Random 5-year window in available range

### Phase 4: Analysis & Reflection

- [ ] **Performance**: Total P&L, Sharpe ratio vs buy-and-hold S&P 500
- [ ] **Risk**: Max drawdown, drawdown duration, does 20-25% threshold get hit?
- [ ] **Trade frequency**: Trades per year, avg holding period, turnover
- [ ] **Sector impact**: Performance with vs without sector gate
- [ ] **Missing pieces to consider**:
  - Portfolio-level drawdown circuit breaker (Weinstein Ch. 7)
  - Trade frequency limits
  - Re-entry criteria after "moving to sidelines"
  - Position time stops (cut if flat for N weeks)
  - Synthetic ADL quality vs external breadth data

## Open Questions

- Universe filtering: how to reliably identify "active US equities" from 37K files?
  Exchange metadata from EODHD is one approach.
- Performance: design doc targets <10 min for 10yr/5K symbols. Need to profile.
- ADL: compute from universe or fetch? Computing is self-referential but may be
  the pragmatic path.
