; Deep-history + cross-check data-source pointers (2026-05-16)

# Deep-history + cross-check data-source pointers

Date: 2026-05-16. Companion to `dev/notes/vendor-comparison-historical-universe-2026-05-16.md`.

That doc is scoped to **point-in-time SP500 / Russell 3000 membership** (Phase
1.4 IWV path). This doc captures the broader vendor landscape — deep-history
(50-100y), free cross-check, international, and commodities — surfaced during
the 2026-05-16 strategic review. Sources behind the recommendations live in
`memory/reference_deep_history_data_sources.md`.

## TL;DR

- **Tier 1 (50-100y per-stock real data) is impossible without CRSP/WRDS.** Institutional-only. Morningstar acquisition Feb 2026 — access terms in flux. Don't plan around it.
- **Tier 1 index-level anchor is free.** **Shiller** (S&P monthly from **1871**) + **Kenneth French Data Library** (portfolio returns + factors from **1926-07**). The synthesis path — French portfolios as systematic skeleton + idiosyncratic noise calibrated to dispersion + rescale to Shiller — is the *correct* engineering response to 50-100y backtest ambitions, not a compromise. **Shillerdata.com is the immediate next-pursue.**
- **Tier 2 cross-check is free.** **Stooq** (free bulk EOD global) is a second-source for the 41,575-symbol EODHD cache. Pairs naturally with the manifest/hash-verify Phase 1 plan: once we have a sha256 per symbol, EODHD-vs-Stooq drift detection is a one-line audit script.
- **Tier 2 alternate** is **Tiingo** (low-cost flat pricing) if EODHD ever changes terms.
- **Tier 3 commodities is free and deep.** **World Bank Pink Sheet** (monthly ~70 commodities from 1960) + **datahub.io/core/gold-prices** (USD monthly since 1833, Public Domain) + **datahub.io/core/commodity-prices** (IMF 53 commodities + 10 indexes). Daily continuous futures still paywalled.
- **Point-in-time index constituents is THE load-bearing risk** (per external review). Our DIY IWV scrape closes 2006-2026; pre-2006 needs EODHD constituent add-on (unverified for Russell) OR synthesis from French industry portfolios.

## Per-tier detail

### Tier 1 — 50-100y deep history

#### What does NOT exist for free
Real per-stock daily data 1925-1999. CRSP-only. NYSE from 1925-12-31; AMEX
from 1962; NASDAQ from late-1972. WRDS access institutional-only. Morningstar
acquired CRSP Feb 2026 — access terms uncertain.

#### What IS available for free

| Source | URL | Coverage | Format |
|---|---|---|---|
| **Shiller dataset** | `shillerdata.com` (`ie_data.xls`) | S&P monthly: price, dividend, earnings, CPI, interest rates from **1871-01** | XLS |
| Shiller CSV mirror | `github.com/datasets/s-and-p-500` | Same | CSV |
| Shiller JSON wrapper | `posix4e.github.io/shiller_wrapper_data` | Same | JSON (no auth) |
| **Kenneth French Data Library** | Dartmouth/Tuck search | Daily + monthly portfolio returns sorted by size / book-to-market / momentum / 49-industry; Fama-French factors. From **1926-07** | CSV |

#### Synthesis methodology (for pre-2000 backtests)

1. **Skeleton**: French portfolio returns provide systematic factor structure (industry × size × value × momentum).
2. **Idiosyncratic noise**: layer in synthetic per-symbol noise calibrated to the cross-sectional dispersion implied by those portfolios.
3. **Aggregate constraint**: rescale so the cap-weighted aggregate reproduces Shiller's S&P composite series.
4. Output: synthetic per-symbol returns with realistic factor structure + index anchor.

#### Pre-CRSP-NASDAQ caveats

- **Pre-1962**: only NYSE-listed (largest firms). No true total-market index.
- **Pre-1972**: banks + financials not tracked in CRSP. Factor analyses suspect.
- Synthesis must reproduce this selection bias rather than paper over it.

#### Why pursue Shiller next

- **Zero marginal cost** (XLS + CSV + JSON mirrors all free, no signup).
- **155 years of index data** — gives the anchor for any synthesis we eventually build.
- **Validation use case TODAY**: pin our SP500 long-horizon baseline against Shiller's monthly series → independent verification of EODHD's adjusted-close construction over the 26y on-disk window. Detects vendor split/dividend revisions.
- Minimal scope: ingest the XLS, normalize to our `Daily_price`-equivalent monthly schema, store as a pinned fixture under `analysis/data/sources/shiller/`. ~200 LOC.

### Tier 2 — 20-30y US + international

#### Cross-check against current EODHD

