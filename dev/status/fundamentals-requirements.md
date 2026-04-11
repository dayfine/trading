# Fundamentals Data Requirements

**Owner**: none — **DEPRECATED** (see [`sector-data-plan.md`](./sector-data-plan.md))
**Status**: DEPRECATED — Wikipedia scrape approach replaced by SPDR ETF holdings
**Last updated**: 2026-04-11

## DEPRECATED: Wikipedia scrape plan (superseded 2026-04-11)

The earlier plan in this doc recommended scraping S&P 500 / 400 / 600 + Russell 1000 Wikipedia pages via a Python stdlib script. **This plan is deprecated.** See [`sector-data-plan.md`](./sector-data-plan.md) for the replacement — use **SPDR ETF holdings files** instead.

Why the change:
1. **Python runtime reliability**: the container does not guarantee a working Python stdlib across upgrades. Either we invest in maintenance (pinning, CI check, doc) or we write the scraper in OCaml. Both are effort; the underlying question is whether Wikipedia is even the right source.
2. **Composition is incidental**: Wikipedia pages are being used as a two-for-one (constituents + sector tags). What we actually need is `ticker → sector`. Index composition is not a requirement.
3. **SPDR holdings files are authoritative**: State Street publishes daily holdings CSVs for each XL* ETF, including GICS sector tags direct from the fund manager. Same provider we already fetch prices from. Refresh cadence is naturally tied to the ETF fetch. No Wikipedia, no Python scraper, no staleness policy to enforce separately.

The deprecated candidate evaluation (yfinance, FMP, Finnhub, Wikipedia) is kept below for historical context. New work should follow [`sector-data-plan.md`](./sector-data-plan.md).

---

## What we actually need

The only fundamental field the Weinstein methodology **requires** is **sector**. Everything else is nice-to-have.

### Required: sector

**Used by**:
- `Portfolio_risk.check_sector_limits` (`portfolio_risk.mli:112`) — `max_sector_concentration` limits positions per sector (default 5)
- `Portfolio_risk.check_new_position ~proposed_sector` (`portfolio_risk.mli:177`) — blocks new positions that would exceed sector concentration
- `Sector.analyze` — sector health composite (combines stage of sector ETF + RS + constituent breadth)
- `Screener.screen ~sector_map` — weights candidates by their sector's Weinstein rating (Strong / Neutral / Weak)

**Weinstein principle** (Ch. 3): "favorable chart in bullish group -> 50-75% advance; same chart in bearish group -> 5-10% gain." Sector context is load-bearing to the strategy's edge.

**Granularity needed**: GICS-style sector is fine (11 buckets: Tech, Financials, Energy, Healthcare, Industrials, Consumer Staples, Consumer Discretionary, Utilities, Materials, Real Estate, Communication Services). Industry-level is not needed for the strategy — sector is sufficient.

**Update frequency**: Sector assignments are stable — an annual refresh is fine. This is NOT like price data that needs daily updates.

**Coverage needed**: All symbols in the trading universe (currently ~24,529 Common Stock + ETF instruments from EODHD).

### Nice-to-have but not required

- **industry** — finer than sector. Not used anywhere in current code.
- **market_cap** — could be used for position sizing or universe filtering.
- **name** / **exchange** — already populated via `fetch_universe.exe`.

## Current state

- `Instrument_info.sector` and `Instrument_info.industry` are **empty strings for all symbols**
- `bootstrap_universe.exe` explicitly leaves them blank (offline tool, no API calls)
- `fetch_universe.exe` populates name/exchange only
- `Weinstein_strategy.on_market_close` passes an empty `sector_map` to `Screener.screen` (line ~213)
- Sector concentration limits are therefore effectively bypassed

## Known source: EODHD Fundamentals Data Feed

- **Price**: $59.99/mo (standalone fundamentals-only plan; All-In-One at $99.99/mo is the other path)
- **Endpoint**: `get_fundamentals` — returns sector, industry, market_cap, exchange, name in one call
- **Integration**: already wired in `trading/analysis/data/sources/eodhd/lib/http_client.ml:217` — parser exists, just needs the API tier
- **Pros**: zero new code, one API call per symbol (~24k calls at upgrade time, then annual refresh)
- **Cons**: $720/yr recurring cost

