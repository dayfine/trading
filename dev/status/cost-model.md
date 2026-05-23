# Status: cost-model

## Last updated: 2026-05-23 (run-2 reconcile — full wiring landed)

## Status
MERGED

End-to-end cost-overlay wiring landed 2026-05-23: #1260 (scenario
field + simulator `on_trade_fill` hook) → #1273 (`retail_default`
golden annotations on 7 Weinstein scenarios) → #1276
(`to_engine_costs` Panel_runner wiring; `engine_costs_with_overlay`
helper exposed for tests) → #1277 (walk-forward `cost_model`
inheritance fix-forward for the `walk_forward_runner.ml:23` follow-up
surfaced on #1260). Item 3 (ADV plumbing for `apply_market_impact`)
DEFERRED by design — wait for empirical evidence impact ≫ spread
before adding the ADV data-layer plumbing. Canonical scenario-facing
cost-overlay configuration module per
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
- [x] **Apply `cost_model = Some retail_default` to canonical
  Weinstein-strategy goldens** (PR pending, 2026-05-23 —
  feat/cost-model-overlay-repin). Declarative overlay added to 7
  goldens: `goldens-small/{bull-crash-2015-2020, six-year-2018-2023,
  covid-recovery-2020-2024}`, `goldens-sp500/{sp500-2019-2023,
  sp500-2019-2023-long-only}`,
  `goldens-sp500-historical/{sp500-2010-2026, sp500-2010-2026-longshort}`.
  BAH-benchmark scenarios excluded (passive references, not
  Weinstein comparators). Byte-equal to prior baseline because
  `retail_default.per_trade_commission = 0.0` and only that knob is
  currently wired — pinned metric ranges preserved. The remaining
  three knobs (per_share, spread_bps, market_impact) become material
  once `to_engine_costs` is wired into `Panel_runner` (next Open
  item). Pinning the overlay declaratively now means that wiring PR
  doesn't have to touch every golden again. See
  `dev/notes/cost-model-overlay-repin-2026-05-23.md` for rationale,
  scope, and estimated drift under full wiring (≈10 bps per
  round-trip ≈ ~1% absolute return-drag on Cell E's 341.69%
  baseline — comfortably inside the ±15% range tolerances). Verify:
  `dune runtest trading/backtest/scenarios` (scenario goldens
  parse + pass).

## Open work

- [ ] **Wire market-impact into the engine** — requires ADV
  plumbing. ADV needs to be loaded alongside bars; not yet in the
  simulation data layer. Defer until empirical evidence shows
  impact dominates over spread for realistic order sizes.

## Completed (continued)

- [x] **Wire `Cost_model.to_engine_costs` through `Panel_runner.run`**
  (PR pending, 2026-05-23 — feat/cost-model-to-engine-wiring). Added
  pure helper `Panel_runner.engine_costs_with_overlay` (exposed in
  the .mli for tests): when `cost_model = Some cm`, derives
  `(commission, slippage_bps)` from `Cost_model.to_engine_costs cm`
  and fully replaces both the runner default commission
  (`{ per_share = 0.01; minimum = 1.0 }`) and the caller's
  `?slippage_bps`; when `cost_model = None`, the runner defaults
  flow through unchanged (byte-equal baseline). Wired into the
  `_make_simulator` call site in `Panel_runner.run`. Two new test
  cases pin the resolution
  (`trading/backtest/test/test_panel_runner_cost_model.ml`):
  `cost_model=None preserves runner defaults` and `cost_model=Some
  retail_default overrides commission + slippage`. Goldens not
  re-pinned in this PR — the 7 cost_model-annotated scenarios
  exercise the full path under nightly perf-tier; Cell E expected
  to drift ≈1% return inside the existing ±15% tolerance per
  `dev/notes/cost-model-overlay-repin-2026-05-23.md` (spread drag
  partially offset by per-share commission dropping $0.01 → $0.00).
  Verify: `dune runtest trading/backtest/test/test_panel_runner_cost_model.exe`
  (2/2 pass); `dune runtest trading/backtest/cost_model` (27/27
  pass); full `dune runtest` green.

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
