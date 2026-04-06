# Status: screener

## Last updated: 2026-04-06

## Status
MERGED

## Interface stable
YES

## Blocked on
- None

## Completed

- SMA and Weighted MA indicators (`analysis/technical/indicators/sma/`) — 11 tests
- Weinstein shared types (`analysis/weinstein/types/`) — stage, ma_slope, overhead_quality,
  rs_trend, volume_confirmation, market_trend, grade variant types with metadata
- Stage Classifier (`analysis/weinstein/stage/`) — pure 4-stage classification with MA slope
  computation, prior_stage disambiguation (Stage1 vs Stage3), late-Stage2 detection,
  transition tracking — 12 tests; ma_type variant (Sma/Wma/Ema) added in review
- Relative Strength analyzer (`analysis/weinstein/rs/`) — Mansfield RS formula with
  zero-line normalization, 6 trend states, date-aligned intersection — 10 tests
- Volume analyzer (`analysis/weinstein/volume/`) — Weinstein's 2× breakout rule,
  Strong/Adequate/Weak classification, pullback contraction check — 12 tests
- Resistance mapper (`analysis/weinstein/resistance/`) — overhead resistance zone finder,
  Virgin/Clean/Moderate/Heavy grading, chart_years window filtering — 9 tests
- Stock Analyzer (`analysis/weinstein/stock_analysis/`) — aggregates all sub-analyses
  per ticker, breakout/breakdown candidate detection — 8 tests
- Screener (`analysis/weinstein/screener/`) — cascade filter (macro gate → sector gate →
  scoring → grade), buy/short candidate ranking with entry/stop/risk/swing — 9 tests
- Macro Analyzer (`analysis/weinstein/macro/`) — weighted composite regime from 5 indicators
  (index stage, A-D divergence, momentum index, NH-NL, global consensus), regime change
  detection — 10 tests
- Sector Analyzer (`analysis/weinstein/sector/`) — stage + RS + constituent breadth
  combines into Strong/Neutral/Weak rating, sector_context_of for screener — 6 tests

Total: 87 new tests across 9 modules, all merged to main.

## In Progress
- None — all code merged to main

## Follow-up / Known Improvements

### Stage classifier: segmentation-based MA direction
`stage/lib/stage.ml` currently classifies MA direction via a two-point slope
comparison (MA_now vs MA_[lookback]_ago). Consider replacing this with the
piecewise linear segmentation in `analysis/technical/trend/lib/segmentation.ml`,
which fits a regression to the MA series and classifies the slope of the most
recent segment. Benefits: fewer false direction flips from short-term noise,
better base-building detection. See module comment in `stage.mli` for details.

### Stage state machine functor
`_classify_new_stage` encodes the valid Stage 1–4 transitions as a large
pattern match. A state machine functor would make valid transitions explicit and
could be shared with the Weinstein stop state machine in `weinstein/portfolio_risk`.
Consider when both state machines are stable enough to identify shared structure.

### Shared MA slope utility
`_compute_ma_slope` duplicates a pattern also in the RS analyser and likely the
macro analyser. Extract a `Ma_utils` module under `analysis/technical/indicators/`
with a single `slope ~lookback ~threshold series → ma_direction * float` function.
See module comment in `stage.mli` for the proposed signature.

### Stage classifier: incremental `classify_step` for simulation
`classify` recomputes the full MA series from all bars on each call — O(n) per
weekly step. For the simulation loop this is fine at current scale, but when
simulation performance becomes a bottleneck add a `classify_step` that takes the
previous `result` + one new bar and updates the MA incrementally in O(1). The
existing `classify` stays as the cold-start entry point. See module comment in
`stage.mli` for the proposed signature.

## Recent Commits (merged PRs)
- #120: Add Stock Analyzer and Cascade Screener
- #121: Add Macro Analyzer and Sector Analyzer
- #122: Screener QC: APPROVED — migrate tests to Matchers, fix magic numbers
- #160: screener/stock-analysis: Add StockAnalysis module
- #164: Add Resistance analysis module
- #165: Add Volume analysis module
