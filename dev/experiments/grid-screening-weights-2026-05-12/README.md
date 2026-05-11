# 81-cell flagship sweep on `screening.weights.*` (Block 4)

Closes `tuning` track M5.5 T-A. Pairs with T-B convergence cross-check (Block 5).

## What

4-D grid over the four primary `Screener.scoring_weights` fields:
- `rs` (relative strength)
- `volume` (volume confirmation)
- `breakout` (breakout-strength)
- `sector` (sector-rating)

Values: `{0.5, 1.0, 1.5}` per dim → 3⁴ = **81 cells**.

Window: 3-scenario smoke catalog (bull-2019h2, crash-2020h1, recovery-2023). Smoke window keeps total wall under 2hr per `dev/status/tuning.md`.

Objective: `Sharpe`.

## Run (Block 4)

```
dev/lib/run-in-env.sh dune exec trading/backtest/tuner/bin/grid_search.exe -- \
  --spec /workspaces/trading-1/dev/experiments/grid-screening-weights-2026-05-12/spec.sexp \
  --out-dir /workspaces/trading-1/dev/experiments/grid-screening-weights-2026-05-12
```

## Acceptance criterion

Per `dev/plans/m5-experiments-roadmap-2026-05-02.md` §M5.5 T-A:

- Best cell's Sharpe must strictly exceed the baseline cell (rs=1.0, volume=1.0, breakout=1.0, sector=1.0). If not, this axis isn't worth tuning and defaults can be pinned.
- Wall-time ≤ 2h.

## T-B convergence cross-check (Block 5)

After grid sweep lands, run:

```
dev/lib/run-in-env.sh dune exec trading/backtest/tuner/bin/bayesian_runner.exe -- \
  --spec <bayes-spec> \
  --out-dir dev/experiments/grid-screening-weights-2026-05-12/bayes-cross-check
```

with the same 4-D bounds + budget=30 evals. T-B passes if it converges to the grid_search best Sharpe ±5% — closes the M5.5 T-B convergence acceptance criterion.
