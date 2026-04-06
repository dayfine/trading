# Status: simulation

## Last updated: 2026-04-06

## Status
IN_PROGRESS

## Interface stable
NO

## Blocked on
- data-layer: MERGED (unblocked)
- portfolio-stops: MERGED (unblocked)
- screener: MERGED (unblocked)

## Existing infrastructure — DO NOT reimplement
`trading/trading/simulation/` is a **generic** framework shared across all strategies (not Weinstein-specific). Phases 1–3 are complete and tested:
- **Phase 1** (core types): `config`, `step_result`, `step_outcome`, `run_result` in `lib/types/simulator_types.ml`
- **Phase 2** (OHLC price path): intraday path generation, order fill detection for all order types
- **Phase 3** (daily loop): `step` and `run` implemented; engine + order manager + portfolio wired up
- The simulator already takes a `(module STRATEGY)` in its `dependencies` record

The Weinstein work in eng-design-4 adds Weinstein-specific components **on top** without breaking general use:
- Add `strategy_cadence : Types.Cadence.t` to the generic simulator `dependencies` (backwards-compatible, done)
- Implement `Weinstein_strategy` in `trading/weinstein/strategy/` satisfying the generic `STRATEGY` interface (done)
- Add a Weinstein-specific parameter tuner with walk-forward validation (M5-gated, not started)

## Completed
- `strategy_cadence`: Added `strategy_cadence : Types.Cadence.t` to `simulator.dependencies`, optional `?strategy_cadence` param on `create_deps`. Test: weekly cadence calls strategy only on Fridays (2 calls over Jan 8-19 2024). Branch: feat/simulation
- `Weinstein_strategy`: `trading/trading/weinstein/strategy/` — config type, `default_config`, `make` returning `(module STRATEGY)`. Handles stop updates, macro analysis, stock screening, entry generation. 5 tests. Branch: feat/simulation

## In Progress
- None (next: synthetic_source for simulation testing)

## Next Steps
1. `Synthetic_source` (`analysis/weinstein/data_source/lib/synthetic_source.ml`): deterministic programmatic bar generation (Trending, Basing, Breakout patterns) for simulation stress testing. Must satisfy `DATA_SOURCE` interface.
2. Integration test: run `Weinstein_strategy` through simulator with synthetic data, verify full weekly loop.
3. Parameter tuner with walk-forward validation (M5-gated — defer until basic simulation works end-to-end).

## Inherited from data-layer
- `Synthetic_source`: implement `analysis/weinstein/data_source/lib/synthetic_source.ml` — deterministic programmatic bar generation (Trending, Basing, Breakout patterns) for stress testing and parameter tuning. Must satisfy `DATA_SOURCE` interface. Deferred here because it is only needed for simulation/tuning, not for live screener runs.

## Follow-up
- None

## Recent Commits
- feat/simulation: simulation — Add strategy_cadence to dependencies and Weinstein strategy module (6 tests)
