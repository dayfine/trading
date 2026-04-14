# ADL Source Validation -- 2026-04-14

Probe scripts: `dev/scripts/probes/probe_yahoo_adl.py`, `probe_eoddata_adl.py`, `probe_unicorn_adl.py`

## Source 1: Yahoo Finance (`^ADV`, `^DECL`, `C:ISSU`, `C:ISSQ`)

**Verdict: REJECTED -- symbols do not exist**

- Tested symbols: `^ADV`, `^DECL`, `^UNCH`, `C:ISSU`, `C:ISSQ`, `ADVN`
- All return `{"error": {"code": "Not Found", "description": "No data found, symbol may be delisted"}}`
- Yahoo does serve `^NYA` (NYSE Composite) with OHLCV data, confirming the API itself works
- The `C:ISSU`/`C:ISSQ` ticker notation appears in some references but Yahoo's v8 chart API does not recognize it
- No alternative Yahoo symbols found for advance/decline counts

## Source 2: EODData.com (`INDEX:ADRN`)

**Verdict: VIABLE -- data available, but scraping required**

- URL: `https://eoddata.com/stockquote/INDEX/ADRN.htm`
- Returns HTML with an embedded quote table showing OHLCV-style data for ADRN (NYSE Advance-Decline Ratio)
- **Data type**: This is the advance-decline RATIO (advances / declines), delivered as OHLCV. Sample values: Close values around 0.4 to 8.4, consistent with a ratio (not absolute counts)
- **Date range available**: The download form shows `min="2015-04-17" max="2026-04-06"` -- roughly 11 years of history
- **Format**: HTML table with Date, Open, High, Low, Close, Volume columns. Volume is always 0
- **Authentication**: Quote page is publicly accessible without login. However, CSV/bulk download requires registration (free tier available)
- **API**: EODData has a new API service (`api.eoddata.com`) but it's unclear if the free tier covers INDEX:ADRN
- **Parsing difficulty**: Medium -- requires HTML scraping of an ASP.NET page, or registration for CSV download
- **Rate limits**: Unknown; no rate-limit headers observed
- **License**: Standard commercial data provider terms

**Key limitation**: ADRN is a ratio, not absolute advance/decline counts. The Weinstein macro analysis (`_ad_line_signal`) expects separate advance and decline counts to compute a cumulative AD line. A ratio can indicate direction but cannot reconstruct the cumulative AD line. We would need to find `ADVN` (advancing issues) and `DECL` (declining issues) as separate INDEX symbols on EODData.

## Source 3: Unicorn.us.com (`advdec`)

**Verdict: DEAD -- site stopped updating Feb 2020**

- URL: `http://unicorn.us.com/advdec/`
- **Status**: Site explicitly states "THIS SITE HAS STOPPED FUNCTIONING" as of February 10, 2020
- **Historical data**: Available from 2002 to 2020-02-10 in per-day text files
- **Format**: Excellent -- comma-delimited with columns: `Market, AdvIssues, DecIssues, UncIssues, AdvVol, DeclVol, UnchVol, NewHis, NewLows`
- **Coverage**: NYSE, AMEX, NASDAQ -- exactly the exchanges we need
- **Sample file** (`adU20200210.txt`):
  ```
  2020/02/10
  Market, AdvIssues, DecIssues, UncIssues, AdvVol, DeclVol, UnchVol, NewHis, NewLows
  NYSE,   1721,      1212,       91,      1840000000, 1750000000, 28520000, 248, 86
  AMEX,    153,       119,       16,        63250000,   61600000,  2540000,  28, 12
  NASDAQ, 1907,      1296,      111,      1610000000,  652980000, 30280000, 167, 92
  ```
- **Parseability**: Trivial -- CSV with fixed schema
- **License**: Free, computed from public sources (median of multiple providers)
- **Suggested alternative**: Site recommends Pinnacle Data (https://pinnacledata2.com/) as replacement

**Useful as historical backfill (2002-2020) but cannot serve as the live source.**

## Summary and Recommendation

| Source | Works? | Data type | Coverage | Parse difficulty | Live feed? |
|--------|--------|-----------|----------|------------------|------------|
| Yahoo `^ADV`/`^DECL` | No | N/A | N/A | N/A | N/A |
| EODData `INDEX:ADRN` | Yes | Ratio (adv/dec) | 2015-present | Medium (HTML scrape) | Yes |
| Unicorn `advdec` | Historical only | Absolute counts | 2002-2020 | Trivial (CSV) | No (dead) |

### Recommended path forward

1. **Primary source: EODData** -- but need to validate whether `INDEX:ADVN` and `INDEX:DECL` exist as separate symbols (absolute counts, not ratio). The free tier registration would allow CSV downloads and API access.

2. **Historical backfill: Unicorn** -- download and cache the 2002-2020 archive (approximately 4,500 files). Format is ideal and trivially parseable. Good for backtesting.

3. **Alternative to investigate**: Pinnacle Data (recommended by Unicorn as successor). Also worth checking FRED (Federal Reserve Economic Data) which publishes NYSE breadth data.

4. **Fallback: compute from universe** -- count advancers/decliners across the cached universe each day. Less accurate than official NYSE counts but correlates well. Viable once Russell 3000 bars are cached.

### Blocking items

- EODData free-tier registration (requires human action) to validate ADVN/DECL separate-symbol availability and get CSV/API access
- Pinnacle Data evaluation (commercial; requires human decision on cost)
