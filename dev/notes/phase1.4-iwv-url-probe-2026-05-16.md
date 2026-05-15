# Phase 1.4 — iShares IWV URL probe (2026-05-16)

Verifies the iShares Russell 3000 ETF (IWV) holdings-CSV URL pattern
is usable for a future OCaml scraper. Doc-only deliverable — no
scraper code in this PR.

Context: `dev/notes/next-session-priorities-2026-05-16.md` §Phase 1.4.
Vendor pivot retired Norgate (Windows-only); the replacement for true
historical Russell 3000 reconstitution is DIY HTTP fetch of iShares'
holdings CSV.

## URL pattern

```
https://www.ishares.com/us/products/239714/ishares-russell-3000-etf/
  1467271812596.ajax?fileType=csv&fileName=IWV_holdings
  &dataType=fund&asOfDate=YYYYMMDD
```

No auth, no cookies required. Plain HTTPS GET. Polite User-Agent
recommended (BlackRock infra; no documented public API).

## Probe results (5 dates)

All probes via `curl -fsL --max-time 30 -A "<polite UA>"`, 2 s sleep
between requests. Response CSVs saved to `/tmp/iwv_holdings_*.csv`
(not committed).

| asOfDate | Weekday | HTTP | Body size | Lines | Data rows | "Fund Holdings as of" | Verdict |
|----------|---------|-----:|----------:|------:|----------:|-----------------------|---------|
| 2026-05-08 | Fri | 200 |   408,845 | 2,601 |     2,582 | `May 08, 2026`        | OK (recent) |
| 2021-01-04 | Mon | 200 |   452,193 | 2,889 |     2,870 | `Jan 04, 2021`        | OK (5y back) |
| 2010-01-04 | Mon | 200 |     4,585 |    20 |         0 | `-`                   | **SENTINEL** (no data) |
| 2012-06-01 | Fri | 200 |   440,308 | 2,955 |     2,936 | `Jun 01, 2012`        | OK (daily cadence) |
| 2006-12-29 | Fri | 200 |   423,572 | 2,984 |     2,965 | `Dec 29, 2006`        | OK (quarter-end) |

Key observation: **iShares always returns HTTP 200**, even when no
data is available. The sentinel response has the full preamble +
column header + legalese footer, but the `Fund Holdings as of`
metadata row contains `"-"` and zero data rows are emitted. **Any
scraper must detect the sentinel by parsing that field, not by HTTP
status.**

## Column shape — STABLE

Line 10 of every response (header row), all five probes:

```
Ticker,Name,Sector,Asset Class,Market Value,Weight (%),Notional Value,
Quantity,Price,Location,Exchange,Currency,FX Rate,Market Currency,Accrual Date
```

Byte-identical across 2006, 2012, 2021, and 2026. Verdict: **STABLE**.
The 15-column shape has not migrated in the ~20-year window iShares
serves. (The sentinel-shaped 2010-01-04 response carries the same
header from the template, which doesn't independently prove stability;
binding evidence is the actual-data 2006-12-29 vs 2026-05-08 match.)

Other invariants:
- UTF-8 BOM at byte 0 (all probes).
- 9 preamble lines (fund name, fund-level metadata, blank line) before
  the column header on line 10.
- Data rows are double-quoted, comma-separated.
- A blank line separates data rows from the legalese footer.

Era-specific row-shape variations the parser must handle:
- **2006 era** — `Sector = "-"` for every row (sector classification
  not yet populated); `Market Currency = "-"`; row order is **ascending
  by Market Value** (smallest first). Includes duplicate cross-listings
  with synthetic tickers (e.g. `0R01` for Citigroup on LSE, `GEC` for
  GE on Xetra).
- **2012+ era** — `Sector` populated (Information Technology /
  Financials / etc.); `Market Currency = "USD"`; row order is
  **descending by Market Value** (NVDA/AAPL/MSFT at top in 2026).
- **All eras** — sentinel rows for escrows/rights (e.g. `P5N994` /
  `WLLBW`) with weight 0.00; sentinel ticker `"-"` for un-tickered
  positions.
- **2012+ era only** — futures hedges (`ESM6`, `RTYM6`) and USD cash
  row appear at end of data. Pre-2012 data has equity-only rows.

A robust parser should filter on `Asset Class = "Equity"` and
`Location = "United States"` to get the pure US-equity universe.

## Date-availability cutoff — characterized via 30+ probes

Coarse cutoff scan (sentinel/OK transitions):

| Boundary           | First OK date  | Cadence available |
|--------------------|----------------|-------------------|
| 2006-09-29         | first quarter-end on record | quarterly only |
| ~2008-12-31        | monthly month-end works    | monthly        |
| 2011 throughout    | all month-ends OK; mid-month sentinel | monthly month-end |
| **2012-04-30**     | **first daily-available date** | daily (business days) |
| 2012-04-30 onward  | daily, with sporadic single-day gaps (e.g. 2013-11-15 sentinel between OK 2013-11-14 and 2013-11-18) | daily |

Detail probes that pinpoint the daily cutoff:
- 2012-04-24 → sentinel
- 2012-04-25 → sentinel
- 2012-04-26 → sentinel
- 2012-04-27 → sentinel
- 2012-04-28 → sentinel (Saturday — non-business)
- 2012-04-29 → sentinel (Sunday)
- **2012-04-30 → OK (Apr 30 2012)** ← transition
- 2012-05-01 → OK
- 2012-05-15 → OK

