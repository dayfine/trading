# Status: simulation

## Last updated: —

## Status
WAITING

## Interface stable
NO

## Blocked on
data-layer: WAITING
portfolio-stops: WAITING
screener: WAITING

## Completed
—

## In Progress
—

## Next Steps
- Read docs/design/eng-design-4-simulation-tuning.md
- Study existing trading/simulation/ and trading/strategy/ modules
- Wait for all three dependencies → "Interface stable: YES"
- While waiting: draft Weinstein_strategy .mli and config types

## Inherited from data-layer
- `Synthetic_source`: implement `analysis/weinstein/data_source/lib/synthetic_source.ml` — deterministic programmatic bar generation (Trending, Basing, Breakout patterns) for stress testing and parameter tuning. Must satisfy `DATA_SOURCE` interface. Deferred here because it is only needed for simulation/tuning, not for live screener runs.

## Recent Commits
—
