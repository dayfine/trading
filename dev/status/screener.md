# Status: screener

## Last updated: 2026-03-30

## Status
READY_FOR_REVIEW

## Interface stable
YES

## Blocked on
- None (data-layer MERGED)

## Completed

### 2026-03-29
- Stack rebased onto new main after screener/stage merge

### 2026-03-28
- All screener modules implemented and passing tests
- `screener/rs`: Relative Strength analyzer
- `screener/volume-resistance`: Volume and Resistance analyzers
- `screener/stock-analysis`: StockAnalysis aggregation module
- `screener/stock-screener`: Screener cascade filter (macro → sector → stock)
- `screener/macro`: Macro market analyzer (with review commit strengthening test)
- `screener/sector`: Sector analyzer
- `feat/screener`: SMA refactor (share impl with WMA via weight_fn)
- All PRs open and awaiting review/merge in order (screener/rs first)

### 2026-03-27
- `screener/stage` (stage classifier) reviewed and merged (#134)
- Review commits applied: helpers extracted, Sma lib integrated, ma_type variant (Sma/Wma/Ema) added

## In Progress
- None — all code done, PRs open for review

## Followup / Known Improvements

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

## Recent Commits
- screener/rs: Add Relative Strength (RS) analyzer
- screener/volume-resistance: Add Resistance and Volume analysis modules
- screener/stock-analysis: Add StockAnalysis module
- screener/stock-screener: Add Screener module with cascade filter
- screener/macro: Add Macro market analyzer
- screener/sector: Add Sector analyzer
- feat/screener: Refactor SMA, share impl with WMA
