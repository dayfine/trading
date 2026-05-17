# Custom-universe bidirectional plan — 2026-05-17

Date: 2026-05-17. Track: `data-foundations`. Plan-first deliverable; the
implementation lands as a stack of small PRs (Q1: three PRs; Q2: two PRs).

## 0. Context

The 2026-05-16 vendor sweep
(`dev/notes/vendor-comparison-historical-universe-2026-05-16.md`) retired the
Norgate Data Updater path (Windows-only — incompatible with our
Mac/Linux/Docker toolchain). The vendor mix we are committed to is:

- **EODHD** for daily OHLCV (2000-present, equities + delisted-aware).
- **DIY iShares IWV scrape** for point-in-time Russell 3000 membership
  (2006-present) — covered by `dev/plans/iwv-scraper-2026-05-16.md`.
- **fja05680/sp500** for S&P 500 changes 1996-1999 (interim until
  Wikipedia changes table cleanly covers the same window).
- **Wikipedia + EODHD** for S&P 500 2010-present
  (`dev/plans/wiki-eodhd-historical-universe-2026-05-03.md`).
- **Kenneth French Data Library** for industry-portfolio factor returns
  pre-1996 (already landed PR #1152 — daily 5-industry).
- **Shiller** for the 1871-1925 macro layer (synthesis-only, no
  individual-name backtests pre-1926).

This plan covers the "custom universe" axis — how we slice inventory
symbols (~41,575 cached) into Weinstein-eligible universes. It is
bidirectional: Q1 narrows from inventory-down (drop non-equity-like
instruments before the Weinstein screener sees them), and Q2 widens from
membership-up (pre-1996 SP500 backbone via Kenneth French synthesis +
Shiller macro).

## 1. Q1 — Asset-type filter for inventory-down universe trimming

The 41,575 cached symbols include mutual funds, ETFs, fund-of-funds,
indices, and a long tail of bond / currency / commodity instruments. The
Weinstein stage classifier was designed for common stock; running it
against an ETF is a category error (no stage transitions, no breakouts —
just a tracking error against the underlying basket).

We parse EODHD's `/api/exchange-symbol-list/{exchange}` `Type` field,
join it against the inventory, and expose a pure filter that drops any
symbol whose classification is not equity-like.

### Q1 PR1 — `Eodhd.Asset_type` parser (#1156, MERGED)

Adds `Eodhd.Asset_type.t` (11 named variants + `Other of string` catch-all),
`of_eodhd_string` / `to_string` / `is_equity_like` helpers, and reshapes
`Eodhd.Http_client.get_symbols` to return `symbol_metadata` records
(`{ code; name; exchange; asset_type }`) so callers can filter without
re-parsing the JSON.

### Q1 PR2 — Bulk enrichment exe + `data/symbol_types.sexp` (#1157, MERGED)

Adds `analysis/scripts/asset_type_enrichment/` with a pure `join` library
(many-to-one: inventory symbols → enriched entries), an executable that
fetches the full US `/api/exchange-symbol-list` and writes
`data/symbol_types.sexp` (~5 MB, 41,575 entries), and a tested round-trip
save / load.

Design choice: `enriched_asset_type` wraps `Eodhd.Asset_type.t` with a
`Not_in_eodhd_listing` sentinel rather than extending the parser variant
itself — keeps the parser's narrow contract intact (one-shot response
shape) and confines the "absent from listing" concept to the enrichment
library.

Per-type counts after the bulk run (2026-05-17):

| Asset type            | Count   |
|-----------------------|---------|
| Fund                  | 15,832  |
| Common Stock          | 13,348  |
| ETF                   | 5,205   |
| Not_in_eodhd_listing  | 4,353   |
| Mutual Fund           | 2,205   |
| Preferred Stock       | 538     |
| Other:Warrant         | 47      |
| Other:Notes           | 26      |
| Other:Unit            | 19      |
| Other:BOND            | 1       |
| Other:ETC             | 1       |
| **Total**             | 41,575  |

Roughly 33% of the inventory passes `is_equity_like` (Common + Preferred).

### Q1 PR3 — `filter_equity_like_symbols` consumer (this PR)

Adds `Asset_type_enrichment_lib.filter_equity_like_symbols` — a pure
function `~symbol_types -> ~symbols:string list -> string list` that
drops every symbol whose `asset_type` is not equity-like (anything other
than `Common_stock`, `Preferred_stock`, `ADR`, `GDR`). Order-preserving;
symbols absent from `symbol_types` are dropped.

