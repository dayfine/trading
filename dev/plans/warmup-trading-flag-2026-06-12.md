# suppress_warmup_trading flag — 2026-06-12

## Context

PR #1549's A2 root-cause investigation found that the Weinstein strategy
**trades during the 210-day warmup window**. The simulator runs from
`warmup_start = start_date - warmup_days` (`Panel_runner._make_simulator`,
`sim_config.start_date = warmup_start`), so every backtest inherits a
portfolio that was built by warmup-window trading before its measurement
`start_date`. The 2009-06-26 fold's warmup spanned the GFC bottom →
portfolio depleted to ~35% of initial cash before measurement opened
(`Backtest.Fold_health` now detects these degenerate folds at the
reporting boundary, but does not prevent the trading).

The likely design intent is **warmup = indicators/data only, no trading**.
This PR adds a **default-off** flag that, when enabled, suppresses all new
position entries (long and short) before the measurement `start_date` while
indicators/data warm up normally. Default = current behaviour, byte-for-byte
no-op on every golden/snapshot/scenario test.

Per `.claude/rules/experiment-flag-discipline.md`: lands **default-off as a
no-op** (`suppress_warmup_trading : bool [@sexp.default false]`), becomes a
searchable `Variant_matrix` axis the day it lands, and is NOT wired into any
default config or preset until a ledger ACCEPT justifies it.

## Approach

The strategy emits `Position.transition`s from `on_market_close`. The only
transition that creates a *new* position is `CreateEntering` (it carries
`side : position_side`, covering both long and short). Every `transition`
carries `date : Date.t` (the simulated date). Suppressing warmup trading is
therefore: drop `CreateEntering` transitions whose `transition.date <
start_date`, leaving every other transition (exits, fills, risk-param
updates, stops) untouched.

The seam is the **strategy wrapper**. The production backtest path wraps the
strategy exactly once, in `Panel_runner._make_simulator` (which already has
`start_date` in scope), via `Strategy_wrapper.wrap`. We compose a second,
optional wrapper there driven by `config.suppress_warmup_trading` and
`start_date`.

1. **Config field** `suppress_warmup_trading : bool [@sexp.default false]` on
   `Weinstein_strategy.config` (`weinstein_strategy_config.{ml,mli}` +
   `weinstein_strategy.mli`), defaulted to `false` in `default_config`.
   `false` = current behaviour (warmup trading happens). This is the FLAG that
   makes it an axis (R2): `Overlay_validator.apply_overrides` resolves it via
   `config_of_sexp`, identical to `enable_short_side` / `enable_laggard_rotation`.

2. **Pure gate** — a micro-lib `Warmup_trade_gate` under
   `trading/trading/backtest/warmup_gate/lib/`:

   ```ocaml
   val filter_transitions :
     suppress:bool -> start_date:Date.t ->
     Position.transition list -> Position.transition list
   ```

   When `suppress = false` → identity (the no-op default). When `suppress =
   true` → drops `CreateEntering` transitions dated strictly before
   `start_date`; every non-`CreateEntering` transition and every
   `CreateEntering` dated on/after `start_date` passes through unchanged. Pure,
   `.mli`-documented, unit-tested.

3. **Wrapper** — `Warmup_trade_gate.wrap_strategy ~suppress ~start_date
   strategy` returns a `STRATEGY` module that runs the inner strategy then maps
   the output transitions through `filter_transitions`. When `suppress = false`
   the wrapper still delegates but returns the output unchanged (bit-identical).

4. **Wire** in `Panel_runner._make_simulator`: after `Strategy_wrapper.wrap`,
   apply `Warmup_trade_gate.wrap_strategy
   ~suppress:input.config.suppress_warmup_trading ~start_date`. With the default
   `false` the strategy module is behaviourally identical to today.

## Why a runner-side gate (not strategy-side)

The strategy only sees the simulation clock (which starts at `warmup_start`);
it does not know the measurement `start_date`. The runner knows both. Keeping
the gate in the runner means the strategy stays date-boundary-agnostic and the
gate is a thin, testable transition filter. The FLAG is still a real
`Weinstein_strategy.config` field (R2 satisfied) — the runner reads the flag
off the resolved config and supplies its own `start_date`.