| Source | URL | Cost | Notes |
|---|---|---|---|
| **EODHD** (current) | — | Paid EOD tier | 30+y US daily; 15-20y EU/Asia. OHLCV split/div adjusted. Fundamentals tier separate (we don't have). |
| **Stooq** | `stooq.com/db/h/` | Free | Bulk EOD global, indices + many tickers. Uneven quality, NOT survivorship-bias-free. **Use as cross-check, not primary.** |
| **Tiingo** | Search Tiingo | Low-cost | 30+y, clean split/div adjusted, transparent flat pricing. |

#### Stooq cross-check design (pairs with manifest Phase 1)

When the CSV-layer manifest (per `dev/plans/data-inventory-and-reproducibility-2026-05-02.md`) lands:

1. For each symbol in `data/sectors.csv`, fetch the matching Stooq bulk file.
2. Compute daily-return divergence vs the EODHD `data.csv`.
3. Flag any symbol with >1% return divergence on any single day OR >0.1% cumulative divergence over the full history.
4. Write divergences to `dev/data/cross-check/eodhd-vs-stooq.sexp`.

This costs nothing (Stooq is free) and gives us an independent integrity audit
that catches:
- EODHD silent split-revisions (G14-class bugs).
- EODHD adjusted-close drift across vendor revisions.
- Tickers renamed without our manifest catching it.

#### Point-in-time constituents — the load-bearing risk

External review (2026-05-16) called this "the single biggest data-integrity
risk in the whole project." Without point-in-time membership, "current
constituents" backtests silently overestimate returns.

**Status of mitigations:**

| Period | Path | Status |
|---|---|---|
| 2006-2026 Russell 3000 | DIY IWV scrape | Code ready (PRs #1112, #1131, #1137); blocked on Akamai IP cooldown OR GHA workflow #1138 |
| 2000-2010 SP500 | EODHD Fundamentals constituents add-on (12y claim, unverified Russell) | Vendor query needed — confirm Russell coverage before relying |
| 1996-1999 SP500 | `fja05680/sp500` static seed (MIT) | Deferred per broader-first pivot |
| 1925-1995 | Synthesis from French industry portfolios | Not yet scoped |

### Tier 2 — international expansion

If we extend beyond US: prefer **direct local-exchange data via EODHD** over
ADR proxies. ADRs introduce FX translation artifacts, sponsorship/ratio
changes, and worse delisting survivorship. ADR is fine for screening / proxy
but not for retunable per-market strategies.

### Tier 3 — Commodities

Best-served tier for free deep history.

| Source | URL | Coverage | Cost |
|---|---|---|---|
| **World Bank "Pink Sheet"** | Search "World Bank Commodity Markets Pink Sheet" | Monthly prices ~70 commodities back to **1960** | Free |
| **datahub.io/core/gold-prices** | `datahub.io/core/gold-prices` | Monthly gold USD since **1833**; 1960+ from Pink Sheet; auto-updated daily | Public Domain |
| **datahub.io/core/commodity-prices** | `datahub.io/core/commodity-prices` | IMF 53 commodities + 10 indexes | Free |
| **Nasdaq Data Link** | Nasdaq Data Link | Daily spot ~100 commodities; free tier covers many | Free tier |
| **EODHD futures** | — | Daily futures (recent ~20y) | Already have |

Daily continuous back-adjusted futures (Stevens / CHRIS-type) are mostly behind
paywalls now. Realistic plan if/when commodity-strategy is in scope:

- Monthly spot from World Bank/IMF for multi-decade regime-tuning.
- Daily futures from EODHD or Nasdaq Data Link for the recent 20y where live
  parameters matter.

## Recommended next-pursue ordering

1. **Shillerdata.com ingest** (~200 LOC). Free, low-effort, unlocks
   long-horizon index baseline + EODHD adjusted-close validation. The
   immediate next data-vendor PR.
2. **Stooq cross-check** (gated on manifest Phase 1). Once the CSV manifest
   lands, ~50 LOC script to flag EODHD-vs-Stooq divergence. Independent
   integrity audit.
3. **Kenneth French ingest** (if/when synthesis pre-2006 backtests are in
   scope). Higher LOC (~400) due to multiple portfolio sorts; not urgent.
4. **EODHD Indices Historical Constituents add-on** — vendor query first
   (Russell coverage unverified). If covered, that retires the IWV scrape
   for the 12y window it covers; if not, IWV stays primary.
5. **World Bank Pink Sheet + datahub commodities** — only when
   commodity-strategy is in scope. Not on near-term roadmap.

## Cross-cutting constraints

- **No Python.** All ingest clients in OCaml + `cohttp` + the repo's existing
  CSV / sexp infra. Reference repos read for URL patterns + schemas only,
  never executed.
- **Caching layout.** `dev/data/<vendor>/...` (gitignored).
- **Pinned fixtures.** Small test fixtures under
  `analysis/data/sources/<vendor>/test/data/`.
- **Manifest provenance.** Every emitted universe / pricing sexp carries
  `source=<vendor>-<descriptor>` header line. Authority:
  `dev/plans/data-inventory-and-reproducibility-2026-05-02.md`.

## References

- `memory/reference_deep_history_data_sources.md` — vendor catalog + URLs.
- `dev/notes/vendor-comparison-historical-universe-2026-05-16.md` — Phase 1.4
  IWV path detail (this doc's companion).
- `dev/plans/data-inventory-and-reproducibility-2026-05-02.md` — manifest
  plan (where Stooq cross-check plugs in).
- `memory/project_strategic_pivot_broader_first.md` — broader-first posture.
- `memory/project_phase1_1996_membership_norgate.md` — Norgate retirement
  context.

## External review attribution

Vendor landscape compiled from a 2026-05-16 external research review. Original
notes saved to memory; this doc adapts them to repo-specific terms +
next-action ordering.
