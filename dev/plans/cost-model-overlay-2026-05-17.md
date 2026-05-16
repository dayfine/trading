# Cost-model overlay — 2026-05-17

## Why

Cell E baseline (~341.69% / 0.78 Sharpe on 15y per
`memory/project_sp500_baseline_conflict.md`) was measured frictionless.
Real costs (commission + slippage + bid-ask spread + market impact) will
reduce realized returns. Listed as the next-after-M5.5 priority in
`memory/project_m5-5-tuning-exhausted.md`.

## State of cost knobs today

The engine already exposes two cost knobs (`trading/trading/engine/lib/types.mli`):

1. **`commission_config { per_share : float; minimum : float }`** — wired
   through `Simulator.create_deps ~commission` and applied via
   `Engine._calculate_commission`: `max(per_share * qty, minimum)`.
2. **`slippage_bps : int`** — one-side bps applied symmetrically at fill
   price via `Engine._apply_slippage_to_fill` (PR #920). Plumbed into
   scenarios as `slippage_bps : int option`.

These cover **per-share commission** and **bid-ask spread** from the task
spec. Missing knobs:

- **`per_trade_commission`** — flat dollars per trade independent of share
  count.
- **`market_impact_bps_per_pct_adv`** — impact bps that scale with order
  size as a fraction of average daily volume.

## Decision: build `cost_model` as a scenario-facing canonical record

Rather than touch `engine/types.mli` (would force every engine_config
caller to change) or build a parallel engine, we add a new
`Cost_model` module under `trading/trading/backtest/cost_model/lib/`
that:

1. Defines a single canonical `Cost_model.t` config record (the four
   knobs from the task spec, as `float`s).
2. Provides `to_engine_costs : t -> (commission_config * int)` to convert
   into the existing engine wiring. Bid-ask-bps float is rounded to int
   for engine consumption (engine API is `int`; preserve byte-equal
   baseline for zero-cost defaults).
3. Provides `apply_per_trade_commission : t -> trade -> trade` — a
   post-fill `Trade.t` adjustment hook that adds the flat per-trade
   commission to `trade.commission`. This is the cleanest Trade-record
   adjustment layer: it does not require engine changes and is easily
   composable.
4. Provides `market_impact_bps : t -> adv_pct:float -> float` — a pure
   function returning the impact bps for an order of `adv_pct` percent of
   average daily volume. Currently not auto-applied (ADV is not plumbed
   into the engine yet); shipped pure + tested so we can wire it later
   from an analysis script or a future engine extension without
   reshaping the API. Documenting this as deferred wiring is explicit
   in the .mli.
5. `zero : t` — back-compat default for scenarios that omit cost_model.

### Integration point

- `Cost_model.t` lives independently in `trading/trading/backtest/cost_model/lib/`.
- Wiring into the simulator happens via `to_engine_costs` at the call
  site (caller passes the result into `Simulator.create_deps
  ~commission ~slippage_bps`).
- Per-trade flat commission is applied as a post-fill `Trade.t`
  rewrite by passing the simulator's emitted trades through
  `Cost_model.apply_per_trade_commission` — but for **this PR** we ship
  the module standalone (not yet wired into runner.ml). Wiring into
  one canonical scenario sexp is a one-line change in `scenario.mli`
  to add the optional `cost_model` field; we do that minimally so
  scenarios CAN reference it without breaking back-compat.

This keeps the PR clean and the cost model isolated and testable.
Re-pinning baselines under cost overlay is **explicitly out of scope**
per the task brief.

## Files to touch

New:
- `trading/trading/backtest/cost_model/lib/cost_model.ml` (~120 LOC)
- `trading/trading/backtest/cost_model/lib/cost_model.mli` (~90 LOC)
- `trading/trading/backtest/cost_model/lib/dune` (~6 LOC)
- `trading/trading/backtest/cost_model/test/test_cost_model.ml` (~150 LOC)
- `trading/trading/backtest/cost_model/test/dune` (~8 LOC)

No changes to engine, simulator, portfolio, or strategy code.
Scenarios with cost_model integration land in a follow-up PR (one
scenario at a time, deliberate baseline-re-pin work).

## Test plan

Covers:
1. Zero-cost default — every output is identity / zero.
2. Per-share commission only — engine_costs.per_share is correctly
   forwarded.
3. Per-trade flat commission — adds correct delta to `trade.commission`
   regardless of share count.
4. Bid-ask spread bps → engine slippage_bps int (round-trip + truncation).
5. Market impact — linear scaling with adv_pct; zero when coef is zero.
6. Combined retail-default and institutional-default round-trips.
7. Negative parameters rejected via `validate`.
