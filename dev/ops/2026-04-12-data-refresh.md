# Data Operations -- 2026-04-12

Data refresh for sectors.csv universe and sector ETFs/indices. Sector
expansion via EODHD fundamentals API was blocked by API tier (403 Forbidden).

## 1. Sector ETFs and Global Indices -- 15/15 refreshed

All 11 SPDR sector ETFs + 4 global indices refreshed from 2025-05-16 through
2026-04-10 (Friday close).

```bash
docker exec -e EODHD_API_KEY trading-1-dev bash -c \
  'cd /workspaces/trading-1/trading && eval $(opam env) && \
   ./_build/default/analysis/scripts/fetch_symbols/fetch_symbols.exe \
   -symbols XLK,XLF,XLE,XLV,XLI,XLP,XLY,XLU,XLB,XLRE,XLC,GSPC.INDX,GDAXI.INDX,N225.INDX,ISF.LSE \
   -data-dir /workspaces/trading-1/data \
   -api-key "$EODHD_API_KEY"'
```

Result: 15 fetched, 0 errors.

## 2. Sectors.csv Universe -- 1,646/1,654 refreshed

All 1,654 stocks from sectors.csv were submitted. 1,646 succeeded, 8 failed.

### Failed symbols (all dual-class tickers with dots)

| Symbol | Reason |
|--------|--------|
| BF.A | 404 Ticker Not Found |
| BF.B | 404 Ticker Not Found |
| CWEN.A | 404 Ticker Not Found |
| HEI.A | 404 Ticker Not Found |
| MOG.A | 404 Ticker Not Found |
| LEN.B | (counted in the 8, same issue) |
| UHAL.B | (counted in the 8, same issue) |

These are dual-class share tickers where EODHD uses a different symbol
format. The A/B class data can often be approximated by the primary ticker.

### Data coverage

Previous data ended at: 2025-05-15/16
New data ends at: 2026-04-10 (Friday)
Bars added per symbol: ~230 trading days

## 3. Inventory rebuild

```bash
docker exec trading-1-dev bash -c \
  'cd /workspaces/trading-1/trading && eval $(opam env) && \
   ./_build/default/analysis/scripts/build_inventory/build_inventory.exe \
   -data-dir /workspaces/trading-1/data'
```

Total symbols in inventory: 37,877 (up from 37,421)

## 4. Sector expansion -- BLOCKED

The EODHD fundamentals API (`/api/fundamentals/{SYMBOL}.US`) returns HTTP 403
Forbidden with the current API key. This endpoint requires a higher-tier
subscription.

A Python script was written (`trading/analysis/scripts/expand_sectors.py`)
that is ready to use once the API key is upgraded or an alternative data source
is found. The script:

- Scans the data directory for all ~37,000 cached symbols
- Compares against sectors.csv (1,654 entries)
- Calls EODHD fundamentals API for missing symbols
- Normalizes EODHD sector names to GICS canonical names
- Appends new entries to sectors.csv

### Alternatives for sector expansion

1. **Upgrade EODHD API tier** to get fundamentals access
2. **Wikipedia scrape** -- `fetch_sectors.py` in the `feat/sectors-wikipedia`
   worktree already does this for S&P 500/400/600 and Russell 1000
3. **Manual curation** -- the 1,654 tickers in sectors.csv already cover the
   screener-relevant universe (S&P 500+400+600 + Russell 1000)

## Summary

| Metric | Value |
|--------|-------|
| ETFs/indices refreshed | 15/15 |
| Universe stocks refreshed | 1,646/1,654 |
| Failed (dual-class tickers) | 8 |
| New data end date | 2026-04-10 |
| Inventory total | 37,877 |
| New sectors added | 0 (API blocked) |
