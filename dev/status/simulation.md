# Status: simulation

## Last updated: 2026-04-07

## Status
READY_FOR_REVIEW

## QC
overall_qc: APPROVED
structural_qc: APPROVED (2026-04-07)
behavioral_qc: APPROVED (2026-04-07)
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
- End-to-end smoke test — `Simulator.run` with `Weinstein_strategy` on CSV data in temp dir; 2 tests covering smoke + date range (feat/simulation branch)

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

- `T2-B` performance gate test deferred to M5

## Next Steps

### Slice 2: wire real bar history into the strategy (4 coordinated changes)

**1. Bar accumulation — replace `_collect_bars` 1-bar placeholder**

Accumulate daily bars per-symbol in the `make` closure (same pattern as `stop_states`):

```ocaml
(* in make *)
let bar_history : Types.Daily_price.t list String.Table.t = String.Table.create () in
```

On each `on_market_close` call, append the current bar (from `get_price`) to the per-symbol buffer. When the strategy needs bars for stage/RS/volume analysis, use the full buffer instead of `_collect_bars`. Convert daily bars to weekly via `Time_period.Conversion.daily_to_weekly` (already used in `time_series.ml`). Aggregate on Fridays (or when producing weekly output).

**2. `portfolio_value` — replace `0.0` placeholder in `_entries_from_candidates`**

Add an optional labeled parameter to `on_market_close`:
```ocaml
val on_market_close :
  get_price:get_price_fn ->
  get_indicator:get_indicator_fn ->
  positions:Position.t String.Map.t ->
  ?portfolio_value:float ->
  output Status.status_or
```
This is truly optional — existing strategies (`ema_strategy`, `buy_and_hold_strategy`) ignore it with `?portfolio_value:_` in their implementation. The simulator passes it from `portfolio.current_cash` (already available in `step`). Weinstein uses it for position sizing in `_entries_from_candidates`.

**3. `ma_direction` — replace `Flat` placeholder in `_handle_stop`**

Use the per-symbol bar buffer (from change 1) to compute MA slope via the existing `Stage.classify` function, which already returns `ma_slope`. Extract direction from its result.

**4. Simulation date — replace `Date.today` in `_make_entry_transition`**

The current bar's date is available from `get_price`. Pass it through from the bar to `_make_entry_transition`.

**Smoke test extension (after all 4 changes)**

- Extend `hist_start` to `2022-01-01` so the bar buffer is large enough for stage classification
- Add assertions: trades were made, open AAPL position exists, realized PnL ≥ 0, unrealized PnL > 0

## Recent Commits

- #195 simulation: Add strategy_cadence to simulator dependencies
- #196 simulation: Weinstein strategy skeleton (STRATEGY impl) — merged 2026-04-07
- feat/simulation: Add Synthetic_source and Weinstein strategy smoke tests (pending PR)
