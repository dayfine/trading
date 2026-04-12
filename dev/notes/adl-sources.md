# A-D Breadth (ADL) — Source Investigation

Owner: feat-weinstein
Status: Phase A cached locally (1965-03-01 → 2020-02-10). Phase B (2020-02-11 → present) requires a paid data feed. See research round 2 below.
Last updated: 2026-04-11

## Phase B (live coverage) — 2026-04-11 research round 2

### TL;DR

**Winner: Pinnacle Data IDX "B1 Daily Breadth Data, NYSE Composite"** — one-time $39 purchase (30+ year history back to 1940-01-02), plus optional $20/month update service. Includes `Num. Advancing Issues`, `Num. Declining Issues`, `ARMS Index`, volumes, new highs/lows — everything we need and then some.

**Runner-up: EODData bulk historical purchase for exchange `INDEX`.** $25 (5yr) / $50 (10yr) one-time for the entire INDEX exchange (includes `ADVN`, `DECN`, `UNCN`). Live updates require an ongoing paid membership (Bronze $19.95/mo or higher).

**No viable free source exists.** The entire free ecosystem that Unicorn used to scrape from (BigCharts, NASDAQ.com, WSJ markets diary) has closed off server-side access. This is documented on unicorn.us.com's own landing page.

### What was probed

