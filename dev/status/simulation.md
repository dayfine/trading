# Status: simulation

## Last updated: 2026-04-09

## Status
READY_FOR_REVIEW

## QC
overall_qc: APPROVED (Slice 1)
structural_qc: APPROVED (2026-04-07)
behavioral_qc: APPROVED (2026-04-07)
See dev/reviews/simulation.md.

Note: Slice 2 changes need fresh QC review.

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
- `Synthetic_source` — deterministic `DATA_SOURCE` impl for testing; 4 bar patterns: Trending/Basing/Breakout/Declining; 8 tests (feat/simulation branch)
- End-to-end smoke test — `Simulator.run` with `Weinstein_strategy` on CSV data in temp dir; 3 tests covering smoke + date range + weekly cadence

### Slice 2 (2026-04-09)

- **`?portfolio_value` on STRATEGY interface** — added as truly optional param on `on_market_close`. Existing strategies (EMA, BuyAndHold) ignore it. Simulator passes it from `_compute_portfolio_value`. Weinstein threads it to `_entries_from_candidates` for position sizing. All callers (14 files) updated.
- **Bar accumulation** — per-symbol daily bar buffer (`Hashtbl<string, Daily_price.t list>`) in `make` closure. Accumulated idempotently on each `on_market_close` call. Converted to weekly via `Time_period.Conversion.daily_to_weekly` for stage/macro/screening analysis. Replaces `_collect_bars` placeholder.
- **MA direction** — computed from `Stage.classify` on the weekly bar buffer instead of hardcoded `Flat`. Falls back to `Flat` when insufficient bars (< ma_period).
- **Simulation date** — `_make_entry_transition` uses current bar's date instead of `Date.today`.
- **Smoke test extended** — `hist_start` moved to 2022-01-01 (100+ weekly bars warmup). Added `portfolio_value > 0` assertion.

## In Progress
- None

## Blocking Refactors
- None

## Follow-up

- Trade assertions (trades made, open position, realized/unrealized PnL) deferred to Slice 3: the screener cascade's `is_breakout_candidate` gate requires a `Breakout` pattern with carefully timed parameters (early Stage 2, `weeks_advancing <= 4`) that the current `Trending` pattern does not produce. Need screener-aware synthetic test data.
- `prior_stage` is passed as `None` to `Stock_analysis.analyze` — accumulating prior stage results per symbol would improve screener accuracy (allows detecting Stage 1 -> Stage 2 transitions).

## Known gaps

- `T2-B` performance gate test deferred to M5
- Trade assertions deferred to Slice 3 (see Follow-up)

## Next Steps

### Slice 3: screener-aware test data for trade assertions

Design synthetic data patterns that pass the full screener cascade:

1. Use `Breakout` pattern with `base_weeks` timed so the breakout happens 1-3 weeks before the first screening Friday. This gives `weeks_advancing <= 4` in `is_breakout_candidate`.

2. Accumulate `prior_stage` per symbol in the `make` closure (same pattern as `stop_states` / `bar_history`). Pass it to `Stock_analysis.analyze` instead of `None`. This enables the `Stage1 -> Stage2` transition path in `is_breakout_candidate`.

3. With both changes, the smoke test should produce trades. Add assertions:
   - At least one trade was made across all steps
   - Final portfolio has an open AAPL position
   - Total realized PnL >= 0
   - Total unrealized PnL > 0

## Recent Commits

- #195 simulation: Add strategy_cadence to simulator dependencies
- #196 simulation: Weinstein strategy skeleton (STRATEGY impl) — merged 2026-04-07
- feat/simulation: Add Synthetic_source and Weinstein strategy smoke tests (pending PR)
- feat/simulation: add ?portfolio_value optional param to STRATEGY interface (2026-04-09)
- feat/simulation: bar accumulation, MA direction, and simulation date (2026-04-09)
- feat/simulation: extend smoke tests with 2022-01-01 history start (2026-04-09)
