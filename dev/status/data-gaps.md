# Data Gaps — features blocked on missing data

Last updated: 2026-04-10 (ADL Phase C + sector/global strategy-side wiring landed on feat/strategy-wiring)

## A-D Breadth (ADL)

**Status**: RESOLVED for the historical backtest window (1965-03-01 → 2020-02-10). Phase C strategy wiring complete.
**Blocks**: None for backtesting. Live-mode bridge (Phase B, Russell 3000 compute-from-universe) optional and not yet built.
**Affects**: `Macro.analyze` now receives real `ad_bars` from `Weinstein_strategy.Ad_bars.load ~data_dir`, wired through the strategy's `make` closure via the new `?ad_bars` parameter.

### What landed
- Phase A (2026-04-10, ops-data): `data/breadth/nyse_advn.csv` + `data/breadth/nyse_decln.csv` downloaded from unicorn.us.com (13,873 rows each, 1965–2020).
- Phase C (2026-04-10, feat-weinstein, branch `feat/strategy-wiring`):
  - New `Weinstein_strategy.Ad_bars.load : data_dir:string -> Macro.ad_bar list` loader. Joins the two CSVs on date, filters (0,0) placeholder rows, sorts chronologically, returns `[]` if either file is missing.
  - New `?ad_bars` optional parameter on `Weinstein_strategy.make`. Default `[]`, so existing callers compile unchanged. Callers that want breadth data call `let ad_bars = Ad_bars.load ~data_dir in make ~ad_bars config`.
  - `_on_market_close` now forwards the closure-held `ad_bars` to `Macro.analyze` on every screening call.
  - Unit tests: 8 cases covering missing files, basic parse, (0,0) placeholder filter, chronological sort, malformed-row skip, unmatched-date drop, and a real-data integration check (opt-in; skipped when `/workspaces/trading-1/data/breadth/` is absent).

### What's still open (NOT blocking backtesting)
- **Phase B — live bridge from 2020-02-11 to present**: compute `advancers = count(close > prev_close)`, `decliners = count(close < prev_close)` across the Russell 3000 universe, append to the combined CSV. Owner: ops-data, when live trading is prioritised.

---

## Sector Analysis

**Status**: Strategy-side wiring complete; per-stock join still blocked on instrument metadata.
**Blocks**: Screener sector filter still degrades to Neutral for every stock (because the `sector_map` is keyed by ETF symbol, and the screener looks up by stock ticker). Portfolio sector concentration limits remain bypassed.
**Affects**: `Sector.analyze` is now exercised; `Screener.screen` receives a non-empty `~sector_map` when sector ETFs are configured.

### Three gaps

1. **Sector ETF bars** — **RESOLVED** (2026-04-10, ops-data). All 11 SPDR sector ETFs are cached under `data/X/{K,F,E,V,I,P,Y,U,B,E,C}/XL*/` with weekly bars since ~1998.

2. **Instrument sector metadata** — STILL OPEN. `Instrument_info.sector` is empty for all symbols.
   - `bootstrap_universe.exe` leaves sector/industry blank by design (offline tool)
   - `fetch_universe.exe` populates name/exchange but not sector/industry
   - EODHD `get_fundamentals` endpoint returns sector data but requires **Fundamentals Data Feed** tier at **$59.99/mo**
   - **Decision pending**: upgrade tier, or use alternative source. See `dev/status/fundamentals-requirements.md`.
   - Parallel work on `sectors-wikipedia` branch adds a Wikipedia-derived GICS sector map — once it lands, the `sector_map` key scheme can migrate from ETF-symbol to stock-ticker.
   - Until populated: the screener's sector gate still falls through to Neutral on every stock lookup.

3. **Strategy wiring** — **RESOLVED** (2026-04-10, feat-weinstein, branch `feat/strategy-wiring`):
   - New `config.sector_etfs : (string * string) list` field. Default empty; callers populate with e.g. `Weinstein_strategy.Macro_inputs.spdr_sector_etfs`.
   - `_on_market_close` accumulates daily bars for each configured ETF in the same per-symbol `bar_history` hashtable as the universe tickers (via `get_price`).
   - On screening days, `Macro_inputs.build_sector_map` runs `Sector.analyze` on each ETF's weekly bars + benchmark bars + empty `constituent_analyses`, and emits `(etf_symbol, sector_context)` entries into the map passed to `Screener.screen`.
   - Prior-stage accumulation for sector ETFs uses a dedicated `sector_prior_stages` hashtable in the closure, enabling Stage1->Stage2 transition detection across screening days.
   - **Caveat**: because `Screener.screen` looks up sector context by **stock ticker**, and the current map is keyed by **ETF symbol**, the lookup always misses and the screener still applies a Neutral sector gate. The pipeline is fully exercised end-to-end — only the final ticker -> sector -> ETF join is still absent. That join will land when instrument sector metadata is populated.

### Impact of gap (remaining)
- Screener still runs without per-stock sector scoring until gap (2) closes
- Portfolio risk sector concentration checks still bypassed until gap (2) closes

---

## Global Index Bars

**Status**: RESOLVED — data cached AND strategy wired (2026-04-10).
**Blocks**: None.
**Affects**: `Macro.analyze ~global_index_bars` now receives real bars on every screening call.

### Current state
- GSPC.INDX (S&P 500): cached, 1927-12-30 → 2026-04-09 — VERIFIED
- GDAXI.INDX (DAX): cached, 1980-01-02 → 2026-04-09 — VERIFIED
- N225.INDX (Nikkei 225): cached, 1965-01-05 → 2026-04-10 — VERIFIED
- `ISF.LSE` (iShares Core FTSE UCITS): cached, used as FTSE 100 proxy

### What landed (2026-04-10, feat-weinstein, branch `feat/strategy-wiring`)
- New `config.global_index_symbols : (string * string) list` field — `(index_symbol, label)` pairs. Default empty; `Weinstein_strategy.Macro_inputs.default_global_indices` exports the canonical (GDAXI, N225, ISF.LSE) triple. GSPC.INDX is intentionally omitted — it is already passed to `Macro.analyze` as `~index_bars`.
- `_on_market_close` accumulates bars for each global index alongside the universe.
- `Macro_inputs.build_global_index_bars` emits `(label, weekly_bars)` pairs for `Macro.analyze`. Indices with no accumulated bars yet are silently dropped.

---

## Resolution ownership

Data fetching and inventory: **ops-data** agent
EODHD API tier upgrade decision: **human**
Alternative ADL source research: **human** (or ops-data if a source is identified)
Strategy wiring once data available: **feat-weinstein** agent