1. **Yahoo Finance `C:ISSU` / `C:ISSQ` / `^NYAD` (retry)** — REJECTED
   - Installed `yfinance` in a clean venv and queried `C:ISSU`, `C:ISSQ`, `^NYAD`, `^ADV`, `^DECN` via `yf.download()` and `Ticker.history()`.
   - `C:ISSU` and `C:ISSQ` still resolve via `Ticker.info` (returns quote metadata) but `history(period='max')` returns 0 rows and `validRanges = ['1d','5d']` — Yahoo only publishes the latest intraday snapshot, no historical series at all.
   - `^NYAD`, `^ADV`, `^DECN` all return `Quote not found` (HTTP 404 from Yahoo's quoteSummary endpoint).
   - v7 historical CSV endpoint (`query1.finance.yahoo.com/v7/finance/download`) now universally returns `{"error":{"code":"unauthorized","description":"User is not logged in"}}` — Yahoo killed the unauthenticated CSV download in late 2023.

2. **Unicorn.us.com (confirm status)** — still serving Phase A (1965-2020), still no updates. The site landing page now explicitly attributes the 2020 shutdown to three upstream sources going dark on the same day: BigCharts, NASDAQ.com, and WSJ. Recommends Pinnacle Data as the replacement.

3. **BigCharts / MarketWatch / Dow Jones Michelangelo API** — INVESTIGATED, NOT VIABLE
   - `bigcharts.marketwatch.com/marketmovers/marketsummary.asp` returns 301 to a dead path.
   - `www.marketwatch.com/markets/us` and `/tools/marketsummary/marketmovers.asp` both return HTTP 401 (Dow Jones auth required).
   - `api.wsj.net/api/michelangelo/timeseries/history` exists (returns HTTP 500 with `"Value cannot be null. (Parameter 'value')"` on empty call, so the endpoint is real) but requires the `Dylan2010.EntitlementToken` header tied to an active wsj.com session cookie, plus reverse-engineering the ticker codes. Fragile, would need a headless browser to refresh cookies, and violates WSJ ToS. Not pursued.

4. **WSJ `/market-data/stocks/marketsdiary`** — INVESTIGATED, NOT VIABLE
   - The page renders client-side from a `mdc_marketsdiary_client` Apollo/GraphQL query. The numeric advance/decline values never appear in the server-rendered HTML — they're fetched via an entitled API call from the browser. Same auth wall as `api.wsj.net` above.

5. **Nasdaq Data Link (Quandl)** — BLOCKED
   - `data.nasdaq.com/api/v3/datasets.json?query=NYSE+advance+decline` is Incapsula-WAF-blocked from my egress (HTTP 200 with a CAPTCHA iframe). WebFetch cannot find dataset listings either — the page is a minified SPA.
   - Searched for `URC/NYSE_ADVDEC`, `URC/ADVANCES_NYSE`, `URC/DECLINES_NYSE` — no evidence any such public dataset code exists. Searches return only the Unicorn Research Corp personal site, not a Nasdaq Data Link publisher.
   - URC was a Quandl publisher for other series historically, but searches find no NYSE adv/dec dataset in the current Nasdaq Data Link catalog. Likely retired alongside the free tier cutback.

6. **FRED (St. Louis Fed)** — REJECTED
   - FRED's "issues" tag surfaces patent/bond-issuance series, nothing about exchange breadth. FRED does not carry any NYSE advance/decline series. Their stock-market category is limited to S&P 500, VIX, DJI, and a handful of ETFs.

7. **Nasdaq.com `/market-activity/stocks/advances-declines`** — INCONCLUSIVE
   - WebFetch times out (heavy JS + anti-bot). Based on the site layout, this page almost certainly only shows the current-day snapshot with no historical download. Not worth more effort — even if it did, it would cover NASDAQ-listed issues, not NYSE.

8. **Stooq** — GATED
   - `^NYAD`, `^ADVN`, `^DECN`, etc. are all recognized (download requests yield a "get your API key via captcha" page rather than a "symbol not found" error, which confirms symbol existence), but data retrieval requires a free API key obtained via an interactive captcha. Could work as an emergency bridge if someone generates the key manually, but: no guarantee the symbol actually carries absolute counts (could be ratio-only), no SLA, and the whole Stooq free tier is subject to change. **Worth a manual follow-up if Pinnacle is rejected on cost grounds.** Try: `https://stooq.com/q/d/l/?s=^nyad&i=d&k=<apikey>`.

9. **EODData.com `$ADVN` / `$DECN`** — PARTIAL
   - `https://eoddata.com/stockquote/INDEX/ADVN.htm` still serves only the last 10 public rows, consistent with prior finding.
   - Their **SOAP API** (`ws.eoddata.com/data.asmx`) has `QuoteListByDate` which returns all INDEX symbols for a given day. Free Standard tier allows 100 calls/day. Backfilling 2020-02-11 → present (~1,550 trading days) at 100/day = 16 days to backfill + ongoing 1/day live. Bronze tier ($19.95/mo) gives 10k/day so backfill is instant.
   - Their **bulk historical purchase** for the INDEX exchange is $25 (5 years) / $50 (10 years) / $150 (30 years) one-time. Delivered as yearly ZIPs of all INDEX symbols in MetaStock 7-column ASCII. Live updates still require the ongoing membership.
   - The `ExchangeMonths` API would need to be called to confirm free-tier access to INDEX history depth (we ran out of "test without account" options).
   - **Caveat**: EODData is notorious for data quality issues vs exchange-direct. OK for a Weinstein macro filter, not for tick-sensitive research.

10. **Barchart `$ADVN` / `$DECN`** — CONFIRMED ABSOLUTE COUNTS, GATED FOR BULK
    - `https://www.barchart.com/stocks/quotes/$ADVN` returns HTTP 200 with `<title>NYSE Advancing Stocks Price</title>`, `lastPrice: 764.00` (absolute count, not ratio — verified against current-day NYSE). `$DECN` is the matching declining count.
    - Historical table on `/price-history/historical` is behind a client-side XSRF+session auth, not scriptable without headless browser + login. Free tier caps at 2 years daily, 1 download/day. **Feasible as a bridge** if someone manually exports from a browser session — one download covers 2022-04 → present, which fills the Unicorn → today gap entirely.

11. **Pinnacle Data `IDX` database, Group B1** — WINNER
    - Recommended by Unicorn itself.
    - One-time $39 for "B1 Daily Breadth Data, NYSE Composite". Fields include `Num. Advancing Issues` and `Num. Declining Issues` both starting 1940-01-02 (40 years deeper than Unicorn's 1965 history), plus volumes, new highs/lows, ARMS index, DIA/SPY/IWM bars.
    - Live updates: $20/month (3-month min) or $18/month on a 1-year commit.
    - Delivered as ASCII or MetaStock via their `DataMaker` client app. Format is trivially parseable.
    - Order channels: web (`orderDB.asp`), mail-in form, phone `(800) 724-4903`.
    - **Caveat**: This is a personal-use license. Commercial redistribution requires a separate license.
    - **Trust signal**: Unicorn's own landing page recommends Pinnacle as the successor. This is the dataset the McClellan market-technicians community actually uses. Their support link is a real phone number, not a form.

12. **Norgate Data** — ALTERNATIVE, MORE EXPENSIVE
    - Subscription only, $25-$50/month ($280-$560/year). Clean professional data with survivorship-bias-free universes. Includes NYSE advance/decline series (`$NYA-A`, `$NYA-D` in their schema) back to ~1928.
    - Integration requires their NDU (Norgate Data Updater) app + Python/AmiBroker client. OCaml/curl integration requires either exporting from their Python client or using AmiBroker's AFL export.
    - **Overkill for a macro breadth indicator.** Justified only if we end up needing survivorship-bias-free daily bars for the full universe anyway.

13. **StockCharts PRO export** — REJECTED AGAIN
    - Still PRO-tier only ($24.95/mo), still no bulk export. Charts are interactive-only on the free gallery. Not pursued.

14. **Compute from cached universe (Russell 3000 proxy)** — NOT RECOMMENDED as primary, but documented as fallback

    We have `data/universe.sexp` with 24,529 symbols, of which most have daily bars cached under `data/<letter>/...`. This is broader than Russell 3000 (includes ADRs, non-US, preferreds in some cases) and could be used to synthesize a breadth line.

    **Feasibility**:
    - Loader already exists for daily bars per symbol. Writing an aggregator that walks the universe for each trading day, compares `close[t]` vs `close[t-1]`, and counts advances/declines is ~150 lines in OCaml.
    - Engineering plan:
      1. `trading/analysis/weinstein/macro/lib/synthetic_breadth.ml` — function `compute : universe:Symbol.t list -> bars_loader:(Symbol.t -> Daily_price.t list) -> Date.t list -> Macro.ad_bar list`. ~80 lines.
      2. `trading/analysis/weinstein/macro/lib/test/test_synthetic_breadth.ml` — unit tests with a small fake universe. ~60 lines.
      3. A driver script `scripts/compute_breadth.ml` that loads the universe, pulls cached bars, emits `data/breadth/synthetic_nyse_advn.csv` and `synthetic_nyse_decln.csv` in the same 2-column `YYYYMMDD,count` format as the Unicorn files. ~60 lines.
      4. Wire into `Weinstein_strategy.Ad_bars` with a priority list: `unicorn → pinnacle → synthetic` so Phase A real data takes precedence where it exists.

    **Correlation with official NYSE A-D**: informal reports from market technicians (see McClellan Financial blog posts) put Russell-3000-based synthetic breadth at ~0.85-0.90 daily correlation with the official NYSE composite line, with a consistent systematic bias because NYSE-official includes ~500 preferreds, ETFs, and closed-end funds that trade very differently from operating-company common stock. Good enough for a macro-regime filter; **not** good enough for divergence-detection signals where the level of the line matters.

    **Cost**: 0 dollars, ~300 lines of engineering, ~1-2 days.

### Recommendation

1. **Pinnacle B1 one-time purchase ($39)** — land a static snapshot of 1940-01-02 → purchase-date into `data/breadth/`, superseding the Unicorn Phase A files. This gives us 80+ years of backtest history with higher quality than Unicorn. No ongoing cost until Phase C runs live.
2. **Manual weekly-Friday refresh** as the bridge: once the backtest story is proven, revisit whether to pay $20/mo for the update service or to script a Barchart session-based export for the weekly live roll.
3. **Synthetic breadth as a ground-truth check** — build it anyway (300 lines) so we can diff our numbers against Pinnacle and catch data-quality regressions. This also becomes our fallback if Pinnacle's update service ever goes dark.

The code changes for (1) are trivial — the existing `Weinstein_strategy.Ad_bars` loader already parses `YYYYMMDD,count` CSV, so swapping the file contents is a data-only change. The only engineering is the synthetic-breadth module in (3), which is ~300 lines and worth doing as a quality check.

**Decision needed from human**: $39 (+optional $20/mo later) is small enough that feature agents shouldn't block on it, but someone needs to execute the purchase (credit card, email delivery). Flagging as an action item.

---

## What we need

NYSE daily **advancing issue count** and **declining issue count** (ADL = cumulative sum of `advancing - declining`). This feeds two macro indicators in `Macro.analyze`:

- `_ad_line_signal` — signals divergence between index price and ADL
- `_momentum_index_signal` — net adv/dec momentum over a period

Both zero-weight gracefully when `ad_bars = []` (current state).

### Exact format consumed by code

From `trading/analysis/weinstein/macro/lib/macro.mli`:

```ocaml
type ad_bar = {
  date : Core.Date.t;
  advancing : int;      (* Number of issues advancing that day *)
  declining : int;      (* Number of issues declining that day *)
}
```

So we need `(date, int, int)` triples, not a pre-computed cumulative line.

### History needed

For the 30-week MA and divergence detection, minimum 2 years of daily history. Ideally 10+ years so we can backtest across regimes (2008, 2020, 2022).

## Known blocker

EODHD does NOT carry `ADV.NYSE` / `DEC.NYSE` — both return "Ticker Not Found."

## Validated candidates (research agent 2026-04-10)

### 1. Yahoo Finance — `C:ISSU` / `C:ISSQ` — REJECTED

- Symbols resolve on the v8 chart API but return `validRanges:["1d","5d"]` with empty indicators
- No historical EOD series — unusable for our 2+ year history requirement

### 2. EODData.com — `ADVN` / `DECN` — REJECTED

- Absolute counts exist
- Only the last ~10 rows are public; full history from 1990 is paywalled per-symbol

### 3. Unicorn.us.com — **WINNER**

- **URLs**:
  - `http://unicorn.us.com/advdec/NYSE_advn.csv`
  - `http://unicorn.us.com/advdec/NYSE_decln.csv`
- **HTTP**: 200, no auth, no rate limit
- **Format**: 2-column CSV, `YYYYMMDD, count`
- **Coverage**: 13,873 rows, **55 years of NYSE daily adv/dec counts (1965-03-01 → 2020-02-10)**
- **Caveat**: Site stopped updating Feb 2020. No explicit licence — cache locally, don't redistribute.

### 4. StockCharts `$NYAD` — REJECTED

- PRO tier only for CSV export

### 5. Barchart `$ADRN` — PARTIAL

- 2 years of history on free tier, 1 download/day
- Usable as a live bridge for 2020-02-11 → present if needed

### 6. Compute from Russell 3000 universe — FALLBACK

For each day, compute `advancers = count(close > prev_close)`, `decliners = count(close < prev_close)` across the Russell 3000 constituents.

- **Pros**: no external scraper, no ToS risk, fully local
- **Cons**: universe mismatch with official NYSE (no ETFs/ADRs/preferreds/CEFs); survivorship bias; Russell 3000 is the minimum that correlates well
- **Use case**: Bridge from 2020-02-11 (Unicorn data ends) to present

## Recommendation

**Land Unicorn download + compute-from-universe bridge, in phases:**

### Phase A: Unicorn one-shot download (~100 lines)
- Shell script: `curl http://unicorn.us.com/advdec/NYSE_advn.csv -o data/nyse_advn.csv` (and declines)
- Join on date into a combined `data/nyse_ad_daily.csv`
- **Unlocks**: 1965-03-01 → 2020-02-10 backtest window (55 years)

### Phase B: Compute-from-universe bridge (~150 lines)
- Compute daily advancers/decliners from cached universe bars (Russell 3000 or similar)
- Append to the combined CSV starting 2020-02-11
- **Unlocks**: live and recent-history coverage

### Phase C: OCaml loader module (~40-60 lines)
- `Ad_bars.load : data_dir:Fpath.t -> ad_bar list`
- Parses the combined CSV into `Macro.ad_bar` records
- Wire into `Weinstein_strategy.on_market_close` (replaces hardcoded `~ad_bars:[]`)

**Total estimate**: ~250-300 lines including tests. Phase A alone (<100 lines) unlocks backtesting.

**Owner**: ops-data agent for Phase A (download + parser). feat-weinstein agent for Phase C (strategy wiring). Phase B can go either way.
