# Status: screener

## Last updated: —

## Status
WAITING

## Interface stable
NO

## Blocked on
data-layer interface: WAITING

## Completed
—

## In Progress
—

## Next Steps
- Read docs/design/eng-design-2-screener-analysis.md
- Read docs/design/weinstein-book-reference.md (primary domain reference)
- Wait for dev/status/data-layer.md → "Interface stable: YES"
- While waiting: draft Analyzer + Screener .mli interfaces

## Followup / Known Improvements

### Stage classifier: segmentation-based MA direction
`stage/lib/stage.ml` currently classifies MA direction via a two-point slope
comparison (MA_now vs MA_[lookback]_ago). Consider replacing this with the
piecewise linear segmentation in `analysis/technical/trend/lib/segmentation.ml`,
which fits a regression to the MA series and classifies the slope of the most
recent segment. Benefits: fewer false direction flips from short-term noise,
better base-building detection. See module comment in `stage.mli` for details.

### Stage classifier: incremental `classify_step` for simulation
`classify` recomputes the full MA series from all bars on each call — O(n) per
weekly step. For the simulation loop this is fine at current scale, but when
simulation performance becomes a bottleneck add a `classify_step` that takes the
previous `result` + one new bar and updates the MA incrementally in O(1). The
existing `classify` stays as the cold-start entry point. See module comment in
`stage.mli` for the proposed signature.

## Recent Commits
—
