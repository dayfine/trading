# Plan: Stage 4 PR-A — drop `Daily_price.t list` intermediates at strategy call sites (2026-04-26)

## Status

In-flight. Branch: `feat/panels-stage04-pr-a-callback-wiring`.

## The wedge

Per `dev/notes/panels-rss-spike-2026-04-25.md`, post-Stage-3 PR 3.2 panel
mode peaks at 3.47 GB on `bull-crash-292x6y` vs the projected <800 MB.
The plan-attributed cause: every reader site reconstructs
`Daily_price.t list` from the panel on every tick. Stage 2 PRs B–H
reshaped callee internals to take callbacks, but the wrappers still
build `Daily_price.t list` via `callbacks_from_bars`.

## Goal of this PR

Switch the strategy call sites from `*.analyze ~bars:...` to
`*.analyze_with_callbacks ~callbacks:...`, where the callback bundles
read panel cells directly without ever materializing `Daily_price.t
list`.

Affected call sites:

| File | Current | Switch to |
|---|---|---|
| `macro_inputs.ml` `build_global_index_bars` | `Bar_reader.weekly_bars_for` | weekly_view per global index symbol |
| `macro_inputs.ml` `_sector_context_for` | `Sector.analyze ~sector_bars` | `Sector.analyze_with_callbacks` w/ panel callbacks |
| `stops_runner.ml` `_compute_ma` | `Stage.classify ~bars:weekly` | `Stage.classify_with_callbacks` w/ panel callbacks |
| `weinstein_strategy.ml` `_make_entry_transition` | `Weinstein_stops.compute_initial_stop_with_floor ~bars` | `_with_callbacks` w/ panel callbacks |
| `weinstein_strategy.ml` `_screen_universe` | `Stock_analysis.analyze ~bars` | `_with_callbacks` w/ panel callbacks |
| `weinstein_strategy.ml` `_run_screen` | `Macro.analyze ~index_bars` | `_with_callbacks` w/ panel callbacks |
| `weinstein_strategy.ml` `_on_market_close` | `Bar_reader.weekly_bars_for` (Friday detection) | `Bar_panels.column_of_date` + last-bar date directly |

## Approach

### New primitives in `data_panel/`

Add `Bar_panels.weekly_view_for` and `Bar_panels.daily_view_for` that
produce float-array views over panel cells without materializing
`Daily_price.t list`:

```ocaml
type weekly_view = {
  closes : float array;       (* adjusted_close per weekly bar *)
  highs : float array;
  lows : float array;
  volumes : float array;
  dates : Core.Date.t array;
  n : int;
}

type daily_view = {
  highs : float array;
  lows : float array;
  closes : float array;
  dates : Core.Date.t array;
  n_days : int;
}

val weekly_view_for : t -> symbol:string -> n:int -> as_of_day:int -> weekly_view
val daily_view_for : t -> symbol:string -> as_of_day:int -> lookback:int -> daily_view
```

### New module `Weinstein_panel_callbacks` (strategy/lib/)

Converts panel views into callback bundles for each callee:

```ocaml
val stage_callbacks_of_weekly_view :
  weekly:Bar_panels.weekly_view -> config:Stage.config -> Stage.callbacks

val rs_callbacks_of_weekly_views :
  stock:Bar_panels.weekly_view -> benchmark:Bar_panels.weekly_view -> Rs.callbacks

val stock_analysis_callbacks_of_weekly_views :
  stock:Bar_panels.weekly_view -> benchmark:Bar_panels.weekly_view ->
  config:Stock_analysis.config -> Stock_analysis.callbacks

val sector_callbacks_of_weekly_views :
  sector:Bar_panels.weekly_view -> benchmark:Bar_panels.weekly_view ->
  config:Sector.config -> Sector.callbacks

val macro_callbacks_of_weekly_views :
  index:Bar_panels.weekly_view ->
  globals:(string * Bar_panels.weekly_view) list ->
  ad_bars:Macro.ad_bar list ->
  config:Macro.config ->
  Macro.callbacks

val support_floor_callbacks_of_daily_view :
  Bar_panels.daily_view -> Weinstein_stops.callbacks
```

These build float-array-backed callbacks. The Stage MA still needs
computing — done once on the `closes` array via the existing
`Sma.calculate_*` (cheap, ~100 floats per call). Stage callbacks
return a closure indexing the resulting MA float array.

### Volume / Resistance still need bar lists

`Stock_analysis.analyze_with_callbacks` carries
`bars_for_volume_resistance : Daily_price.t list` because Volume +
Resistance haven't been reshaped yet. Preserved for PR-A; PR-B
reshapes those callees.

## Parity gates

1. `test_panel_loader_parity` round_trips golden — bit-equal trades
   (load-bearing).
2. New parity tests in `test_panel_callbacks.ml`: for each callee,
   build `callbacks_from_bars` (existing) AND
   `*_callbacks_of_weekly_view` (new) on the same input data. Assert
   the resulting `result` is bit-identical.

## LOC budget

~500 LOC target, ~700 max.

## Out of scope (PR-B/C/D)

- Volume + Resistance reshape (drops `bars_for_volume_resistance`)
- `Ohlcv_weekly_panels` + Friday rollup
- Port stage classifier / volume / resistance to indicator kernels
