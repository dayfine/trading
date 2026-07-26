# Weekly picks — as-of 2026-07-24 (generated 2026-07-26)

First weekly run with the full post-FTH-incident hardening stack live:
RS-quality ranking (#2079), sparse-tail eligibility gate (#2090),
failed-breakout invalidation (#2087, armed this run at tolerance 0.05),
structural Weinstein stops + fixed-risk sized instructions (#2078 + #2091).
System version `2bcf5b335` (post-#2091 main).

## Pipeline

- **Fetch**: 12-batch parallel incremental, 3,173/3,173 symbols, 0 errors
  (bars through Fri 2026-07-24).
- **Inventory**: 5,734 symbols. **Warehouse**: incremental rebuild of
  `dev/data/snapshots/weekly-review` windowed [2024-06-01, 2026-07-24],
  3,173/3,173 verified, 0 failures.
- **Generate**: superset build universe = pinned 2026-06-26 (3,158) + 15
  context symbols; live overrides now arm `failed_breakout_tolerance_pct
  0.05` (merged into the `screening_config` overlay beside
  `candidate_ranking Quality` so neither clobbers the other).

## Result

**Bullish** (1.00); 8 strong sectors; **20 long candidates** led by CPK
(the full list + sized order tickets in `2bcf5b335/2026-07-24.md`);
0 shorts; 0 held (portfolio.sexp still the $100k template — set real
cash to size the tickets to your book).

**Structural stops live**: Risk % now varies 2.1-38.3% by chart structure
(was uniformly 8.0%); `*` marks the fallback-buffer cases; sizing responds
(tight-stop names cap at 30% of book, e.g. CPK 212sh/$30.0k/risk $623;
wide-stop CLMB gets 110sh/$2.6k at the full $999 risk).

**Sparse-tail gate harvest**: 18 zombie tickers dropped with reasons —
including SNSE (the FTH rename specimen, 2 bars in last 15 days) plus
17 more sparse feeds (BLD, VSCO, SATS, GTLS, ...). The rename problem is
clearly broader than one ticker → #2083-F2 (rename tracking via the live
returns-basis twin matcher) is the standing next fix.

## Caveats

- Universe still the 2026-06-26 pin — renamed/delisted names leave via
  the sparse gate rather than a refreshed universe; a re-pin +
  #2083-F2 belong to the next data-maintenance pass.
- Backfill comparison: 07-17 vs 07-24 lists share few names, but with
  ranked ordering + the invalidation gates this now reflects genuine
  breakout cohort turnover, not the alphabetical artifact (the 07-10 vs
  07-17 zero-overlap finding).
