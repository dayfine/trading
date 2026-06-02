---
name: Deep-history stock/commodity data sources
description: Vendor catalog + synthesis methodology for 50-100y backtests. Free/low-cost alternatives to CRSP for the pre-2000 era.
type: reference
originSessionId: f999bf66-ce35-4bfd-b2cc-2b0461cc4c1b
---
# Deep-history data sources — Tier 1 (50-100y), Tier 2 (20-30y), Tier 3 (commodities)

External research compiled 2026-05-16. Vendor URLs + capability + tier-fit notes.

## Tier 1 — 50-100 year deep history

**Structurally impossible to get real per-stock daily data 1930s-1990s for free.** That data is CRSP-only (NYSE from 1925-12-31; AMEX from 1962; NASDAQ from late-1972). CRSP is WRDS-paywalled, institutional-only. **CRSP acquired by Morningstar Feb 2026** — access terms in flux.

### Free index-level anchors (the synthesis approach)

| Source | Coverage | URL | Format |
|---|---|---|---|
| **Shiller dataset** | S&P composite monthly: price, dividend, earnings, CPI, interest rates from **1871-01** (~155y) | `shillerdata.com` (`ie_data.xls`) | XLS |
| Shiller CSV mirror | Same | `github.com/datasets/s-and-p-500` | CSV |
| Shiller JSON wrapper | Same | `posix4e.github.io/shiller_wrapper_data` | JSON (no auth) |
| **Kenneth French Data Library** | Daily + monthly portfolio returns sorted by size / book-to-market / momentum / industry (e.g. 49-industry portfolios); Fama-French factors. Back to **1926-07**. | Search "Kenneth French data library" (Dartmouth/Tuck) | CSV |

### Synthesis design (for pre-2000 backtests when real per-stock unavailable)

- Use **French portfolio returns** as the systematic skeleton (industry × size × value × momentum buckets).
- Layer idiosyncratic noise calibrated to the cross-sectional dispersion implied by those portfolios.
- Rescale so the cap-weighted aggregate reproduces **Shiller's S&P series**.
- Output: synthetic per-symbol returns with realistic factor structure + index anchor.

### Pre-CRSP-NASDAQ caveats (bake into synthetic universe)

- **Pre-1962**: only NYSE-listed (largest firms). No true total-market index.
- **Pre-1972**: banks + financials not tracked in CRSP. Factor analyses suspect.
- Synthesis must reproduce this selection bias, not paper over it.

## Tier 2 — 20-30y US + international

**Current stack** (EODHD) largely covers. Alternates:

| Source | Coverage | Cost | Notes |
|---|---|---|---|
| **EODHD** (current) | 30+y US daily EOD; 15-20y for major EU/Asia exchanges | Paid EOD tier | OHLCV split/div adjusted. Fundamentals tier separate (we don't have it). |
| **Stooq** | Free bulk EOD global, indices + many tickers | Free | `stooq.com/db/h/` — uneven quality, NOT survivorship-bias-free. Good for cross-check vs EODHD. |
| **Tiingo** | 30+y, clean split/div adjusted, transparent flat pricing | Low-cost | Strong second source. |

### Point-in-time constituents (the survivorship-bias risk)

- **Single biggest data-integrity risk in the project.** Without point-in-time membership, "current constituents" backtests silently overestimate returns.
- **EODHD "Indices Historical Constituents"** add-on: claims up to 12y for global S&P / Dow Jones indices. **Russell coverage unverified — confirm with EODHD support.**
- Russell 3000 25y point-in-time = CRSP-tier (paywalled) OR our DIY IWV scrape (per `project_phase1_1996_membership_norgate.md`).

### International — local-exchange vs ADR tradeoff

- ADRs trade on US exchanges → trivially available from any US-focused source.
- ADR cons: FX translation artifacts, sponsorship/ratio changes, worse delisting survivorship.
- For retunable per-market system: prefer direct local-exchange data via EODHD over ADR proxies.

## Tier 3 — Commodities (best-served free tier)

| Source | Coverage | URL | Cost |
|---|---|---|---|
| **World Bank "Pink Sheet"** | Monthly prices ~70 commodities back to **1960** | Search "World Bank Commodity Markets Pink Sheet" | Free |
| **datahub.io/core/gold-prices** | Monthly gold USD since **1833** (1960+ from Pink Sheet, auto-updated daily) | `datahub.io/core/gold-prices` | Public Domain |
| **datahub.io/core/commodity-prices** | IMF-sourced 53 commodities + 10 indexes | `datahub.io/core/commodity-prices` | Free |
| **Nasdaq Data Link** | Daily spot ~100 commodities, free tier covers many | Nasdaq Data Link | Free tier |
| **EODHD futures** | Daily futures (recent ~20y) | EODHD (current) | Paid |

### Commodity futures gap

- Clean continuous back-adjusted daily futures series (Stevens / CHRIS-type) **mostly behind paywalls now**.
- Practical plan: monthly spot from World Bank/IMF for multi-decade regime-tuning; daily futures from EODHD or Nasdaq Data Link for recent 20y where live parameters matter.

## Bottom line for this project

- **Tier 2 + Tier 3 + Tier 1 index-anchor**: fully satisfiable with EODHD + Shiller + French + World Bank + datahub.
- **Tier 1 real per-stock**: impossible without CRSP. Synthesis is the correct engineering response, not a compromise.
- **Point-in-time Russell 3000 constituents** is the load-bearing risk. The DIY IWV scrape (2006-present) closes it for 20y+; pre-2006 needs either EODHD constituent add-on (verify) or synthesis from French industry portfolios.

## When to consult this memory

- Anytime the backtest horizon extends pre-2006 (Russell membership boundary).
- Anytime a synthetic-universe PR is in scope — Tier 1 anchors above are the calibration target.
- Commodity-strategy ambition — Tier 3 free sources cover the regime-tuning need.
- New-vendor evaluation — cross-check against EODHD + Stooq + Tiingo for the 20y tier.