The filter lives in the enrichment library, not in `universe_filter/`,
because:
1. `asset_type_enrichment_lib` already owns the `t` / `entry` types and
   the only dependency is `Eodhd.Asset_type`. Universe_filter would have
   to take a new dep on enrichment OR Eodhd just for the predicate.
2. The function is one-line on top of `Eodhd.Asset_type.is_equity_like`;
   making a new module for it is over-abstraction.
3. Universe_filter remains script-shaped (CSV in → sexp out). The
   asset-type pass is more naturally a library primitive that any caller
   (universe_filter, future broad-universe pipelines, ad-hoc analysis)
   can compose without booting universe_filter's CSV codepath.

Tests pin the equity-only contract over a 12-listing fixture covering
every named `Asset_type.t` variant plus `Other _` and absent-from-index;
a second test pins order preservation.

## 2. Q2 — Pre-1996 SP500 backbone (synthesis)

Q1's filter narrows the inventory we already have. Q2 widens history past
the EODHD floor (2000) and the fja05680/sp500 floor (1996).

### Q2-A — Decomposition (1996-2000 gap)

Between fja05680/sp500's earliest commit (1996-01-02) and EODHD's
earliest daily OHLCV (2000-01-03), we have membership but no per-symbol
prices. The two viable closures are:

1. **Stooq daily backfill** for the 200-300 SP500 names that traded in
   1996-1999 and survived into the EODHD window. Stooq covers most
   pre-2000 US-listed common stock; gaps are filled with
   forward-from-EODHD where the symbol survives and dropped where it
   doesn't.
2. **Forward-only backtests pre-2000**: restrict the Weinstein simulator
   to symbols where we have continuous coverage from the entry date
   forward. Names whose history starts inside the backtest window are
   excluded for that window's purposes.

Q2-A PR: `analysis/data/sources/stooq/` — minimal client + bulk fetch
for a fixed SP500 1996-1999 backbone list. Not yet started.

### Q2-B — Decomposition (1926-1997 industry-aggregate synthesis)

Pre-1996 we abandon individual-name coverage entirely. The substitute is
Kenneth French's 5-industry daily-portfolio returns (already landed via
PR #1152) projected backward to 1926-07-01.

The Weinstein simulator runs against the 5 industry portfolios as if
they were stocks. The portfolios trade like stocks (no dividends in the
return series — total-return index), they have a continuous 99-year
history, and they're statistically equivalent to running the simulator
against an equal-weight subuniverse of every SP500 member at the time.
The information content is lower per-bar (5 series instead of 500), but
that's the price of a 1926 backbone.

Q2-B PR: `analysis/data/synthetic/french_industry_universe/` —
wraps the existing French daily output as a Weinstein-compatible
universe. Not yet started.

## 3. Sequencing

| PR | Name | Status |
|----|------|--------|
| Q1 PR1 | `Eodhd.Asset_type` parser | MERGED (#1156) |
| Q1 PR2 | Bulk enrichment exe + `symbol_types.sexp` | MERGED (#1157) |
| Q1 PR3 | `filter_equity_like_symbols` | THIS PR |
| Q2-A   | Stooq 1996-1999 backbone | NOT STARTED |
| Q2-B   | French-industry universe (1926-1997) | NOT STARTED |

Q1 is self-contained — it doesn't depend on Q2 and unblocks downstream
broader-universe backtests immediately. Q2 is sequenced after the
broader-universe (Russell 3000) work in `iwv-scraper-2026-05-16.md`
finishes — running Weinstein against 3,000 names will tell us whether
the deep-history extension is worth the synthesis complexity.

## 4. Authority + cross-references

- `dev/notes/vendor-comparison-historical-universe-2026-05-16.md` — why
  this vendor mix.
- `dev/plans/iwv-scraper-2026-05-16.md` — Russell 3000 reconstitution
  (parallel work, not on this plan's critical path).
- `dev/plans/wiki-eodhd-historical-universe-2026-05-03.md` — SP500
  2010-present (already landed).
- Companion `.mli`:
  - `trading/analysis/data/sources/eodhd/lib/asset_type.mli`
  - `trading/analysis/scripts/asset_type_enrichment/lib/asset_type_enrichment_lib.mli`
