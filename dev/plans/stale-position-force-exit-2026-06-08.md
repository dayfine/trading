# Plan — stale/delisted position force-exit (default-off) — issue #1484

Date: 2026-06-08
Track: backtest-infra (simulation-correctness)
Branch: feat/backtest

## Problem

`Trading_simulation.Stale_hold` is a **detector only**: it records an event
when a held position's symbol stops emitting bars, but emits no exit. A
delisted/halted position is carried open indefinitely, marked at its last
available close, and counted in terminal NAV — inflating it (8 of 9 terminal
open positions in a top-3000 PIT 15y run were such zombies). See
`dev/notes/p0-verify-broad-universe-790-2026-06-08.md` §3.

## Goal

A **default-off** force-exit: when configured, a held position whose bar gap
≥ N is force-sold at its last available close as a **realized trade** — so it
lands in `trades.csv` / realized PnL and frees cash, instead of perpetuating
an open mark. Default-off ⇒ byte-identical to current behaviour
(`.claude/rules/experiment-flag-discipline.md` R1).

## Design

### Config plumbing

1. `Stale_hold.config` gains `stale_exit_after_days : int option`
   (`[@sexp.default None]`). `None` = current detector-only (no exit);
   `Some n` = force-exit once a held position's gap ≥ n. Keeps the simulator
   generic — it still just takes a `Stale_hold.config`.
2. `Weinstein_strategy.config` gains the same field
   `stale_exit_after_days : int option [@sexp.default None]` — the axis-able
   surface (flag-discipline R2). Routes through `config_overrides` /
   `Overlay_validator`.
3. `Backtest.Panel_runner._make_simulator` is the bridge: it already holds the
   resolved `input.config` (a `Weinstein_strategy.config`) and constructs
   `Simulator.create_deps`. Build the `Stale_hold.config` from the strategy
   config's `stale_exit_after_days` (carry `enabled`/`stale_after_days`
   defaults) and pass `~stale_hold_policy`.

### Force-exit logic (simulator)

In `_prepare_market_state` (where `detect_stale` is already called), after the
detector pass, when `config.stale_exit_after_days = Some n`, for each held
position with bar gap ≥ n:

- Build a synthetic market-sell (long) / market-buy (short) trade for the full
  position quantity at the last available close.
- Apply it to the portfolio (`apply_single_trade`) → realized PnL, freed cash.
- Drive the strategy `Position.t` Holding → Exiting → Closed via
  `TriggerExit` + `ExitFill` + `ExitComplete` transitions
  (`StrategySignal { label = "stale_force_exit"; ... }`), then drop the closed
  position from the positions map (same `_set_or_drop_if_closed` convention).
- Thread the resulting trades out of `_prepare_market_state` so they are merged
  into the step's `trades` list (→ `trades.csv`).

Why not route a `TriggerExit` through the normal order machinery (like
`Margin_runner`)? The symbol has **no bar today** — the engine can't fill an
order against absent market data, so the position would never close. The
realized-trade path applies the exit directly at the last close.

The candidate selection (which held positions to force-exit, the last close,
the signed quantity) is a pure helper `Stale_hold.force_exit_candidates`. The
trade construction + portfolio/position mutation are extracted into a new
strategy-agnostic `Stale_exit_runner` module (mirroring `Margin_runner`) so
`simulator.ml` stays under the 500-line hard limit; `_prepare_market_state`
calls `Stale_exit_runner.tick` and threads its trades into the step.

### Default-off invariant

With the field `None` everywhere, the new branch is never entered → byte-
identical to current behaviour. Verified by goldens + the existing
`test_stale_hold` detector tests staying green.

## Tests (TDD, write first)

- `test_stale_hold.ml`: `force_exit_candidates` returns the long position at
  its last close when `Some 5` and gap ≥ 5; returns `[]` when `None`.
- `test_simulator.ml` (or focused new test): end-to-end —
  - Delisted symbol, held, `stale_exit_after_days = Some 5`: exactly one
    realized exit trade at the last close ~5 bar-days after the last bar;
    position flat thereafter; freed cash available.
  - `stale_exit_after_days = None`: no exit trade; position stays open marked
    at last close (current behaviour).
  - Exit PnL realized = (last_close − avg_cost) × qty.

## Files

- `trading/trading/simulation/lib/stale_hold.{ml,mli}` — config field +
  `force_exit_candidates` pure helper.
- `trading/trading/simulation/lib/stale_exit_runner.{ml,mli}` (new) — the
  force-exit application (trade construction + portfolio/position mutation),
  extracted to keep `simulator.ml` under the 500-line hard limit.
- `trading/trading/simulation/lib/simulator.ml` — calls `Stale_exit_runner.tick`
  in `_prepare_market_state`; threads the trades into the step.
- `trading/trading/simulation/lib/dune` — register `stale_exit_runner`.
- `trading/trading/weinstein/strategy/lib/weinstein_strategy_config.{ml,mli}`
  + `weinstein_strategy.mli` — the `stale_exit_after_days` axis field.
- `trading/trading/backtest/lib/panel_runner.ml` — bridge.
- `trading/trading/simulation/test/test_stale_hold.ml`
  + `test_simulator.ml` — TDD tests.
