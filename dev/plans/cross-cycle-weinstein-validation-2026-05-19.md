# Cross-cycle Weinstein validation — multi-milestone plan

Date: 2026-05-19. Companion to
`dev/notes/deep-history-data-pointers-2026-05-16.md` and
`memory/reference_deep_history_data_sources.md`.

## Problem statement

Stan Weinstein's *Secrets for Profiting in Bull and Bear Markets* was
published 1988, calibrated on tape from the 1970s-80s (post-Bretton Woods
stagflation through the start of the 1982-2000 secular bull). Our
current backtest universe is **sp500-2010-2026** — a single regime
(post-GFC QE through 2022 hike cycle). Cell-E's 0.94 Sharpe on 15y is
a useful baseline but tells us nothing about robustness across:

- 1929-39 depression
- 1945-66 post-WWII secular bull
- 1966-82 stagflation
- 1973-74 bear
- 1982-2000 secular bull (incl. 1987 crash, 1990 recession)
- 2000-02 tech bust
- 2007-09 GFC
- 2020 COVID flash crash
- 2022 hike cycle (partially covered by current backtest)

The strategy may be **regime-specific**. A Weinstein-faithful
implementation should profit in every regime where the 30-week MA
stage framework is informative — broadly, anywhere there are
distinguishable Stage-2 advancers vs Stage-4 decliners. The
secular bull of 1982-2000 likely flatters the framework; the
range-bound 1966-82 stagflation may destroy it.

## Data constraints (the load-bearing reality)

Per `dev/notes/deep-history-data-pointers-2026-05-16.md`:

- **Per-stock daily 1925-1999**: CRSP. Institutional-only. Morningstar
  acquired Feb 2026; access uncertain. **Assume unavailable.**
- **Index-level S&P from 1871**: Shiller dataset (XLS / CSV / JSON
  mirrors). FREE. Monthly granularity (daily not available pre-1962
  for free).
- **Portfolio-level from 1926**: Kenneth French Data Library. FREE.
  49 industries, size × value × momentum sorts, daily granularity.
- **Tier-2 commodities + international**: deferred to later milestones.

The plan is shaped by what's free.

## Milestones

### M1: Shiller index Weinstein reduction (cheapest)

**Goal**: run a single-symbol Weinstein on monthly S&P data
1871-2025. Validate the framework on 155y of regime variation.

**Deliverable**: decade-by-decade Sharpe + MaxDD table.

**Scope** (~2 PRs, ~400 LOC):

1. **PR-A**: Shiller ingest. Pull `ie_data.xls` (or the JSON mirror at
   `posix4e.github.io/shiller_wrapper_data`). Normalise to
   `Daily_price.t`-shaped monthly rows: date, close = real S&P
   (CPI-deflated), volume = N/A (zero or NaN). Store as a pinned
   fixture under `analysis/data/sources/shiller/`. ~200 LOC.

2. **PR-B**: monthly-bar Weinstein reduction. The full strategy
   requires daily bars + cross-sectional ranking; the reduction runs
   on **one symbol** (S&P index) with the **simplest stage
   classifier** (price vs 30-month MA = ~30-week × 4-week aggregate).
   No screener cascade, no relative strength. Strategy:
   - Long S&P when price > rising 30-month MA
   - Cash when price < 30-month MA
   - Optional short variant: short S&P when price < falling 30-month MA
   
   ~200 LOC. Standalone strategy module; does not touch the production
   Weinstein impl.

**Output**: a single table:

```
Decade        | Strategy CAGR | B&H CAGR | Strategy Sharpe | Strategy MaxDD
1871-1880     |  X.X%         |  X.X%    | X.XX            | -X.X%
1880-1890     |  ...
...
2020-2025     |  ...
```

Plus a chart: cumulative-return curves (strategy vs buy-and-hold)
overlaid 1871-2025.

**Limitations**: index-level only. No cross-sectional ranking, no
sector rotation, no per-stock RS. The 30-month MA is a coarse proxy
for 30-week. Monthly granularity means we can't measure intra-month
stop performance. But for the question "does the stage framework
profit at all in 1929 / 1973 / 2000?" this is sufficient.

**Sequencing**: pursue immediately after v1 sweep lands. ~1 week of
work.

### M2: French 49-industry portfolio Weinstein

**Goal**: extend M1 to cross-sectional cadence — run Weinstein-style
ranking across 49 French industry portfolios, daily, 1926-2025.

**Deliverable**: per-decade Sharpe + DD on a Long-top-K-industries /
Short-bottom-K-industries rotation strategy.

**Scope** (~3 PRs, ~1k LOC):

1. **PR-C**: French Data Library ingest. The library exposes 49
   daily-industry-return series + Fama-French factor series. Pull
   from the Dartmouth/Tuck CSVs. Normalise to `Daily_price.t`-shaped
   (synthetic price levels reconstructed from cumulative returns).
   ~300 LOC. Storage under `analysis/data/sources/french/`.

2. **PR-D**: daily-bar Weinstein-style industry rotation. Strategy:
   - For each industry, compute 30-week MA + stage classification.
   - Rank Stage-2 industries by 13-week relative strength vs market.
   - Long the top-5 industries; short the bottom-5 (or cash variant
     for long-only comparison).
   - Rebalance weekly.
   
   ~500 LOC. Standalone strategy module.

