# Status: simulation

## Last updated: 2026-03-29

## Status
WAITING

## Interface stable
NO

## Blocked on
- data-layer: MERGED (unblocked)
- portfolio-stops: PLANNING (need stop state machine interface)
- screener: READY_FOR_REVIEW (need Screener + StockAnalysis interface)

## Existing infrastructure — DO NOT reimplement
`trading/trading/simulation/` is a **generic** framework shared across all strategies (not Weinstein-specific). Phases 1–3 are complete and tested:
- **Phase 1** (core types): `config`, `step_result`, `step_outcome`, `run_result` in `lib/types/simulator_types.ml`
- **Phase 2** (OHLC price path): intraday path generation, order fill detection for all order types
- **Phase 3** (daily loop): `step` and `run` implemented; engine + order manager + portfolio wired up
- The simulator already takes a `(module STRATEGY)` in its `dependencies` record

The Weinstein work in eng-design-4 adds Weinstein-specific components **on top** without breaking general use:
- Add `strategy_cadence : Types.Cadence.t` to the generic simulator `config` (backwards-compatible)
- Implement `Weinstein_strategy` in `analysis/weinstein/` satisfying the generic `STRATEGY` interface
- Add a Weinstein-specific parameter tuner with walk-forward validation

Read `trading/trading/simulation/lib/simulator.mli` and `README.md` before writing any code.

## Completed
—

## In Progress
—

## Next Steps
- Read docs/design/eng-design-4-simulation-tuning.md
- Read `trading/trading/simulation/lib/simulator.mli` and `README.md`
- Study existing `trading/trading/strategy/` modules
- Wait for portfolio-stops and screener → "Interface stable: YES"
- While waiting: draft Weinstein_strategy .mli and config types

## Inherited from data-layer
- `Synthetic_source`: implement `analysis/weinstein/data_source/lib/synthetic_source.ml` — deterministic programmatic bar generation (Trending, Basing, Breakout patterns) for stress testing and parameter tuning. Must satisfy `DATA_SOURCE` interface. Deferred here because it is only needed for simulation/tuning, not for live screener runs.

## Recent Commits
—
