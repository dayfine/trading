# P5 PI-filter 16y validation — survivorship-bias check on M5.5 axis-2 STOP (2026-05-14)

## Context

- PR #1089 (merged) wired the strategy-side `enable_pi_filter` flag +
  `Screener.screen_with_cooldown ?membership_at` callback.
- PR #1094 (merged) propagated `Daily_price.active_through` through manifest
  → snapshot → bar reader so the filter is finally behaviourally live.
- M5.5 axis-2 (`memory/project_m5-5-tuning-exhausted.md`) recorded a
  CATASTROPHIC STOP on 16y long-only — MaxDD 19.9% → 60.1%, 0 → 26
  force-liquidations (PR #1086). That was measured on survivorship-biased
  data (every delisted symbol treated as if it traded forever).

## Hypothesis

If turning the PI filter on materially reduces the 16y MaxDD / force-liq
count under the axis-2 (`min_correction_pct = 0.10`) catastrophic config,
then survivorship bias was a load-bearing piece of the axis-2 verdict and
the M5.5 STOP may be revisable. If not (filter is on but metrics stay
roughly the same), survivorship is NOT what drove axis-2's failure.

## 2×2 design

Four cells on the 16y `goldens-sp500-historical/sp500-2010-2026.sexp`
universe (510-symbol sp500-historical, Wiki+EODHD-replayed):

| Cell | axis-2 | PI filter | Purpose |
|---|---|---|---|
| `pi-off-baseline` | OFF | OFF | Mainline baseline; bit-equal to current 16y golden |
| `pi-on-baseline`  | OFF | ON  | Does PI filter alone shift the baseline? |
| `pi-off-axis2`    | ON  | OFF | Reproduce PR #1086's catastrophic survivorship-biased verdict |
| `pi-on-axis2`     | ON  | ON  | Critical cell: does PI filter rescue the catastrophe? |

All cells use Cell E ship config (post-PR #1052..#1063, post-PR #1094):
- `max_position_pct_long = 0.14`, `max_long_exposure_pct = 0.70`,
  `min_cash_pct = 0.30`
- `enable_stage3_force_exit = true` (h=1)
- `enable_laggard_rotation = true` (h=2)
- Long-only (`enable_short_side = false`)

axis-2 cells additionally set `stops_config.min_correction_pct = 0.10`
(the rejected PR #1083 5y winner).

PI-on cells additionally set `enable_pi_filter = true`.

## Metrics captured per cell

CAGR, Sharpe, MaxDD, Calmar, total return, **total trade count**,
**force-liquidation count**, **distinct-tickers-traded count**, win rate,
average holding days, Sortino, Ulcer index. Side-by-side delta in
`report.md`.

## Decision rules (pre-registered)

**Revise the M5.5 axis-2 STOP** iff ALL hold on the `pi-on-axis2` vs
`pi-off-axis2` comparison:
- MaxDD reduction ≥ 10pp (e.g. 60% → 50% or less)
- Force-liq count reduction ≥ 50% (e.g. 26 → 13 or less)
- Calmar ΔCalmar ≥ +0.10

**Keep the M5.5 axis-2 STOP** iff ANY hold:
- MaxDD within ±3pp of `pi-off-axis2`
- Force-liq count within ±20%
- ΔCalmar within ±0.05

**Inconclusive** for everything between (warrants a smaller-scope
follow-up, e.g. broad-1000 PI re-run or a longer horizon).

A separate observation on the `pi-on-baseline` vs `pi-off-baseline`
pair: if these differ by ≥ 5% on any headline metric, every 16y golden
needs re-pinning. If they're bit-equal, the PI filter is a strict
no-op on the survivorship-aware default Cell E universe (because no
delistings occur during the window in this 510-symbol Wiki-replayed
universe) — that would be its own diagnostic, not a failure.

## Falsifiability

Today (post-#1094), the wiring is behaviourally live. The previous
P5 wiring-validation experiment (`p5-pi-filter-validation-2026-05-14/`)
expected bit-equality between pi-off and pi-on; if today's run also
returns bit-equality on the baseline pair, that's not a wiring bug —
it means no symbol in `sp500-2010-01-01.sexp` has an `active_through`
date inside the 2010-01-01..2026-04-30 window (likely outcome given
the universe was reverse-replayed FROM the 2026 constituent table).
The axis-2 cell remains informative regardless.

## Reproduction

```bash
docker exec trading-1-dev bash -c \
  'cd /workspaces/trading-1/trading && eval $(opam env) && \
   dune exec backtest/scenarios/scenario_runner.exe -- \
     --dir test_data/backtest_scenarios/experiments/p5-pi-filter-16y-validation-2026-05-14 \
     --parallel 2'
```

Output: `dev/backtest/scenarios-<timestamp>/<scenario>/{summary,actual,params}.sexp`.