3. **PR-E**: 100y decade-by-decade results write-up.

**Limitations**: still not per-stock. Industry-level granularity
hides intra-industry dispersion. But this DOES test the
**cross-sectional core** of Weinstein (Stage-2 advancers outperform
Stage-4 decliners) on 100y of data. If this fails in
1966-82 stagflation, the framework is regime-specific.

**Sequencing**: depends on M1 result. If M1 shows the framework profits
in every regime, M2 is a higher-confidence test. If M1 fails in some
regime, M2 may explain why (industry rotation gives more degrees of
freedom than index timing).

### M3: Synthesised per-stock 1925-1999

**Goal**: run the FULL production strategy (525-symbol cascade with
sector ETFs, AD breadth, etc.) on synthesised pre-2000 per-stock data.

**Deliverable**: per-decade Sharpe + DD using the same strategy
artifact we're shipping today, on 1925-1999 + 2000-2025 = ~100y.

**Scope** (~5 PRs, ~3k LOC, multi-week effort):

1. **PR-F**: factor-anchored synthesis methodology. Use French
   portfolios as the systematic skeleton (size × value × momentum ×
   industry); layer idiosyncratic noise calibrated to cross-sectional
   dispersion; rescale so the cap-weighted aggregate reproduces
   Shiller's S&P composite. ~1.5k LOC. Most expensive PR.

2. **PR-G**: synthesis validation. Compare synthesised 2000-2025
   universe-aggregate against ACTUAL EODHD 2000-2025 universe-aggregate.
   If the synthesis matches actual cross-sectional dispersion + factor
   loadings + return distribution within tolerance, we can trust the
   pre-2000 synthesis. ~300 LOC. **This is the make-or-break PR — if
   synthesis fails validation, M3 is not viable.**

3. **PR-H, I, J**: pin the synthesised pre-2000 universe as a backtest
   fixture; run the production cascade; emit decade-by-decade results.

**Limitations**: synthesised data, not real. We're testing whether the
strategy profits in a counterfactual 1929/1973 that's been hand-rolled
to match observable factor structure. Findings are weaker than M1/M2
which use real (if index-level) data.

**Sequencing**: blocks on M1 + M2 demonstrating the index/industry
levels show interesting regime variance worth investigating at
per-stock level. If M1 shows the framework profits uniformly, M3
adds little. If M1 shows regime collapse in 1973-82 stagflation, M3
becomes critical for figuring out which sub-population (large vs
small, value vs growth) drove the collapse.

### M4 (stretch): CRSP access via Morningstar

**Goal**: real per-stock 1925-1999 daily, no synthesis. The
gold-standard test.

**Status**: blocked on Morningstar institutional terms post-Feb 2026
acquisition. Not actionable today.

**Scope**: pure data-acquisition cost; ingest is a small PR if access
materialises. Park.

## Decision tree

```
v1 Bayesian sweep lands → cell-E baseline pinned on 2010-2025
  ↓
M1 Shiller index Weinstein (1-week effort)
  ↓
  ├─ Framework profits in every regime → great, low-priority M2-M3
  │   (proceed only if curiosity or regulatory ask)
  │
  └─ Framework collapses in 1 or 2 regimes (e.g. stagflation, depression)
      ↓
      M2 French industry-rotation (2-week effort)
      ↓
      ├─ Industry rotation works where index fails → cross-sectional
      │   ranking IS the value-add. Production strategy is well-grounded.
      │
      └─ Industry rotation ALSO collapses in same regimes → cross-sectional
          ranking does not save the framework. M3 becomes load-bearing
          (need per-stock granularity to find what does work).
```

## What this is NOT

- Not a "go fetch CRSP / Sharadar / Norgate" plan. We've ruled those
  out (paywall + Windows-only for Norgate).
- Not a full historical-universe-construction plan (that's Phase 1.x
  per `dev/notes/vendor-comparison-historical-universe-2026-05-16.md`).
  This is the *complementary* deep-history validation lane.
- Not a path to running the production strategy on real per-stock
  1925-1999 data. That requires CRSP, which we can't get.

## Effort summary

| Milestone | PRs | LOC | Wall time | Data source |
|---|---:|---:|---|---|
| M1: Shiller index | 2 | ~400 | 1 week | Shiller (free) |
| M2: French industry | 3 | ~1000 | 2 weeks | French (free) |
| M3: Synthesised per-stock | 5 | ~3000 | 3-4 weeks | Synthesis (free) |
| M4: CRSP | 1 (data only) | ~200 | TBD | CRSP (paywall) |

Total realistic-effort budget: ~5-8 weeks for M1+M2+M3, gated by M1
results. M4 stays parked.

## Cross-references

- `dev/notes/deep-history-data-pointers-2026-05-16.md` — vendor matrix
- `dev/notes/vendor-comparison-historical-universe-2026-05-16.md` —
  IWV / SP500 historical-universe sub-plan (orthogonal to this one)
- `memory/reference_deep_history_data_sources.md` — source list
- `docs/design/weinstein-book-reference.md` — domain reference (book
  rules + parameter values)
