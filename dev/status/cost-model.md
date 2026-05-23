# Status: cost-model

## Last updated: 2026-05-23

## Status
READY_FOR_REVIEW

Canonical scenario-facing cost-overlay configuration module. Listed
as the next-after-M5.5 priority in
`memory/project_m5-5-tuning-exhausted.md`.

## Interface stable

YES

### Surface

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

- [x] **Cost-model module** (PR #1151, 2026-05-17). Module +
  test (27 cases, all green). ~85 LOC impl, ~130 LOC mli, ~290 LOC
  test. Wired into nothing — standalone, callers can opt in. Verify:
  `dune runtest trading/backtest/cost_model` (27/27 pass).
- [x] **Wire `cost_model` sexp field into `scenario.mli`** (PR
  pending, 2026-05-23 — feat/cost-model-wiring-phase1). Added
  `cost_model : Cost_model.t option` with `[@sexp.option]` so every
  existing scenario file omits the field and continues to parse
  with `None`. Threaded through `scenario_runner` →
  `Runner.run_backtest` → `Panel_runner.run`. Verify: `dune runtest
  trading/backtest/scenarios/test/test_scenario` (15/15 pass
  including 3 new cost_model round-trip cases).
- [x] **Wire `apply_per_trade_commission` into the simulator's
  post-fill hook** (PR pending, 2026-05-23 — same PR). Added
  strategy-agnostic `?on_trade_fill : (trade -> trade)` optional
  dep on `Simulator.create_deps` (default `None` → byte-equal
  baseline). `Panel_runner.run` constructs the hook from
  `Cost_model.apply_per_trade_commission` when `?cost_model` is
  supplied. Architectural note: simulator does NOT depend on
  `Backtest_cost_model` (avoids inverting the layering — backtest
  already depends on simulation); the cost-model module lives one
  layer up and the hook surface keeps simulator generic. Verify:
  `dune runtest trading/simulation/test/test_simulator_cost_model`
  (3/3 pass — None preserves baseline, retail_default per_trade=0
  preserves baseline, custom per_trade=$1.50 subtracts exact
  delta). No goldens needed re-pinning since every existing
  scenario file has `cost_model = None`.

## Open work

- [ ] **Wire market-impact into the engine** — requires ADV
  plumbing. ADV needs to be loaded alongside bars; not yet in the
  simulation data layer. Defer until empirical evidence shows
  impact dominates over spread for realistic order sizes.
- [ ] **Re-pin Cell E baseline with retail/institutional cost
  overlay** — once items 1+2 above land, run Cell E (15y SP500)
  with `cost_model = Some retail_default` and `Some
  institutional_default` to quantify the cost attrition curve
  beyond bid-ask-spread. The `slippage_bps` knob (PR #920) already
  approximates the spread component.

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