## Validation results (2026-04-10)

### 1. Yahoo Finance quoteSummary (`assetProfile` / `fundProfile`) — PARTIAL

- **Endpoint**: `https://query2.finance.yahoo.com/v10/finance/quoteSummary/{symbol}?modules=assetProfile,fundProfile,topHoldings`
- **Auth**: requires a "crumb" cookie dance — hit `https://fc.yahoo.com` to get a cookie, then `https://query2.finance.yahoo.com/v1/test/getcrumb` to get the token, then append `&crumb=...` to each quoteSummary call. Easy but not zero-friction. `yfinance` automates this.
- **Common-stock coverage**: **GOOD**. Verified on AAPL, MSFT, TSLA, JNJ, BRK-B (use `BRK-B`, not `BRK.B`) — every one returned `assetProfile.sector` + `assetProfile.industry`. Labels are Yahoo's own 11-sector taxonomy (e.g. "Technology", "Healthcare", "Financial Services", "Consumer Cyclical") — close to GICS but not identical (GICS uses "Information Technology", "Consumer Discretionary", etc.). A small static remapping table is enough to normalise.
- **ETF coverage**: **WEAK for assetProfile**. SPY, XLK, QQQ, VTI all returned `assetProfile = {}`. ETFs expose sector only via `fundProfile.categoryName` ("Technology" for XLK) and `topHoldings.sectorWeightings` (breakdown percentages). `categoryName` is a Morningstar category, not GICS — and only applies to sector ETFs; broad ETFs like VTI return category "Large Blend", which isn't a sector at all.
- **Rate limit**: Soft ~360 req/hour; 429 "Too Many Requests" reported after bursts of ~950 tickers on some IPs (github.com/ranaroussi/yfinance issues #2128, #2480). For our ~24k universe: 24000/360 = ~67 hours of careful pacing, with ban risk. Realistic only with rotating IPs or very conservative pacing (a few thousand a day spread across days).
- **ToS**: Yahoo's terms prohibit "using any automated means" to access the site. Grey area for personal research use; blocker for any commercial redistribution.
- **Verdict**: Usable for a one-time bulk backfill of Common Stock if we accept slow pacing (~1 week wall-clock) + ban risk, but not ETFs.

### 2. Financial Modeling Prep (FMP) `/api/v3/profile` — LIMITED BY QUOTA

- **Endpoint**: `https://financialmodelingprep.com/api/v3/profile/{symbol}?apikey=...`
- **Auth**: free API key required (no credit card).
- **Free tier**: **250 requests/day**. At 24k symbols, that's **96 days** of bulk backfill — untenable as a primary source.
- **Coverage**: 70k+ global securities, sector + industry returned. Confirmed to include ETFs in their catalog (though with a loose "ETF" sector label on some entries).
- **ToS**: free tier is "for personal use and testing."
- **Verdict**: Not viable as bulk source. Useful as **incremental top-up** for newly-listed symbols Wikipedia doesn't cover (250/day is plenty for delta refreshes).

### 3. Finnhub `/stock/profile2` — NOT GICS

- **Endpoint**: `https://finnhub.io/api/v1/stock/profile2?symbol={symbol}&token=...`
- **Auth**: free API key required.
- **Critical**: Finnhub's `CompanyProfile2` schema **does NOT return a GICS-style sector**. It only returns "Finnhub industry classification" — a custom taxonomy. Fields are: Country, Currency, Exchange, `finnhubIndustry`, IPO date, Logo, Market Cap, Name, Phone, Share Outstanding, Ticker, Website.
- **ETF coverage**: ETFs supported via dedicated `/etf/profile`, `/etf/holdings`, `/etf/sector` endpoints (separate from `stock/profile2`).
- **Rate limit**: 60 calls/minute on free tier; 30 calls/second ceiling on all plans.
- **Verdict**: **Not a direct fit** — we'd need a Finnhub-industry -> GICS-sector mapping table. Skip unless all else fails.

### 4. Wikipedia constituent lists — WORKS, limited coverage

Direct HTML scrape, no auth, no rate limit, GICS Sector + Sub-Industry included as dedicated columns:

| Page | Rows | GICS Sector | GICS Sub-Industry | Sample column headers |
|------|-----:|:-----------:|:-----------------:|----------------------|
| `List_of_S%26P_500_companies` | 503 | YES | YES | Symbol, Security, GICS Sector, GICS Sub-Industry, HQ, Date added, CIK, Founded |
| `List_of_S%26P_400_companies` | 400 | YES | YES | Symbol, Security, GICS Sector, GICS Sub-Industry, HQ, SEC filings |
| `List_of_S%26P_600_companies` | 603 | YES | YES | Symbol, Security, GICS Sector, GICS Sub-Industry, HQ, SEC filings, CIK |
| `Russell_1000_Index` | 1006 | YES | YES | Company, Symbol, GICS Sector, GICS Sub-Industry |
| `Nasdaq-100` | n/a | — | — | No clean constituents table in the same format |

**Union coverage**: ~1500-1700 unique US equities (S&P 500+400+600 = "S&P 1500" composite plus Russell 1000 which overlaps heavily). Covers essentially all large/mid-cap US listings — the long tail (micro-caps, OTC, recent IPOs, ADRs, ETFs) is NOT covered.

- **Format**: static HTML `<table class="wikitable">`. ~4 HTTP requests total, parse with any regex or HTML lib.
- **Update frequency**: community-maintained, usually current within a day of index changes.
- **Licence**: CC BY-SA 4.0 — redistribution allowed with attribution. No ToS risk.
- **Critical gap**: **NO ETFs**. Weinstein strategy uses sector ETFs (XLK/XLF/XLE etc.) for sector health analysis — we need sector labels for them too. Can be hardcoded: the ~11 SPDR sector ETFs are a known fixed list.
- **Verdict**: **Primary free source for the ~1500 large/mid-cap US Common Stocks** that make up the effective Weinstein universe.

### 5. SEC EDGAR CIK -> SIC -> GICS

- `https://www.sec.gov/files/company_tickers_exchange.json` — 10,433 US-listed companies with CIK, name, ticker, exchange. **NO sector**.
- `https://data.sec.gov/submissions/CIK{padded}.json` — per-company, returns `sic` and `sicDescription`. Verified: AAPL returns `sic=3571, sicDescription="Electronic Computers"`.
- **Auth**: none, but SEC requires a descriptive `User-Agent` header with email.
- **Rate limit**: 10 requests/second (policy).
- **Coverage**: ~10k SEC-registered US issuers. **No ETFs** (ETFs file differently).
- **Engineering cost**: medium — requires a static SIC (~440 codes) -> GICS (11 sectors) mapping table. Such mappings exist publicly but aren't canonical and need vetting.
- **Verdict**: Viable backstop for the ~8k-9k Common Stocks not in Wikipedia index lists, but more integration work than it sounds.

## Recommendation

### **Top choice: free Wikipedia scrape + hardcoded sector-ETF map, fall back to EODHD upgrade when that becomes insufficient.**

#### Rationale

1. **Our real trading universe is much smaller than 24k.** The Weinstein screener filters on the cascade (macro OK -> Stage 2 -> RS > X -> volume -> resistance breakout). In practice it touches maybe 500-2000 symbols per week, heavily concentrated in liquid large/mid-cap names. The 20k "long tail" of nanocap / OTC / inactive names in `Instrument_info` are not candidates the strategy would ever take a position in, so **we don't actually need sector data for all 24k**.
2. **Wikipedia covers the universe that matters.** S&P 500 + S&P 400 + S&P 600 = the "S&P 1500 composite", which by market-cap covers ~90% of US equities that clear any reasonable liquidity filter. Union with Russell 1000 adds ~200 more large-cap names. That's the set `Screener.screen` will mostly output.
3. **Sector ETFs are a fixed list.** The ~11 SPDR sector ETFs (XLK, XLF, XLE, XLV, XLI, XLP, XLY, XLU, XLB, XLRE, XLC) plus a handful of alternatives (VNQ, GDX, SMH, etc.) are a static, hardcoded table. No API needed.
4. **This unblocks the real work now.** Sector metadata isn't the Weinstein strategy's bottleneck — screener quality and execution are. Spending $720/yr on EODHD fundamentals while the strategy doesn't yet have validated edge is premature.
5. **Two-step path.** Land the Wikipedia scraper now (low cost, low risk). Upgrade to EODHD later if and when walk-forward validation shows we need sector data on the long tail or on symbols Wikipedia doesn't cover.

#### Coverage estimate

| Source | Symbols covered | % of Weinstein-relevant universe |
|--------|---:|---:|
| Wikipedia S&P 500 + 400 + 600 + Russell 1000 | ~1,500-1,700 | ~85-90% of names the screener would pick |
| Hardcoded sector ETF list | ~15-20 ETFs | 100% of sector-ETF analysis inputs |
| **Gap** | ~22k long-tail + most non-sector ETFs | Names we'd effectively never trade anyway |

For the gap: `Instrument_info.sector` stays blank. `Portfolio_risk.check_sector_limits` should treat blank-sector positions as a special "unknown" bucket with its own cap (e.g. max 2 positions) so risk limits don't silently vanish. `Screener.screen` already handles missing sector entries gracefully (they get the "Neutral" weight). No code changes needed beyond populating the map for the covered names.

#### Engineering cost estimate

New OCaml module under `analysis/data/sources/wikipedia/` (or a one-off shell script feeding `bootstrap_universe.exe`):

- Fetch 4 Wikipedia pages: **~20 lines** shell or curl wrapper.
- HTML table parser (regex for `<table class="wikitable">` + `<tr>/<td>` extraction): **~80-120 lines** OCaml (or reuse an existing lib if one is in opam). Alternatively, offline-preprocess with a Python script and check in a static CSV — **~30 lines**.
- Yahoo sector label -> GICS label normaliser: **~20 lines** (small lookup table).
- SIC -> GICS sector mapping for the SEC fallback: **~50 lines** of static data if we decide to add it later. **Not required for the first cut.**
- Hardcoded sector ETF map: **~15 lines**.
- Wiring into `bootstrap_universe.exe` / `Instrument_info` loader: **~30-50 lines**.
- Tests: **~80 lines** (fixture-driven — commit a small HTML snippet).

**Total first cut: ~250-300 lines** including tests. Offline-preprocess variant (Python -> checked-in CSV -> OCaml CSV reader): **~150 lines**. Either fits in a single PR.

#### Should the user upgrade to EODHD instead?

**Not yet.** Arguments for waiting:

- **Cost not justified by current value**: $720/yr buys coverage for ~22k symbols we're not trading and don't plan to trade. The 1,500 we care about are free via Wikipedia.
- **Refresh cadence is slow**: sector is annual-refresh data. Paying monthly for a monthly refresh is wasteful.
- **Upgrade can happen later without rework**: the `Instrument_info.sector` field is the integration seam. Once Wikipedia populates it, swapping in EODHD later is a one-line change in whichever loader we wire up.

Arguments **for** upgrading to EODHD anyway:

- Zero integration work — parser already exists (`http_client.ml:217`).
- Single source of truth; no scraping fragility.
- Would also unlock `market_cap` and `industry` for future features.
- Removes any ToS/licence concerns entirely.

**Default recommendation**: land the Wikipedia-scrape path first (days of work, $0). Revisit EODHD upgrade as a separate decision after the next walk-forward validation cycle, **only if** (a) the screener's rejection rate on "no sector" is materially hurting signal quality, or (b) the 1,500-name coverage proves too narrow in practice.

### Open decisions for review

1. **Static-CSV vs runtime-scrape**: commit a checked-in CSV of `(symbol, gics_sector, gics_sub_industry)` generated by an offline Python script, or scrape Wikipedia at build/boot time? Recommendation: **checked-in CSV**, regenerated quarterly via a Makefile target. No runtime network dependency, reproducible builds.
2. **Sector taxonomy**: commit to GICS 11-sector as the canonical in-code enum now, and normalise all sources (Yahoo's "Financial Services" -> GICS "Financials", etc.) at ingest.
3. **Unknown-sector risk policy**: decide the `Portfolio_risk` behaviour for blank sector — "unknown" bucket with a cap of 2? Or block entirely? Recommendation: cap of 2 + log warning, so the gap is visible but not strategy-blocking.
4. **ETF sector labels**: hardcoded map of sector ETFs covers SPDR Select Sectors cleanly, but thematic ETFs (ARKK, IBB, SMH, JETS) don't fit the 11-GICS scheme. Either omit them from sector analysis or add a "Thematic" bucket outside GICS.
