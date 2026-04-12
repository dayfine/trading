# Status: simulation

## Last updated: 2026-04-12

## Status
MERGED

## QC
overall_qc: APPROVED (Slice 1 + Slice 3)
structural_qc: APPROVED (Slice 1: 2026-04-07, Slice 3: 2026-04-10)
behavioral_qc: APPROVED (Slice 1: 2026-04-07, Slice 3: 2026-04-10)
See dev/reviews/simulation.md.

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

- **`Portfolio_view.t` on STRATEGY interface** — replaced `~positions:Position.t String.Map.t` with `~portfolio:Portfolio_view.t` containing `{ cash; positions }`. Simulator constructs it from `Portfolio.current_cash` + position map. Weinstein strategy derives portfolio value via `Portfolio_view.portfolio_value` for position sizing. 3 tests for the utility module.
- **Bar accumulation** — per-symbol daily bar buffer (`Hashtbl<string, Daily_price.t list>`) in `make` closure. Accumulated idempotently on each `on_market_close` call. Converted to weekly via `Time_period.Conversion.daily_to_weekly` for stage/macro/screening analysis. Replaces `_collect_bars` placeholder.
- **MA direction** — computed from `Stage.classify` on the weekly bar buffer instead of hardcoded `Flat`. Falls back to `Flat` when insufficient bars (< ma_period).
- **Simulation date** — `_make_entry_transition` uses current bar's date instead of `Date.today`.
- **Smoke test extended** — `hist_start` moved to 2022-01-01 (100+ weekly bars warmup). Added `portfolio_value > 0` assertion.

### Slice 3 (2026-04-10) — merged (#246)

- **Prior stage accumulation** — per-symbol `prior_stages` Hashtbl in the `make` closure. `Stage.classify` and `Stock_analysis.analyze` now receive accumulated prior stage instead of `None`. Enables accurate Stage1→Stage2 transition detection in `is_breakout_candidate`.
- **Index prior stage** — `Macro.analyze` receives accumulated index prior stage instead of `None`.
- **Breakout smoke test** — new test using `Breakout` synthetic pattern (40 weeks basing, 8x breakout volume, 1-year sim from data start). Asserts: orders submitted, trades executed, positive portfolio value. Full screener→order→trade pipeline verified end-to-end.

All slices merged: Slice 1 (#196), Slice 2 (#237, #240, #241, #242), Slice 3 (#246).

## In Progress
- M5 (walk-forward backtest, parameter tuner) is next

## Blocking Refactors
- None

## Follow-up

- Volume dilution in weekly aggregation: a single high-volume daily breakout bar gets averaged with 4 normal-volume bars in the weekly sum, requiring unrealistically high `breakout_volume_mult` (8x daily) to achieve 2x weekly ratio. Consider enhancing `Synthetic_source.Breakout` to apply volume spike across multiple days of the breakout week.
- Test does not yet assert on specific position symbols (AAPL open position) or PnL direction — trades are confirmed but position-level assertions deferred.

## Known gaps

- `T2-B` performance gate test deferred to M5
- Trade assertions deferred to Slice 3 (see Follow-up)

## Next Steps

### QC review for Slice 2+3

Both Slice 2 (merged PRs #237, #240, #241, #242) and Slice 3 (feat/simulation branch) need fresh QC review.

### Future slices

- Position-level assertions: verify AAPL open position, PnL direction
- Walk-forward backtest (M5): parameter tuner with validation period
- Performance gate test (T2-B)

## Recent Commits

- #195 simulation: Add strategy_cadence to simulator dependencies
- #196 simulation: Weinstein strategy skeleton (STRATEGY impl) — merged 2026-04-07
- feat/simulation: Add Synthetic_source and Weinstein strategy smoke tests (pending PR)
- feat/simulation: add ?portfolio_value optional param to STRATEGY interface (2026-04-09)
- feat/simulation: bar accumulation, MA direction, and simulation date (2026-04-09)
- feat/simulation: extend smoke tests with 2022-01-01 history start (2026-04-09)
- feat/simulation: accumulate prior_stage per symbol for Stage1->Stage2 detection (2026-04-10)
- feat/simulation: add breakout pattern smoke test with trade assertions (2026-04-10)
