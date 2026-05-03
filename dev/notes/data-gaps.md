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

**Status**: Open (filed 2026-05-03; recurrence is structural, not one-off)
**Blocks**: Nothing critical — the 491 symbols in `trading/test_data/backtest_scenarios/universes/sp500.sexp` are sufficient for current goldens. The 12 missing are recent additions or delistings without downloaded history.
**Affects**: `goldens-sp500/` scenarios (slight under-coverage, pinned at generation time so reproducibility is preserved); future Wiki+EODHD replay (`dev/plans/wiki-eodhd-historical-universe-2026-05-03.md`) inherits the same pattern.

### Background

S&P 500 actually has **503 securities** (5 dual-class: GOOG/GOOGL, NWSA/NWS, FOXA/FOX, BRK.A/BRK.B, etc). Today's `sp500.sexp` has 491 — i.e. 12 of 503 are not in our local CSV cache. Header comment on the file already notes this.

### Resolution

**ops-data dispatch**:
1. Re-run the join script that produced `sp500.sexp` (currently inline; should be extracted to `dev/scripts/build_sp500_universe.sh` per the file's TODO).
2. Identify the 12 symbols missing from the local cache.
3. Fetch via `analysis/scripts/fetch_symbols.exe -- --symbols <comma-list>`.
4. Rebuild inventory via `analysis/scripts/build_inventory/build_inventory.exe`.
5. Regenerate `sp500.sexp` (now 503 symbols).
6. Update this entry to **RESOLVED** with resolution date.

**Estimated effort**: ~30 min ops-data dispatch (mostly fetch wall + golden regen).

### Recurrence pattern (structural, not one-off)

The same gap reappears at any historical date — when Wiki+EODHD replay (PR-A/B/C of `wiki-eodhd-historical-universe-2026-05-03.md`) lands and emits historical-date universe sexps, each will reference symbols not in the local cache (delisted issues, recent IPOs).

Plan locks the fix into PR-C: `build_universe.exe --fetch-prices` auto-fetches on cache miss, closing the gap at construction time. **ops-data is not the routine resolver** for replay-driven universes — the build CLI itself fetches. ops-data still owns gap-by-symbol resolution for static `sp500.sexp` regeneration.

### What's needed

- **ops-data**: extract `dev/scripts/build_sp500_universe.sh` from inline join logic; fetch the 12 missing; regenerate `sp500.sexp`. Independent task — not blocked.
- **feat-data** (downstream): build_universe.exe in PR-C (Wiki+EODHD plan) replicates this pattern with `--fetch-prices` auto-fetch.

---

## Resolution ownership

Data fetching and inventory: **ops-data** agent
EODHD API tier upgrade decision: **human**
Alternative ADL source research: **human** (or ops-data if a source is identified)
Strategy wiring once data available: **feat-weinstein** agent
Historical-universe replay infrastructure: **feat-data** agent
