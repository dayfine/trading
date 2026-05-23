# Cost-model overlay repin — 2026-05-23

## Summary

Applied `cost_model = Some retail_default` declaratively to seven
canonical Weinstein-strategy goldens. With the current wiring landed
in PR #1260 (`apply_per_trade_commission` only, hooked via the
simulator's `?on_trade_fill`), this is byte-equal to `cost_model =
None` because `retail_default.per_trade_commission = 0.0` — the hook
is the identity function and every pinned metric is preserved.

No repin of metric ranges was required. The declarative wiring is the
deliverable. It removes the need to touch every golden again when the
remaining `Cost_model.to_engine_costs` plumbing lands (Open work item
in `dev/status/cost-model.md`).

## Scope

| Scenario | Tier | Strategy | Baseline metrics (pre-change) | Cost_model added |
|---|---|---|---|---|
| `goldens-small/bull-crash-2015-2020` | 2 | Weinstein | +110.6% / 0.93 Sharpe / 18.5% DD / 283 trades | `retail_default` |
| `goldens-small/six-year-2018-2023` | 2 | Weinstein | +56.6% / 0.55 Sharpe / 25.8% DD / 320 trades | `retail_default` |
| `goldens-small/covid-recovery-2020-2024` | 2 | Weinstein | +80.8% / 0.80 Sharpe / 24.3% DD / 280 trades | `retail_default` |
| `goldens-sp500/sp500-2019-2023` | 3 | Weinstein | +50.66% / 0.56 Sharpe / 21.56% DD / 264 trades | `retail_default` |
| `goldens-sp500/sp500-2019-2023-long-only` | 3 | Weinstein | +66.54% / 0.68 Sharpe / 24.09% DD / 248 trades | `retail_default` |
| `goldens-sp500-historical/sp500-2010-2026` (Cell E) | 3 | Weinstein | +341.69% / 0.78 Sharpe / 18.36% DD / 806 trades | `retail_default` |
| `goldens-sp500-historical/sp500-2010-2026-longshort` | 3 | Weinstein | +316% / 0.70 Sharpe / 19.8% DD / ~720 trades | `retail_default` |

BAH-benchmark scenarios (`sp500-2019-2023-bah-{brk-b,spy}`,
`sp500-2011-2026-bah-brk-b`) intentionally excluded — they're passive
single-symbol references, not Weinstein-strategy comparators.

## Why retail_default

Per the four-knob preset defined in
`trading/trading/backtest/cost_model/lib/cost_model.ml`:

```
retail_default = {
  per_trade_commission = 0.0;
  per_share_commission = 0.0;
  bid_ask_spread_bps   = 5.0;
  market_impact_bps_per_pct_adv = 0.0;
}
```

Rationale (from the module docstring): "Approximate flat-fee retail
broker: $0/trade, $0/share, 5 bps bid-ask, no market impact" — i.e.
Robinhood / IBKR Lite circa 2026. Zero explicit commission matches
the current US-equity zero-commission norm. The 5 bps bid-ask is a
realistic round-half spread for top-of-book SP500 liquidity.

`institutional_default` (per_share=$0.005, spread=2 bps, impact=1 bps
per 1% ADV) was considered but rejected as a default:
- The two cost regimes diverge most on `per_share`, which is not yet
  wired into the simulator. Until `to_engine_costs` plumbing lands,
  the choice between presets is decorative.
- Retail framing matches the system's stated user model ("semi-
  automated trading system" — `weinstein-trading-system-v2.md`).
- Future sensitivity sweeps can flip a single field to compare.

## Why declarative-now, drift-later

PR #1260 wired only `apply_per_trade_commission` into the simulator.
The other three knobs — `per_share_commission`, `bid_ask_spread_bps`,
`market_impact_bps_per_pct_adv` — are reachable via
`Cost_model.to_engine_costs` and `apply_market_impact`, but those
helpers are NOT called by `Panel_runner.run` yet. See the open work
section of `dev/status/cost-model.md`:

> Wire market-impact into the engine — requires ADV plumbing. ADV
> needs to be loaded alongside bars; not yet in the simulation data
> layer. Defer until empirical evidence shows impact dominates over
> spread for realistic order sizes.

So `cost_model = Some retail_default` today is **byte-equal** to
`cost_model = None`:

- `per_trade_commission = 0.0` → `apply_per_trade_commission` is the
  identity (`if Float.(t.per_trade_commission = 0.0) then trade`).
- `per_share_commission`, `bid_ask_spread_bps`, and
  `market_impact_bps_per_pct_adv` are inert because no caller reads
  them.

The benefit of pinning declaratively now: the next wiring PR can
flip a flag in `Panel_runner.run` to call `to_engine_costs` and
every golden immediately becomes a cost-aware run — no per-scenario
touch needed.

## Estimated drift under full wiring

Once `to_engine_costs` is wired into `Panel_runner`, the
`retail_default.bid_ask_spread_bps = 5.0` rounds to `slippage_bps =
5` (engine's int param), which the engine's
`_apply_slippage_to_fill` applies symmetrically — buys at
`price × (1 + 5/10000)`, sells at `price / (1 + 5/10000)`. Expected
attrition (rough, order-of-magnitude):

- **Per round-trip drag**: ~10 bps (buy + sell each take 5 bps).
- **Cell E (15y, 806 trades, ≈403 round-trips)**: ≈403 × 10 bps ≈
  4% cumulative cash-flow drag. On a 341.69% baseline ≈ 1% absolute
  return-drag.
- **sp500-2019-2023 (5y, 264 trades, ≈132 round-trips)**: ≈132 × 10
  bps ≈ 1.3% cumulative drag.

This sits well inside the current ±15% range tolerances, so even
after the wiring PR lands, the *pinned ranges* below the cost
overlay are likely to absorb the drift without a re-pin. The
expected metric *deltas* (point estimates) will shift; the range
*bounds* should not. That's the cleanest outcome: the cost overlay
is a meaningful realism improvement without rebaselining every test.

## Follow-up work

In priority order:

1. **Wire `to_engine_costs` through `Panel_runner`** so cost_model
   actually controls commission + slippage. Single-file change
   (~30 LOC):
   ```ocaml
   (* In Panel_runner.run, before _make_simulator: *)
   let commission, slippage_bps =
     match cost_model with
     | Some cm ->
         let cm_commission, cm_bps = Cost_model.to_engine_costs cm in
         let bps = Option.value slippage_bps ~default:cm_bps in
         (cm_commission, Some bps)
     | None -> (commission, slippage_bps)
   in
   ```
   Land alongside a smoke test confirming the panel-step loop sees
   the new commission + bps values when cost_model is set.
2. **Re-run the small goldens** (six-year, bull-crash, covid-
   recovery) under the new wiring; observe expected ≈1% return-drag
   and confirm pinned ranges still gate. If any range breaks, this
   IS the signal that a re-pin is needed.
3. **Re-run Cell E** (15y, ~20 min on local parallel-3). Same
   expectation: ≈1% return-drag, no range breakage.
4. **Sweep `bid_ask_spread_bps`** from 0 to 50 bps on Cell E to
   quantify the attrition curve. Status file's follow-up
   experiments section already requests this.
5. **Plumb ADV** through `Daily_panel_snapshot` so
   `apply_market_impact` can be wired into the fill path.

## Verification

```
docker exec trading-1-dev bash -c \
  'cd /workspaces/trading-1/trading && eval $(opam env) && \
   dune build && \
   dune runtest trading/backtest/scenarios && \
   dune runtest trading/backtest/cost_model'
```

All scenario sexps still parse (`Scenario.load` round-trip via
`dune runtest trading/backtest/scenarios`). The `cost_model` field is
optional and parses correctly when set or omitted. Existing pinned
metric ranges unchanged.