## Suppression scope

- **New positions only.** `CreateEntering` (long + short) before `start_date`
  is dropped. With the flag on there will be no warmup-entered positions to
  exit later, so the warmup window opens the measurement window with a clean
  all-cash portfolio.
- **Exits / stops / fills are never suppressed.** `TriggerExit`,
  `TriggerPartialExit`, `UpdateRiskParams`, `EntryFill`, `EntryComplete`,
  `ExitFill`, `ExitComplete`, `CancelEntry` all pass through regardless of
  date. So even if a warmup-entered position somehow exists, its exit/stop
  handling is never broken.

## Files to change

- `trading/trading/weinstein/strategy/lib/weinstein_strategy_config.ml` — field + default.
- `trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli` — field + doc.
- `trading/trading/weinstein/strategy/lib/weinstein_strategy.mli` — field + doc on the public config type.
- `trading/trading/backtest/warmup_gate/lib/dune` — new micro-lib.
- `trading/trading/backtest/warmup_gate/lib/warmup_trade_gate.{ml,mli}` — gate + wrapper.
- `trading/trading/backtest/lib/dune` — depend on the micro-lib.
- `trading/trading/backtest/lib/panel_runner.ml` — wire the wrapper.
- `trading/trading/backtest/warmup_gate/test/{dune,test_warmup_trade_gate.ml}` — unit tests.
- `trading/trading/backtest/walk_forward/test/test_variant_matrix.ml` — axis test.
- `dev/status/backtest-infra.md` — dated status note.

## No-op-default argument

`suppress_warmup_trading` defaults to `false`. `Warmup_trade_gate.wrap_strategy`
with `suppress = false` (and `filter_transitions ~suppress:false`) is the
identity on the strategy's output — the same module behaviour, the same
transition list, byte-for-byte. Existing sexps that omit the field decode to
`false` via `[@sexp.default false]`. No golden / snapshot / scenario decodes or
replays differently. `Backtest.Fold_health` signatures fire exactly as before
(they observe terminal facts, which are unchanged with the flag off).

## Axis-ability note (R2)

`suppress_warmup_trading` is a top-level `bool` field with `[@sexp.default
false]`, so `Variant_matrix` resolves it by sexp name through `Overlay_validator`
with no overlay-validator change (identical mechanism to `enable_laggard_rotation`
/ `enable_short_side`). Axis test added:
`((flag suppress_warmup_trading) (values (true false)))` expands + validates.

## Tests

- `test_warmup_trade_gate.ml` (new):
  - `suppress=false` → identity (no-op default); list returned unchanged.
  - `suppress=true` → `CreateEntering` dated before `start_date` dropped.
  - `suppress=true` → `CreateEntering` dated on `start_date` retained (boundary
    is inclusive: `< start_date` drops, `>= start_date` keeps).
  - `suppress=true` → `CreateEntering` dated after `start_date` retained.
  - `suppress=true` → exit / fill / risk-param transitions dated in the warmup
    window are NEVER dropped.
  - `wrap_strategy` end-to-end: a stub strategy emitting a warmup-dated
    `CreateEntering` + a warmup-dated `TriggerExit` → wrapped strategy drops the
    entry, keeps the exit; with `suppress=false` keeps both.
- `test_variant_matrix.ml`: `suppress_warmup_trading` flag axis expands +
  validates.
- `dune build @fmt`, `dune build && dune runtest` exit 0; all goldens unchanged.

## Out of scope

- Quantifying how every baseline shifts with the flag ON (the comparison run is
  P0's analysis step, a separate experiment — not this code PR).
- Flipping the default to `true` (forbidden without a ledger ACCEPT + the
  promotion confirmation grid).
- Segregating inherited-position metrics (the "running start is intentional"
  alternative semantics) — orthogonal.
- Any change to `Backtest.Fold_health`, the simulator, or core modules.
