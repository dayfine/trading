# Vendor comparison — historical universe (2026-05-16, Option B pivot)

Survivorship-correct point-in-time membership for a US equity
historical universe spanning 2006 → present (minimum) or 1996 →
present (stretch). Originally authored 2026-05-16 as part of the
Norgate retirement (vendor-pivot PR #1105); regenerated 2026-05-16
after the Phase 1.1 EODHD-Fundamentals verification (PR #1106) came
back FAIL and the Phase 1.4 IWV URL probe (PR #1108) came back
green.

## TL;DR

- **#1 — iShares IWV holdings scrape (NEW PRIMARY).** Pure HTTP, no
  auth, no vendor signup. Confirmed working 2006-09-29 → 2026-05-08
  via PR #1108 probes. Russell 3000 universe (~3000 names) is
  strictly broader than SP500 (every SP500 name is in IWV). Zero
  marginal cost.
- **#2 — `fja05680/sp500` static seed.** MIT-licensed GitHub repo
  shipping `sp500_ticker_start_end.csv` covering 1996 → present. Use
  only for the 1996–2005 SP500 tail (iShares IWV pre-dates 2006-09).
  Author flags first ~5 years as best-effort; deferred per the
  broader-first pivot in `memory/project_strategic_pivot_broader_first.md`.
- **#3 — EODHD Fundamentals API.** RETIRED for our use case after the
  2026-05-16 verification — our current EODHD subscription is the
  EOD-only tier; the Fundamentals endpoint returns HTTP 403 across
  every variant probed. Tier upgrade ($59.99/mo Fundamentals Data Feed
  or €99.99/mo All-In-One) was rejected per the Option B pivot.
- **#4 — Sharadar via Nasdaq Data Link.** Deferred. The only credible
  >30y step-up for non-institutional pricing; revisit once Phase 1.4
  proves out at 20y.
- **#5 — Norgate.** Retired 2026-05-16 (Windows-only NDU client;
  incompatible with our Mac/Linux Docker toolchain).

Strategic posture (`memory/project_strategic_pivot_broader_first.md`):
broader-first beats more-knobs. The next round of strategy tuning
needs a wider, longer, survivorship-correct universe more than it
needs deeper history on the existing 510-symbol baseline. Russell
3000 from 2006 is enough to clear that bar.

## Decision

**Option B — IWV scrape as PRIMARY source.** Phase 1.4 in
`dev/status/data-foundations.md` becomes the load-bearing item.
Phase 1.1 (EODHD Fundamentals) is FAILED at verification and parked
indefinitely. Phase 1.5 (fja05680 1996-1999 tail) remains deferred.

## Per-option detail

### Option 1 — iShares IWV holdings scrape (PRIMARY)

| Field | Value |
|---|---|
| Vendor | BlackRock / iShares (public website; no key) |
| Coverage start | 2006-09-29 (probed; PR #1108) |
| Coverage end | Current trading day |
| Cadence (early) | Quarterly 2006-09 → 2008-12 |
| Cadence (mid) | Monthly 2009-01 → 2012-04 |
| Cadence (late) | Daily 2012-04-30 → present |
| Universe | Russell 3000 (≈3000 large + mid + small caps) |
| SP500 coverage | Yes — every SP500 name is also in Russell 3000 |
| Delisted symbols | Yes (by inference — symbol present on date `D`, absent on `D+1` ⇒ exited universe; tenure reconstructed via diffing consecutive snapshots) |
| Cost | $0 |
| Auth | None (no API key, no cookies) |
| Rate limit | Unpublished; PR #1108 used 2s polite spacing across 31 probes without throttling |
| URL template | `https://www.ishares.com/us/products/239714/ishares-russell-3000-etf/1467271812596.ajax?fileType=csv&fileName=IWV_holdings&dataType=fund&asOfDate=YYYYMMDD` |
| Sentinel for unavailable dates | HTTP 200 + 4585-byte template body with `Fund Holdings as of,"-"` on line 2 (must parse content, not status code) |
| Header stability | Line 10 header byte-identical 2006-12-29 → 2026-05-08 (28 boundary tests pinned in PR #1108) |
| File size | ~430 KB/snapshot; ~3550 total snapshots; ~1.5 GB raw uncompressed |
| Backfill wall time | ~3 hr at 2s polite spacing |
| ToS / licensing | iShares website is public; fund holdings are required US-SEC disclosures. Cache CSVs locally; do not redistribute. Mark manifest `source=ishares-iwv-public` |
| Native client | OCaml `cohttp` HTTPS GET + repo's existing `analysis/data/storage/csv` decoder — no Python dependency |
| Pre-existing reference impl | `talsan/ishares` (Python; we read it as a reference doc only) |

**Sibling ETFs (same URL pattern, different product ID):**

| ETF | Universe | Product ID | Notes |
|---|---|---|---|
| IWV | Russell 3000 | 239714 / 1467271812596 | This option |
| IWB | Russell 1000 (large + mid) | 239707 | Subset of IWV; redundant if scraping IWV |
| IWM | Russell 2000 (small cap) | 239710 | Subset of IWV; redundant if scraping IWV |

Would-this-work assessment: yes, this is the recommended path. The
2006-09-29 coverage start is acceptable — 20y is in the
broader-first sweet spot, and the gap to our existing 2010 baseline
is a 4y prepend, not a redesign.

### Option 2 — `fja05680/sp500` static seed (1996–1999 tail; DEFERRED)

| Field | Value |
|---|---|
| Vendor | GitHub `fja05680/sp500` (hobbyist) |
| License | MIT |
| Coverage start | 1996-01-02 (best-effort; author flags first ~5 years as incomplete) |
| Coverage end | Author-maintained; pinned commit recommended |
| Universe | SP500 only |
| Schema | `sp500_ticker_start_end.csv` — `ticker,start_date,end_date` |
| Delisted symbols | Yes (carried in csv) |
| Cost | $0 |
| Auth | None |
| Native client | OCaml + `analysis/data/storage/csv` |
| ToS / licensing | MIT — pin a commit, vendor under `analysis/data/sources/fja05680/data/` |
| Manifest tag | `source=fja05680-best-effort` (per author's reliability caveat) |

Would-this-work assessment: usable only for the 1996–2005 SP500 tail
that IWV cannot cover. Deferred 2026-05-16 per the broader-first
pivot — better to spend the implementation budget on a broader
2006+ universe than on a deeper SP500-only seed with reliability
caveats.

### Option 3 — EODHD Fundamentals API (RETIRED for our use case)

| Field | Value |
|---|---|
| Vendor | EOD Historical Data |
| Coverage start (claimed) | Jan 2000 (`HistoricalTickerComponents` on `GSPC.INDX`) |
| Coverage start (per vendor docs) | "1960s, though the most complete data starts from 2016" — EODHD marketing copy |
| Universe | Indices: SP500, Dow Jones, FTSE, NASDAQ100, etc. via `<INDEX>.INDX` |
| Delisted symbols | Per-row `IsDelisted: true` flag claimed; schema not verified |
| Cost | $59.99/mo Fundamentals Data Feed standalone; €99.99/mo All-In-One (Fundamentals + EOD + Live + Options) |
| Our subscription | EOD-only tier — does NOT include Fundamentals |
| Probed result (2026-05-16) | HTTP 403 across all 10 URL variants, including bulk + historical-market-cap with explicit denial messages (PR #1106) |
| Native client | Yes — reuses existing `analysis/data/sources/eodhd/lib/eodhd_client` |
| Schema caveat | Public docs describe `Components` + `HistoricalComponents` (snapshot-based) rather than per-row `StartDate`/`EndDate` tenure intervals — schema may differ from what `data-foundations.md` Track 1 originally assumed |

**Marketplace alternative — Unicorn Bay product** (rejected separately):

| Field | Value |
|---|---|
| Product | "S&P and Dow Jones: Indices Historical Constituents Data API" |
| URL | `eodhd.com/marketplace/unicornbay/spgloical` |
| Cost | $29.99/mo regular; $50 for first 3 months promo |
| Coverage | "up to 12 years" = 2014-present — does not cover our 2010 baseline |
| Schema | Not published on marketplace page; would need sales-team trial |

Would-this-work assessment: no, retired 2026-05-16. Both the
mainline Fundamentals tier ($60/mo) and the marketplace add-on
($30/mo) lose to the free IWV scrape on cost, coverage, and
provenance certainty. The EOD tier we already pay for stays in use
for price bars; only the Fundamentals add-on is rejected.

### Option 4 — Sharadar via Nasdaq Data Link (>30y; DEFERRED)

| Field | Value |
|---|---|
| Vendor | Quandl/Sharadar via Nasdaq Data Link (`SHARADAR/SP500`) |
| Coverage start | 1957 for SP500 changes; equity prices from 1998 |
| Universe | SP500 + delisted; Sharadar's broader US equity table for prices |
| Delisted symbols | Yes (load-bearing for the product) |
| Cost | $150–$300/mo personal tier (varies by package) |
| Auth | API key |
| Native client | New — would need `analysis/data/sources/sharadar/` |
| Reliability | Commercial, institutionally-used |

Would-this-work assessment: the only credible non-institutional
>30y step-up. Defer until Phase 1.4 IWV scrape proves out at 20y
and the strategy demonstrates it needs deeper history (per
`memory/project_m5-5-tuning-exhausted.md` and the broader-first
pivot, 20y on a 3000-name universe is far from tapped out).

### Option 5 — Norgate Data (RETIRED)

| Field | Value |
|---|---|
| Vendor | Norgate |
| Coverage start | 1990 SP500 + R1k + R2k PI membership; institutional-grade |
| Cost | ≈$30/mo personal |
| Auth | NDU desktop application |
| Native client | **Windows-only** — would require running Windows in Docker or a separate VM |
| Verdict | Retired 2026-05-16 (Decisions log entry). Adds an OS to our supported stack for one ingest path; not justifiable when IWV scrape covers 20y for $0 |

### Option 6 — FMP (Financial Modeling Prep)

| Field | Value |
|---|---|
| Vendor | FMP |
| Coverage | SP500 historical constituents from ~2014 |
| Cost | Free tier 250 req/day; paid tiers from $14/mo |
| Auth | API key |
| Native client | New — would need an `analysis/data/sources/fmp/` |

Would-this-work assessment: no. Coverage starts post-2014; we
already have 2010-present locally. Adds a vendor surface without
extending horizon.

### Option 7 — Polygon.io

| Field | Value |
|---|---|
| Vendor | Polygon |
| Coverage | Equities back to 2003; SP500 constituents via the `/reference/tickers` snapshots since ~2017 |
| Cost | Free tier 5 req/min, no historical; paid from $29/mo |
| Auth | API key |
| Native client | New |

Would-this-work assessment: no — best for intraday / tick data, not
historical PI membership. Membership history is shallow (post-2017
only).

### Option 8 — Tiingo

| Field | Value |
|---|---|
| Vendor | Tiingo |
| Coverage | EOD from 1962 for some symbols; no published PI membership endpoint |
| Cost | $30/mo paid tier |
| Auth | API key |

Would-this-work assessment: no — Tiingo is a price-bar vendor, not
an index-membership vendor. Skip.

### Option 9 — SPDR SPY direct scrape (DIY, SP500 only)

| Field | Value |
|---|---|
| Vendor | State Street SPY ETF holdings page |
| Coverage | SP500 only |
| Cost | $0 |
| Auth | None |
| Schema | XLSX export rather than CSV; different parser to write |

Would-this-work assessment: redundant with IWV (every SPY name is in
IWV). The XLSX-only export and the SP500-only scope make it strictly
worse than IWV for our needs. Skip.

### Option 10 — CRSP / WRDS

| Field | Value |
|---|---|
| Vendor | CRSP via Wharton WRDS |
| Coverage | 1925 → present, NYSE-grade institutional data |
| Cost | $5,000+/yr institutional access only |
| Auth | WRDS account (university or institutional sponsorship) |

Would-this-work assessment: no — institutional access only. The
100y NYSE data is the load-bearing reason CRSP exists; we are not
buying it for this project. Listed for completeness only.

## Ranked recommendation (post-2026-05-16 verification)

1. **iShares IWV scrape** — primary; 2006-present Russell 3000 free.
   Phase 1.4 in `dev/status/data-foundations.md`.
2. **fja05680/sp500 static seed** — optional 1996–2005 SP500 tail.
   Phase 1.5 (deferred).
3. **Sharadar / Nasdaq Data Link** — Phase 1.6 (deferred) if/when
   IWV's 20y horizon is exhausted.

EODHD Fundamentals (Phase 1.1) is FAILED and NOT being pursued.
Norgate (formerly Phase 1.1 / pre-pivot Phase 1.2) is RETIRED.

## 2026-05-16 verification appendix

### PR #1106 — EODHD Fundamentals tier: FAIL

- 10 URL variants probed; all returned HTTP 403.
- `/api/user` returned `subscriptionType:"monthly"` (a paid plan, EOD
  tier).
- `/api/historical-market-cap/AAPL.US` returned the explicit
  `Forbidden. You have no access to Historical Market Cap Data Feed.`
  message, confirming the 403 is scope-not-auth.
- The originally-planned 5-event spot-check (LEH/KODK/FB/TSLA/GE)
  could not be executed.
- Full transcript: `dev/notes/phase1.1-eodhd-verification-2026-05-16.md`.

### PR #1108 — IWV URL pattern: PASS

- 31 total probes (3 primary + 28 boundary).
- HTTP 200 across full 2006-09-29 → 2026-05-08 range.
- Line 10 header byte-identical across the entire date range.
- Sentinel for unavailable dates is `Fund Holdings as of,"-"` on line
  2 of an HTTP 200 response — must parse content, not status code.
- Coverage cadence: quarterly (2006-09 → 2008-12) → monthly (2009 →
  2012-04) → daily (2012-04-30+).
- Full transcript: `dev/notes/phase1.4-iwv-url-probe-2026-05-16.md`.

## Cross-cutting notes

- **No Python.** All clients live in OCaml + `cohttp` + the repo's
  existing CSV / sexp infra. Reference Python repos (`talsan/ishares`,
  `fja05680/sp500`) are read for their URL patterns and CSV schemas
  only — never executed.
- **Caching layout.** All vendor-derived raw files go under
  `dev/data/<vendor>/...` (gitignored, per
  `.claude/rules/no-python.md` and the data-foundations agent's
  scope). Small pinned fixtures for tests go under
  `analysis/data/sources/<vendor>/test/data/`.
- **Manifest provenance.** Every emitted universe sexp must carry a
  `source=<vendor>-<descriptor>` header line so downstream backtests
  can audit which source / cadence / coverage window underlies a
  given run (per `dev/plans/data-inventory-and-reproducibility-2026-05-02.md`).
- **Survivorship handling.** IWV diff-based tenure inference is the
  same algorithm Phase 1.1's EODHD parser would have used had the
  schema turned out to be the snapshot-based `Components` /
  `HistoricalComponents` shape (per the schema caveat in
  `dev/notes/phase1.1-eodhd-verification-2026-05-16.md`). The
  algorithm is vendor-agnostic; only the snapshot source changes.

## Adjacent vendor pointers (broader landscape)

This doc's scope is **point-in-time SP500 / Russell 3000 membership**. For
broader data-vendor questions — deep-history (Shiller, French), free
cross-check (Stooq, Tiingo), commodities (World Bank, datahub.io) — see
`dev/notes/deep-history-data-pointers-2026-05-16.md` and
`memory/reference_deep_history_data_sources.md`. Highlights:

- **Shillerdata.com** — free S&P monthly from **1871** (`ie_data.xls`).
  Next-pursue for long-horizon index anchor + EODHD adjusted-close
  cross-validation.
- **Kenneth French Data Library** — free portfolio + factor returns from
  **1926-07**. Synthesis target for pre-2006 backtests when real per-stock
  data isn't available.
- **Stooq** — free bulk EOD global. Pairs with manifest Phase 1 for
  EODHD-vs-Stooq drift detection.
- **CRSP-via-WRDS** is institutional-only and out of scope; Morningstar
  acquired CRSP Feb 2026 (access terms in flux).

## Sources

- EODHD pricing page (read 2026-05-16) — Fundamentals tier gating.
- EODHD `/api/user` + `/api/fundamentals/*` 2026-05-16 probes (PR
  #1106).
- iShares IWV holdings ajax endpoint, probed 2026-05-16 (PR #1108).
- `fja05680/sp500` GitHub repo (MIT, sp500_ticker_start_end.csv).
- Norgate Data product pages — Windows-only NDU client confirmation.
- Sharadar / Nasdaq Data Link product pages — coverage + pricing.
- `memory/project_strategic_pivot_broader_first.md` — strategic
  posture rationale.
- `memory/project_m5-5-tuning-exhausted.md` — tuning-surface
  exhaustion context.
