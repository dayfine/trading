# Status: cost-model

## Last updated: 2026-05-17

## Status
READY_FOR_REVIEW

Canonical scenario-facing cost-overlay configuration module. Listed
as the next-after-M5.5 priority in
`memory/project_m5-5-tuning-exhausted.md`.

## Interface stable

`Backtest_cost_model.Cost_model` (`trading/trading/backtest/cost_model/lib/`):
- `type t = { per_trade_commission; per_share_commission;
  bid_ask_spread_bps; market_impact_bps_per_pct_adv }` — four
  independent non-negative `float` knobs.
- `zero : t` — frictionless baseline.
- `retail_default : t` — $0/trade, $0/share, 5 bps, no impact.
- `institutional_default : t` — $0/trade, $0.005/share, 2 bps, 1 bps
  per 1% ADV.
- `validate : t -> (unit, Status.t) result` — rejects negative or
  non-finite values.
- `to_engine_costs : t -> commission_config * int` — converts to the
  engine's existing wiring. Spread bps rounds to int.
- `apply_per_trade_commission : t -> trade -> trade` — post-fill
  Trade-record adjustment that adds the flat per-trade commission.
- `market_impact_bps : t -> adv_pct:float -> float` — pure linear
  impact bps function.
- `apply_market_impact : t -> adv_pct -> side -> fill_price -> float`
  — symmetric one-side impact-adjusted fill price.

## Completed

- [x] **Cost-model module** (PR pending, 2026-05-17). Module +
  test (27 cases, all green). ~85 LOC impl, ~130 LOC mli, ~290 LOC
  test. Wired into nothing — standalone, callers can opt in. Verify:
  `dune runtest trading/backtest/cost_model` (27/27 pass).

## Open work

- [ ] **Wire `cost_model` sexp field into `scenario.mli`** — add
  `cost_model : Cost_model.t option` so scenarios can declare costs
  declaratively. Lifts the existing `slippage_bps : int option`
  into the broader config. Defer until at least one scenario needs
  per-trade or impact, since `slippage_bps` already covers the
  bid-ask-spread case.
- [ ] **Wire `apply_per_trade_commission` into the simulator's
  post-fill hook** — currently a standalone helper. Likely the
  cleanest place is `Simulator._apply_trades_best_effort` (map
  trades through the adjustment before applying to portfolio).
  Trade-off: when this lands, every scenario re-pin is needed.
- [ ] **Wire market-impact into the engine** — requires ADV
  plumbing. ADV needs to be loaded alongside bars; not yet in the
  simulation data layer. Defer until empirical evidence shows
  impact dominates over spread for realistic order sizes.

## Follow-up experiments

- Sweep `bid_ask_spread_bps` from 0 to 50 bps and pin returns / Sharpe
  attrition curve for Cell E (15y SP500). Already partly probed by
  the existing `slippage_bps` knob (PR #920); this would extend to
  more bps levels with the cost_model harness.
- Once per-trade commission is wired, sweep $0 / $0.50 / $1 / $5 per
  trade. Strategies that trade more frequently will suffer
  disproportionately — a useful signal for sizing dynamics work.

## Notes

- The pre-existing `Trading_engine.Types.engine_config` already
  exposes `per_share` commission + `slippage_bps`. The cost_model
  module is intentionally **additive**: it does not reshape engine
  types; it converts into them. This preserves byte-equal baselines
  for any scenario that opts out by passing `Cost_model.zero`.
- Negative `adv_pct` is clamped to zero in `market_impact_bps` to
  prevent sell-side orders against thin tape from producing a
  negative-impact "bonus" (artefact of linear extrapolation).
- The engine's `commission_config.minimum` floor is intentionally NOT
  exposed by `Cost_model.t`. It's a different concept from a flat
  per-trade fee (per-share calculations with a floor vs flat per
  trade). If a future scenario needs it, route through engine config
  directly.
