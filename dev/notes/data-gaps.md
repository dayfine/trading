# Data Gaps — features blocked on missing data

Last updated: 2026-04-14 (sharpened actionability per gap; scrape research moved into ops-data scope)

## A-D Breadth (ADL)

**Status**: Candidate sources identified; needs validation  
**Blocks**: Full macro analysis (currently passes `~ad_bars:[]`, degrades gracefully)  
**Affects**: `Macro.analyze` — ADL indicators (`_ad_line_signal`, `_momentum_index_signal`) return zero weight when `ad_bars` is empty

### What we tried
- EODHD `ADV.NYSE` / `DEC.NYSE`: "Ticker Not Found". Not available on this platform.

### Candidate sources (ranked, 2026-04-10 research)

1. **Yahoo Finance `C:ISSU` (NYSE) / `C:ISSQ` (NASDAQ)** — daily adv/dec/unchanged. Accessible via `yfinance` Python library or scraping. Free. **Needs validation**: does the symbol actually work? What historical coverage? What's the non-OCHLCV response format?
2. **EODData.com `INDEX:ADRN`** — NYSE Advance-Decline Ratio, up to 30 years of EOD quotes, downloadable in multiple formats. Free/low-cost. **Needs validation**: is ADRN a ratio (adv/dec) or absolute counts? Scraper required.
3. **Unicorn.us.com `advdec`** — comma-delimited historical A-D data for major indexes, free, computed from public sources. **Needs validation**: freshness, licence.
4. **Compute from Russell 3000 universe** — count advancers/decliners across the cached universe each day. Tradeoffs: universe mismatch with official NYSE (no ETFs/ADRs/preferreds/CEFs), survivorship bias from current-constituents, but should correlate well. Fallback if scraper options fail. **Cost**: need Russell 3000 bars cached first (~3000 symbols × daily bars).

### What's needed (orchestrator-actionable)
- **ops-data**: write a probe script per candidate source under
  `dev/scripts/probes/`, fetch 30 days of sample data, write findings
  to `dev/notes/adl-validation.md` (parse-ability, historical depth,
  rate limits, license). No EODHD key required for any of these
  sources. **This is dispatchable today** — no human input needed.
- After validation: write the production parser for the winning source,
  add a fetch script alongside `fetch_symbols.exe`.
- Once cached: feat-weinstein wires into `Weinstein_strategy.on_market_close`
  (line ~288, currently hardcoded `~ad_bars:[]`). NOTE: feat-weinstein's
  current scope is closed — surface as escalation if so.

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

1. **Sector ETF bars** — daily bars for XLK, XLF, XLE, XLV, XLI, XLP,
   XLY, XLU, XLB, XLRE, XLC. **Dispatchable when EODHD_API_KEY is set
   in the host env** (`[ -n "$EODHD_API_KEY" ]`). Skip and surface as
   escalation only if truly absent. Fetch:
   ```
   docker exec -e EODHD_API_KEY trading-1-dev bash -c \
     'cd /workspaces/trading-1/trading && eval $(opam env) && \
      ./_build/default/analysis/scripts/fetch_symbols/fetch_symbols.exe \
      --symbols XLK,XLF,XLE,XLV,XLI,XLP,XLY,XLU,XLB,XLRE,XLC \
      --data-dir /workspaces/trading-1/data \
      --api-key "$EODHD_API_KEY"'
   ```
   Then rebuild inventory with `build_inventory.exe`. Once cached, feed into `Sector.analyze ~sector_bars`.

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
