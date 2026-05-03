# Data Gaps — features blocked on missing data

Last updated: 2026-05-03 (sp500 universe coverage gap resolved; ADL source validation complete; sector ETF bars refreshed)

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

**Status**: Cached and wired into strategy (PR #355, 2026-04-12)  
**Blocks**: None — data is fetched and consumed.  
**Affects**: `Macro.analyze ~global_index_bars`

### Current state
- GSPC.INDX (S&P 500): cached, 1927-12-30 to 2026-04-09 — VERIFIED
- GDAXI.INDX (DAX): cached, 1980-01-02 to 2026-04-09 — VERIFIED
- N225.INDX (Nikkei 225): cached, 1965-01-05 to 2026-04-10 — VERIFIED
- **FTSE 100 via `ISF.LSE` (iShares Core FTSE 100 UCITS ETF)** — **DECISION: use as proxy** (2026-04-10). Physical-replication tracker, ~bps tracking error, functionally indistinguishable from the index at weekly cadence. `UKX.INDX` returned empty; `ISF.LSE` fetched successfully (6,552 bars, 2000-05-02 to 2026-04-10) — VERIFIED (2026-04-11).

### What's needed
- Nothing. Strategy wiring landed via PR #355. Keep the cache fresh
  via the weekly refresh — no outstanding data-gap action.

---

## sp500 Universe Coverage — 12 Missing Symbols

**Status**: RESOLVED (2026-05-03)
**Blocks**: Nothing critical — resolved. `sp500.sexp` now has all 503 symbols.
**Affects**: `goldens-sp500/` scenarios — coverage now complete.

### Background

S&P 500 actually has **503 securities** (5 dual-class: GOOG/GOOGL, NWSA/NWS, FOXA/FOX, BRK.A/BRK.B, etc). The original `sp500.sexp` had 491 — the 12 missing were already in the local bar-data cache but were dropped by the original join due to two issues:
1. Single-letter symbols (A, C, D, F, J, L, O, Q, T, V) — the original regex `\w+` stopped at word boundaries and dropped single-char matches.
2. Dot-notation symbols (BF.B, BRK.B) — the original join compared sp500.csv dot-form against inventory dash-form (BF-B, BRK-B) without normalisation.

No new data fetches were required. All 12 symbols had full bar history in the local cache.

### Resolution (2026-05-03)

1. Identified the 12 missing symbols: A, BF-B, BRK-B, C, D, F, J, L, O, Q, T, V.
2. All 12 confirmed present in `data/inventory.sexp` with bar history.
3. Extracted join logic into `dev/scripts/build_sp500_universe.sh` (closes the TODO in the original sp500.sexp header comment). The script handles:
   - Single-letter tickers
   - Dot-to-dash normalisation (BF.B → BF-B, BRK.B → BRK-B)
   - Quoted CSV fields with embedded commas in Security names (e.g. "F5, Inc.", "Tapestry, Inc.") using sector-name scanning instead of fixed field indexing
4. Ran `dev/scripts/build_sp500_universe.sh` — output: 503 / 503 symbols.
5. `sp500.sexp` regenerated from 491 → 503 symbols.

Symbols added: A (Health Care), BF-B (Consumer Staples), BRK-B (Financials), C (Financials), D (Utilities), F (Consumer Discretionary), J (Industrials), L (Financials), O (Real Estate), Q (Information Technology), T (Communication Services), V (Financials).

### Recurrence pattern (structural, not one-off)

The same gap reappears at any historical date — when Wiki+EODHD replay (PR-A/B/C of `wiki-eodhd-historical-universe-2026-05-03.md`) lands and emits historical-date universe sexps, each will reference symbols not in the local cache (delisted issues, recent IPOs).

Plan locks the fix into PR-C: `build_universe.exe --fetch-prices` auto-fetches on cache miss, closing the gap at construction time. **ops-data is not the routine resolver** for replay-driven universes — the build CLI itself fetches. `dev/scripts/build_sp500_universe.sh` is the tool for static `sp500.sexp` regeneration.

### What's needed going forward

- **feat-data** (downstream): build_universe.exe in PR-C (Wiki+EODHD plan) replicates this pattern with `--fetch-prices` auto-fetch.
- **ops-data** (maintenance): re-run `dev/scripts/build_sp500_universe.sh` whenever `data/sp500.csv` is updated (S&P 500 adds/removes).

---

## Resolution ownership

Data fetching and inventory: **ops-data** agent
EODHD API tier upgrade decision: **human**
Alternative ADL source research: **human** (or ops-data if a source is identified)
Strategy wiring once data available: **feat-weinstein** agent
Historical-universe replay infrastructure: **feat-data** agent
