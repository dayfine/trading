# Status: stage3-hysteresis

## Last updated: 2026-05-29

## Status
READY_FOR_REVIEW

## Interface stable
NO

`Stage3_force_exit_runner.update` gained two new arguments
(`exit_margin_pct`, `prior_stage_ma_values`) and the strategy config
gained `stage3_exit_margin_pct`. The detector core in
`analysis/weinstein/stage3_force_exit/` is UNCHANGED — the margin
filter sits at the runner layer (where price + MA are accessible).
Public surface treated as v0 until at least one downstream sweep
exercises both panel scenarios with the new defaults.

## What it is

Production-side analogue of the per-symbol Stage-3 hysteresis fix
recommended by the trade-autopsy diagnostic (PR #1360,
`dev/notes/trade-autopsy-2026-05-29.md`). Two knobs:

1. `Stage3_force_exit.config.hysteresis_weeks` — already existed
   (default 2); the autopsy recommended bumping panel scenarios from
   1 → 2. No code change here, just a panel scenario override flip.
2. `Weinstein_strategy_config.stage3_exit_margin_pct` — NEW. Required
   minimum margin (fractional) by which close must sit below the
   30-week MA before the runner emits a force-exit. Default 0.0
   preserves prior behaviour; panel scenarios opt in via override.

Together these gate false Stage 2 → 3 transitions that immediately
resolve back to Stage 2. Autopsy classified those as +1557% missed
gain across 48 trades (`late_reentry`) + +1176% across 71 trades
(`stage3_false_positive`) — combined ~75% of measured missed gain
on the 27y × 12 sym per-symbol panel.

## Files

Strategy (`trading/trading/weinstein/strategy/lib/`):
- `weinstein_strategy_config.{ml,mli}` — new `stage3_exit_margin_pct`
  field on `config`, default `0.0`.
- `weinstein_strategy.{ml,mli}` — allocates a parallel
  `prior_stage_ma_values : float Hashtbl.M(String).t`, threads it
  through `_run_stops_pass` (write) and `_run_special_exits` (read).
- `stops_runner.{ml,mli}` — new optional `?prior_stage_ma_values`
  parameter; when supplied, writes each symbol's `result.ma_value`
  alongside the existing `prior_stages` write.
- `stage3_force_exit_runner.{ml,mli}` — `update` gained
  `~exit_margin_pct : float` and `~prior_stage_ma_values : float
  Hashtbl.M(String).t option`. Both required-labeled for explicit
  intent at every call site.

Tests (`trading/trading/weinstein/strategy/test/`):
- `test_stage3_force_exit_runner.ml` — extended from 9 → 16 cases.
  7 new cases pin: backward-compat at `h=1` + `margin=0.0`; margin
  filter suppresses close-above-MA / marginal-below; margin filter
  fires on deep-below; missing-MA short-circuits to "met"; combined
  confirmation + margin both satisfied; combined confirmation met but
  margin fails.
- `test_force_liquidation_strategy.ml` — `_strategy_state` record
  + `_fresh_state` updated with `prior_stage_ma_values` field.

Panel scenarios NOT re-pinned in this PR — split out to PR-B
(follow-up):
- `trading/test_data/backtest_scenarios/goldens-sp500-historical/sp500-2010-2026.sexp`
- `trading/test_data/backtest_scenarios/goldens-sp500/sp500-2019-2023.sexp`

Both still pin at `((hysteresis_weeks 1))` + default
`((stage3_exit_margin_pct 0.0))` (preserved) — backward-compat is
maintained, no panel pin drift, CI stays green on the merge of this
PR. The actual flip to `hysteresis_weeks 2` + `stage3_exit_margin_pct
0.02` requires:

1. Run scenario_runner on both panels (~25 min each wall).
2. Read each `actual.sexp`; update Measured header + expected ranges
   (±15% tolerances around new measurements).
3. Update `dev/scripts/promote_config.sh` PANEL row constants
   (8-column format from #1359).

This is left to follow-up PR-B per the brief's "2 PRs if scenario
re-pins want to be separate" allowance. Justification: the panel
re-runs are wall-time-bound (~50 min combined) and require active
sanity-checking against `feedback_strategy_mechanic_changes_too_explorative.md`
(if numbers degrade on the 5y panel, retract). Keeping the code-only
PR mergeable independently lets PR-B test (and potentially retract)
the parameter choices in isolation.

## Architecture notes

- The pure detector `Stage3_force_exit` in `analysis/weinstein/` was
  NOT modified. Per the dispatch scope guard rail "Do NOT modify any
  analysis/ source code", and because the margin filter needs price +
  MA data only available at the trading-side runner layer.
- The brief named the new confirmation knob
  `stage3_confirmation_weeks` and suggested adding it to
  `stage3_force_exit_config`. That conflicts with the EXISTING
  `Stage3_force_exit.config.hysteresis_weeks` knob which already
  encodes exactly the same semantics (consecutive Stage-3 Friday
  count). Rather than duplicate the knob, this PR re-uses
  `hysteresis_weeks` and exposes only `stage3_exit_margin_pct` as
  new surface.

## QC

NOT YET REVIEWED. Awaiting:
- `qc-structural` (A1 will FLAG — touches `weinstein_strategy_config`
  + `weinstein_strategy.ml` + `stops_runner.ml` — Weinstein-specific
  strategy-level config additions are expected for this track).
- `qc-behavioral` (S* / L* / C* / T* domain rows apply; S3 / S5 / S6
  / L1-L4 / T1-T4 most relevant).

## Verify

Build + tests inside docker:

```bash
docker exec trading-1-dev bash -c \
  'cd /workspaces/trading-1/trading && eval $(opam env) && \
   dune build @fmt && dune build && dune runtest'
```

Specifically the 16 stage3-runner tests:

```bash
docker exec trading-1-dev bash -c \
  'cd /workspaces/trading-1/trading && eval $(opam env) && \
   dune runtest trading/weinstein/strategy/test/test_stage3_force_exit_runner.exe'
```

Panel re-runs (each ~25 min wall):

```bash
docker exec trading-1-dev bash -c \
  'cd /workspaces/trading-1/trading && eval $(opam env) && \
   ./_build/default/trading/backtest/scenarios/scenario_runner.exe \
     --dir test_data/backtest_scenarios/goldens-sp500 \
     --fixtures-root test_data/backtest_scenarios \
     --no-emit-all-eligible'
```

## Follow-ups (out of scope for this PR)

1. **Re-run trade-autopsy with the hysteresis fix in place** — pin
   the autopsy framework as a fix-finder vs labelling exercise.
   Expected: `late_reentry` total drops 40-70%; `stage3_false_positive`
   drops dramatically; `late_stage2_admission` unchanged.
2. **Sweep `(hysteresis_weeks, exit_margin_pct)` jointly** for the
   CAGR-vs-Sharpe optimum on both 5y and 15y panels.
3. **Late_stage2_admission fix** — autopsy's #3 failure mode
   (+505% / 100 trades). Different mechanic; defer until P0+P1
   confirm the autopsy → fix loop is working.
4. **`stage3_force_exit_config` field embedding** — eventually move
   `exit_margin_pct` into the analysis-side `Stage3_force_exit.config`
   record once the analysis vs trading layer split is reconsidered.
   Out of scope here per the dispatch scope guard rail.
