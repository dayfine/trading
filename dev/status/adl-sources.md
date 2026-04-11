# A-D Breadth (ADL) — Source Investigation

**Owners**: `ops-data` (Phase A/B data fetch + cadence), `feat-weinstein` (Phase C OCaml loader + strategy wiring)
**Status**: ACTIVE — Phase A complete, Phase B blocked on human source decision, Phase C pending
**Last updated**: 2026-04-10

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
