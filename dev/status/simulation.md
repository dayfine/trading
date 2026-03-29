# Status: simulation

## Last updated: 2026-03-29

## Status
WAITING

## Interface stable
NO

## Blocked on
- data-layer: MERGED (unblocked)
- portfolio-stops: PLANNING
- screener: READY_FOR_REVIEW

## Completed
—

## In Progress
—

## Next Steps
- Read docs/design/eng-design-4-simulation-tuning.md
- Study existing trading/simulation/ and trading/strategy/ modules
- Wait for portfolio-stops and screener → "Interface stable: YES"
- While waiting: draft Weinstein_strategy .mli and config types

## Inherited from data-layer
- `Synthetic_source`: implement `analysis/weinstein/data_source/lib/synthetic_source.ml` — deterministic programmatic bar generation (Trending, Basing, Breakout patterns) for stress testing and parameter tuning. Must satisfy `DATA_SOURCE` interface. Deferred here because it is only needed for simulation/tuning, not for live screener runs.

## Recent Commits
—
