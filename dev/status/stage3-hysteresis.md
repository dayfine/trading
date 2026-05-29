# Status: stage3-hysteresis

## Last updated: 2026-05-29

## Status
MERGED

PR-A MERGED (#1362, code knob plumbing). PR-B REJECTED on data (panel
re-pin retracted; see retraction note). Track delivers no further code
under this status file — any future revisit (walk-forward-grounded)
will open under a new track.

## Interface stable
YES

`Stage3_force_exit_runner.update` gained two new arguments
(`exit_margin_pct`, `prior_stage_ma_values`) and the strategy config
gained `stage3_exit_margin_pct`. The detector core in
`analysis/weinstein/stage3_force_exit/` is UNCHANGED — the margin
filter sits at the runner layer (where price + MA are accessible).
Knob defaults preserve panel behavior (`hysteresis_weeks=2` on
detector config; panel scenarios still pin explicit override
`hysteresis_weeks=1`. Margin default `0.0` skips the filter). PR-B
(panel re-pin to `hysteresis_weeks=2 + margin=0.02`) was REJECTED
on 2026-05-29 PM after the 15y panel materially regressed (see
follow-up retraction note).

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

Panel scenarios remain UNCHANGED — PR-B was REJECTED on 2026-05-29 PM
after the planned re-pin (`hysteresis_weeks=2 + stage3_exit_margin_pct=0.02`)
materially regressed the 15y panel despite winning on the 5y panel:

| Metric | 5y delta | 15y delta |
|---|---|---|
| total_return_pct | +4.33pp (improved) | -113.68pp (regressed) |
| sharpe_ratio | +0.05 (improved) | -0.16 (regressed) |
| max_drawdown_pct | -3.52pp (improved) | +4.47pp (regressed) |
| calmar_ratio | +0.11 (improved) | -0.19 (regressed) |
| sortino_ratio | +0.09 (improved) | -0.30 (regressed) |
| ulcer_index | -1.80 (improved) | +1.61 (regressed) |

5y vs 15y disagreement is the textbook single-window overfit pattern
this project has explicitly committed to reject (precedent:
`memory/project_continuation_combined_rejected.md`). Full data + lesson
in `dev/notes/stage3-hysteresis-panel-rejected-2026-05-29.md`.

Panel scenarios stay at:
- `trading/test_data/backtest_scenarios/goldens-sp500-historical/sp500-2010-2026.sexp` (`((hysteresis_weeks 1))`, default margin=0.0)
- `trading/test_data/backtest_scenarios/goldens-sp500/sp500-2019-2023.sexp` (same)

PR-A's code change (#1362) remains MERGED — knob defaults preserve panel
behavior, no harm done. The knob is available for future use; the panel
re-pin specifically was the wrong application.

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

PR-A (#1362, code knob plumbing) — REVIEWED + MERGED.

PR-B (panel re-pin) was REJECTED before opening. The retraction note
`dev/notes/stage3-hysteresis-panel-rejected-2026-05-29.md` is the
only PR-B-tier artifact landing.

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

## Follow-ups

1. **DO NOT re-attempt the panel re-pin with alternative `(h, margin)`
   cells** without first adding walk-forward cross-window validation.
   Per `dev/notes/stage3-hysteresis-panel-rejected-2026-05-29.md`, the
   single-window-overfit pattern is the reason; iterating in knob
   space without walk-forward is the explorative approach the project
   has committed to avoid.
2. **Walk-forward CV infrastructure** is the right unblock surface.
   Per `memory/project_strategic_pivot_broader_first.md` (2026-05-15
   pivot) — broader-universe + walk-forward CV + ML-discipline tuning
   is P0; this retraction reinforces the pivot's framing.
3. **Symmetric autopsy classifier** — extend `analysis/scripts/trade_autopsy/`
   to also measure missed-drawdown-avoidance on the late-exit side,
   not only missed-recovery on the early-exit side. The asymmetric
   signal is part of why the autopsy's 5y projection missed the 15y
   sign-flip.
4. **`stage3_force_exit_config` field embedding** — eventually move
   `exit_margin_pct` into the analysis-side `Stage3_force_exit.config`
   record once the analysis vs trading layer split is reconsidered.
   Lower priority now that PR-B is rejected — the knob is dormant
   until a walk-forward-grounded re-attempt is feasible.
5. **Late_stage2_admission fix (autopsy mode 3)** — same caution as
   stage3 hysteresis. Do not project per-symbol missed gain to
   portfolio outcomes without walk-forward validation.
