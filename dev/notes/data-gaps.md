# Data Gaps — features blocked on missing data

Last updated: 2026-04-14 (ADL source validation complete; sector ETF bars refreshed)

## A-D Breadth (ADL)

**Status**: Validation complete (2026-04-14). No single source provides live absolute counts without registration. See `dev/notes/adl-validation.md`.  
**Blocks**: Full macro analysis (currently passes `~ad_bars:[]`, degrades gracefully)  
**Affects**: `Macro.analyze` — ADL indicators (`_ad_line_signal`, `_momentum_index_signal`) return zero weight when `ad_bars` is empty

### What we tried
- EODHD `ADV.NYSE` / `DEC.NYSE`: "Ticker Not Found". Not available on this platform.

### Source validation results (2026-04-14)

Probe scripts under `dev/scripts/probes/`. Full writeup in `dev/notes/adl-validation.md`.

1. **Yahoo Finance `^ADV` / `^DECL` / `C:ISSU` / `C:ISSQ`** — **REJECTED**. All symbols return "No data found, symbol may be delisted" on Yahoo v8 chart API.
2. **EODData.com `INDEX:ADRN`** — **VIABLE (ratio only)**. Public HTML page with OHLCV of the advance-decline ratio (2015-present). However, ADRN is a ratio, not absolute counts. Need to check if `INDEX:ADVN`/`INDEX:DECL` exist as separate symbols. **Requires EODData free-tier registration** (human action) for CSV/API access.
3. **Unicorn.us.com `advdec`** — **DEAD since Feb 2020**. Site explicitly stopped updating. Historical archive (2002-2020) has excellent format: CSV with NYSE/AMEX/NASDAQ absolute counts. Useful for backtest backfill only.
4. **Compute from Russell 3000 universe** — still viable as fallback. Tradeoffs unchanged.

### What's needed (human input required)
- **Human**: register for EODData free tier and check if `INDEX:ADVN`/`INDEX:DECL` exist as separate symbols with absolute counts (not just ratio)
- **Human**: evaluate Pinnacle Data (recommended by Unicorn as successor) — cost/license
- **ops-data (after human input)**: write the production parser for the winning source, add a fetch script alongside `fetch_symbols.exe`
- **ops-data (independent)**: optionally download Unicorn 2002-2020 archive for backtest backfill (~4,500 per-day files, trivially parseable)
- **feat-weinstein (after data cached)**: wire into `Weinstein_strategy.on_market_close` (line ~288, currently hardcoded `~ad_bars:[]`)

### Impact of gap
- Macro trend detection works but misses breadth divergence signals
- Weinstein methodology relies on ADL for confirming/denying market trends
- E2e tests verify graceful degradation (`test_macro_degrades_without_breadth`)

---

## Sector Analysis

**Status**: Module implemented, data not populated  
**Blocks**: Screener sector filter, portfolio sector concentration limits  
**Affects**: `Sector.analyze`, `Screener.screen` (receives empty `~sector_map`), `Portfolio_risk.check_sector_limits`

### Three gaps (each with explicit ops-data dispatch criteria)

1. **Sector ETF bars** — **RESOLVED (2026-04-14)**. Daily bars cached for
   all 11 SPDR sector ETFs (XLK, XLF, XLE, XLV, XLI, XLP, XLY, XLU,
   XLB, XLRE, XLC) through 2026-04-14. Inventory rebuilt. Ready for
   `Sector.analyze ~sector_bars`.

2. **Instrument sector metadata** — `Instrument_info.sector` is empty
   for all symbols. **Dispatchable today** — the plan exists and
   doesn't require new human input.
   - `bootstrap_universe.exe` leaves sector/industry blank by design
   - `fetch_universe.exe` populates name/exchange but not sector/industry
   - **Plan**: see [`sector-data-plan.md`](./sector-data-plan.md) —
     fetch SPDR sector ETF holdings from SSGA. One data provider, no
     Python, automatic refresh cadence tied to ETF fetch. Covers ~500
     S&P 500 names; long-tail goes to the "unknown sector" bucket
     (`max_unknown_sector_positions = 2`, merged in #250).
   - **ops-data action**: execute the plan. The plan IS the spec.
   - **Deprecated**: the Wikipedia scrape approach (PRs #251/#252/#253,
     now closed). See deprecation note in
     [`fundamentals-requirements.md`](./fundamentals-requirements.md).
   - Until populated: screener can't group by sector; portfolio risk
     can't enforce sector limits for named sectors (unknown bucket
     enforced).

3. **Strategy wiring** — `Weinstein_strategy.on_market_close` creates an
   empty `sector_map` (line ~213). Feature work, not ops-data. Owner:
   feat-weinstein. NOTE: feat-weinstein's current scope is closed —
   surface as escalation if dispatched.

### Impact of gap
- Screener runs without sector context — a stock in a weak sector gets the same treatment as one in a strong sector
- Portfolio risk sector concentration checks are effectively bypassed
- Weinstein methodology considers sector strength a key factor (Ch. 3: "favorable chart in bullish group → 50-75% advance; same chart in bearish group → 5-10% gain")

---

## Global Index Bars

**Status**: Cached and verified (2026-04-10)  
**Blocks**: Strategy wiring only (data is available)  
**Affects**: `Macro.analyze ~global_index_bars`

### Current state
- GSPC.INDX (S&P 500): cached, 1927-12-30 to 2026-04-09 — VERIFIED
- GDAXI.INDX (DAX): cached, 1980-01-02 to 2026-04-09 — VERIFIED
- N225.INDX (Nikkei 225): cached, 1965-01-05 to 2026-04-10 — VERIFIED
- **FTSE 100 via `ISF.LSE` (iShares Core FTSE 100 UCITS ETF)** — **DECISION: use as proxy** (2026-04-10). Physical-replication tracker, ~bps tracking error, functionally indistinguishable from the index at weekly cadence. `UKX.INDX` returned empty; `ISF.LSE` fetched successfully (6,552 bars, 2000-05-02 to 2026-04-10) — VERIFIED (2026-04-11).

### What's needed (escalation territory)
- **feat-weinstein**: wire cached global index bars into strategy
  (currently passes `~global_index_bars:[]`). Feature work, not
  ops-data. NOTE: feat-weinstein's current scope is closed — surface
  as escalation when dispatched.

---

## Resolution ownership

Data fetching and inventory: **ops-data** agent  
EODHD API tier upgrade decision: **human**  
Alternative ADL source research: **human** (or ops-data if a source is identified)  
Strategy wiring once data available: **feat-weinstein** agent
