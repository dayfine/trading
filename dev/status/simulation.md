# Status: simulation

## Last updated: 2026-04-07

## Status
IN_PROGRESS

## Interface stable
YES

## Blocked on
- None

## Existing infrastructure — DO NOT reimplement
`trading/trading/simulation/` is a **generic** framework shared across all strategies (not Weinstein-specific). Phases 1–3 are complete and tested:
- **Phase 1** (core types): `config`, `step_result`, `step_outcome`, `run_result` in `lib/types/simulator_types.ml`
- **Phase 2** (OHLC price path): intraday path generation, order fill detection for all order types
- **Phase 3** (daily loop): `step` and `run` implemented; engine + order manager + portfolio wired up
- The simulator already takes a `(module STRATEGY)` in its `dependencies` record

The Weinstein work in eng-design-4 adds Weinstein-specific components **on top** without breaking general use.

## Completed

- `strategy_cadence` added to simulator config — Weekly/Daily gate (#195)
- `Weinstein_strategy` — full `STRATEGY` impl, daily stop cadence, Friday-gated screening (#196, merged 2026-04-07)
  - Stop updates: daily (adjusts trailing stops as MA moves)
  - Macro analysis + screening: Fridays only (Weinstein weekly review cadence)
  - `_update_stops`, `_screen_universe`, `_make_entry_transition` wired to all analysis modules

## In Progress
- None

## Blocking Refactors
- None

## Follow-up

- `_collect_bars` returns only the current bar (1 bar) — full history requires `Historical_source` wired into the simulation loop (Slice 2)
- `portfolio_value = 0.0` placeholder in `_entries_from_candidates` — needs real cash from simulator snapshot
- `ma_direction = Flat` placeholder in `_handle_stop` — needs computed MA slope from full bar history
- `Date.today` in `_make_entry_transition` — should use the simulation date from the current bar

## Known gaps

- `Synthetic_source` not yet implemented — needed for deterministic simulation tests and parameter tuning
- No end-to-end simulation integration test — no script/test that runs `Simulator.run` with `Weinstein_strategy` on real or synthetic data
- `T2-B` performance gate test deferred to M5

## Next Steps

1. Implement `Synthetic_source` (`analysis/weinstein/data_source/lib/synthetic_source.ml`) — deterministic bar generation for Trending/Basing/Breakout patterns; satisfies `DATA_SOURCE` interface
2. Write end-to-end simulation smoke test using `Synthetic_source` — run `Simulator.run` with `Weinstein_strategy` on a known breakout scenario
3. Wire `Historical_source` into simulation loop to replace `_collect_bars` 1-bar placeholder (Slice 2)

## Recent Commits

- #195 simulation: Add strategy_cadence to simulator dependencies
- #196 simulation: Weinstein strategy skeleton (STRATEGY impl) — merged 2026-04-07
