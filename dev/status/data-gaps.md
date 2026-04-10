# Data Gaps — features blocked on missing data

Last updated: 2026-04-10

## A-D Breadth (ADL)

**Status**: No data source identified  
**Blocks**: Full macro analysis (currently passes `~ad_bars:[]`, degrades gracefully)  
**Affects**: `Macro.analyze` — ADL indicators (`_ad_line_signal`, `_momentum_index_signal`) return zero weight when `ad_bars` is empty

### What we tried
- EODHD `ADV.NYSE` / `DEC.NYSE`: "Ticker Not Found". Not available on this platform.

### What's needed
- Alternative data source for NYSE daily advancing/declining issue counts
- New parser — ADL data is not OHLCV format
- Once available: wire into `Weinstein_strategy.on_market_close` (line ~272, currently hardcoded `~ad_bars:[]`)

### Impact of gap
- Macro trend detection works but misses breadth divergence signals
- Weinstein methodology relies on ADL for confirming/denying market trends
- E2e tests verify graceful degradation (`test_macro_degrades_without_breadth`)

---

## Sector Analysis

**Status**: Module implemented, data not populated  
**Blocks**: Screener sector filter, portfolio sector concentration limits  
**Affects**: `Sector.analyze`, `Screener.screen` (receives empty `~sector_map`), `Portfolio_risk.check_sector_limits`

### Three gaps

1. **Sector ETF bars** — Need weekly bars for sector index ETFs (e.g. XLK, XLF, XLE). Not yet cached. Once cached, feed into `Sector.analyze ~sector_bars`.

2. **Instrument sector metadata** — `Instrument_info.sector` is empty for all symbols.
   - `bootstrap_universe.exe` leaves sector/industry blank by design (offline tool)
   - `fetch_universe.exe` populates name/exchange but not sector/industry
   - EODHD `get_fundamentals` endpoint returns sector data but requires a higher API tier
   - Until populated: screener cannot group stocks by sector, portfolio risk cannot enforce sector concentration limits

3. **Strategy wiring** — `Weinstein_strategy.on_market_close` creates an empty `sector_map` (line ~213). Once sector data is available, build the map from `Sector.analyze` results and pass to `Screener.screen`.

### Impact of gap
- Screener runs without sector context — a stock in a weak sector gets the same treatment as one in a strong sector
- Portfolio risk sector concentration checks are effectively bypassed
- Weinstein methodology considers sector strength a key factor (Ch. 3: "favorable chart in bullish group → 50-75% advance; same chart in bearish group → 5-10% gain")

---

## Global Index Bars

**Status**: Partially cached  
**Blocks**: Full macro global breadth analysis  
**Affects**: `Macro.analyze ~global_index_bars`

### Current state
- GSPC.INDX (S&P 500): cached, 24,684 bars
- GDAXI.INDX (DAX): cached, 11,838 bars
- N225.INDX (Nikkei 225): cached, 15,735 bars
- FTSE.INDX: Not on EODHD (returns `[]`). `ISF.LSE` (ETF) is a possible proxy — decision pending.

### What's needed
- Decision on FTSE proxy (or skip)
- Wire cached global index bars into strategy (currently passes `~global_index_bars:[]`)

---

## Resolution ownership

Data fetching and inventory: **ops-data** agent  
EODHD API tier upgrade decision: **human**  
Alternative ADL source research: **human** (or ops-data if a source is identified)  
Strategy wiring once data available: **feat-weinstein** agent