Earlier cutoff (monthly → quarterly):
- 2006-09-29 → OK
- 2006-08-31 → sentinel
- 2006-07-31 → sentinel
- 2006-06-30 → sentinel
- 2005-12-30 → sentinel
- 2004-06-30 → sentinel
- 2002-06-28 → sentinel

iShares **does not serve pre-Sep-2006** holdings via this endpoint.
The IWV ETF launched in May 2000 (per the preamble Inception Date),
so 6 years of early history are unavailable.

Non-business-day asOfDates (Saturdays / Sundays / market holidays)
always return sentinel. Examples confirmed:
- 2012-04-01 (Sunday) → sentinel
- 2012-09-03 (Labor Day Monday) → sentinel
- 2013-11-15 (Friday — not a holiday) → sentinel (single-day gap)

## Volume estimate

Average single-pull payload: ~430 KB across the four with-data probes
(414 KB / 430 KB / 442 KB / 399 KB). Size is nearly flat across 20
years because the universe is always ~2900-3000 holdings.

Full backfill scope:

| Period | Cadence | Snapshots | Total size |
|--------|---------|----------:|-----------:|
| 2006-09 to 2008-12 | quarterly | ~10  |   ~4 MB |
| 2009-01 to 2012-04 | monthly   | ~40  |  ~17 MB |
| 2012-05 to 2026-05 | daily     | ~3,500 | ~1.5 GB |
| **Total**          |           | **~3,550** | **~1.5 GB raw CSV** |

Trading-days math for the daily window: 14 years × 252 trading days
= 3,528 daily snapshots. At ~430 KB each = ~1.48 GB raw. After
ticker/sector/listing extraction and gzip compression, **storage
footprint should drop to ~150-250 MB** (the same ~2,900 tickers
repeat day-to-day with small deltas).

Fetch wall-clock estimate at 2 s polite sleep + ~1.3 s response =
3.3 s/request × 3,550 = ~3.3 hours one-time backfill. Acceptable.

## Failure-mode catalog

| Failure | Symptom | Detection in OCaml |
|---------|---------|--------------------|
| No data for asOfDate | HTTP 200 + 4,585-byte body + `Fund Holdings as of,"-"` row | Parse line 2; reject if RHS = `"-"` |
| Non-business day | Same as above (Sat/Sun/holiday auto-sentinel) | Same |
| Single-day mid-history gap (e.g. 2013-11-15) | Same sentinel | Same — retry adjacent business day |
| Pre-2006-09-29 request | Same sentinel | Same |
| Rate-limit / transient error | Not observed in this probe (no 429/503 hit at 2 s spacing) | Add exponential backoff on non-200 |
| HTML response instead of CSV | Not observed | Check first byte after BOM = `i` (start of "iShares Russell..."); otherwise treat as error |

The sentinel response pattern is the dominant failure mode and is
trivially classified by the `Fund Holdings as of` field check.

## Recommendation — proceed to OCaml scraper design

Green-light to proceed with a `feat-data` plan-first dispatch for the
IWV scraper. The probe confirms:

1. **URL pattern works** — no auth, no cookies, plain HTTPS GET.
2. **Column shape is stable** for the entire 2006-2026 window.
3. **Sentinel detection is deterministic** — one-field check on line 2.
4. **Cadence is asymmetric** — caller must request the right cadence
   per era (quarterly 2006-09 to 2008, monthly 2009 to 2012-04, daily
   2012-05 to present).
5. **Volume is tractable** — ~3,550 snapshots, ~1.5 GB raw, ~3 hours
   to backfill at polite spacing.

Suggested OCaml-side design (deliverable in the next dispatch):

- Module: `analysis/data/sources/ishares/lib/iwv_client.ml` —
  HTTP fetch with polite-UA, retry, exponential backoff.
- Module: `analysis/data/sources/ishares/lib/iwv_parser.ml` —
  CSV parser with UTF-8 BOM strip, preamble skip (lines 1-9),
  sentinel detection (line 2 `"-"` check), row tokenization,
  futures/cash/non-US filtering.
- CLI: `analysis/data/sources/ishares/bin/probe_iwv.exe` for
  single-date fetch (mirrors this probe in OCaml).
- CLI: `analysis/data/sources/ishares/bin/build_universe.exe` for
  backfill into a sexp manifest of point-in-time membership.
- Cadence policy: quarterly 2006-09 to 2008-12, monthly 2009-01 to
  2012-04, weekly Friday 2012-05 onward (daily resolution is overkill
  for stage-2 stock-picking; weekly tracks rebalances cheaply).

Fallback plan: if iShares serves the endpoint behind Cloudflare or
JS challenge later, freeze the historical pulls (treat them as
immutable snapshots after first fetch — the data does not change
retroactively) and switch live updates to the EODHD `IWV.US`
fundamentals endpoint (`HistoricalTickerComponents`) which we already
support per Phase 1.1.

## Out of scope for this probe

- Live OCaml port of the URL fetch.
- ETF-vs-index drift quantification (IWV tracks but does not equal
  Russell 3000; tracking error is ~5-15 bps).
- Pre-2006-09 sourcing — explicitly deferred per the broader-first
  pivot; not material until we re-prioritize Sharadar or institutional
  vendors.
