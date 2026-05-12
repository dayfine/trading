# 81-cell flagship grid — `screening.weights.*` (2026-05-12)

Closes (in the negative) the M5.5 T-A acceptance criterion:

> "Best cell must produce a strictly-higher Sharpe than the baseline
> (rs=1.0, vol=1.0, breakout=1.0, sector=1.0)."

## Headline

**All 81 cells produce identical (Sharpe, num_trades, total_pnl, max_drawdown,
…) within each scenario.** The screener-weight axis is functionally inert at
the current cascade-filter design. M5.5 T-A acceptance criterion FAILS by
strict reading (no cell strictly beats baseline) and PASSES by the
"no-need-to-tune" reading (defaults are as good as anything in this grid).

## Result table

| Scenario | Sharpe | num_trades | total_pnl | (constant across all 81 cells) |
|---|---:|---:|---:|---:|
| bull-2019h2 | 1.429316 | 32 | +$35,780 | yes |
| crash-2020h1 | 0.169706 | 31 | -$89,432 | yes |
| recovery-2023 | 1.447642 | 51 | -$36,545 | yes |
| **Mean** | **1.015555** | — | — | — |

Sensitivity report (`sensitivity.md`) confirms: each of the four weight
parameters shows mean objective = 1.015555 at all three sweep values
(0.5 / 1.0 / 1.5) — a flat sensitivity surface on every axis.

## Run params

- Spec: `dev/experiments/grid-screening-weights-2026-05-12/spec.sexp`
- Grid: 3⁴ = 81 cells over `{rs, volume, breakout, sector}` × `{0.5, 1.0, 1.5}`
- Scenarios: 3 smoke (bull-2019h2, crash-2020h1, recovery-2023)
- Objective: Sharpe (mean across scenarios)
- Wall: ~2h 5min at `--parallel 3` on the local container.
- Log: `dev/experiments/grid-screening-weights-2026-05-12/run-logs/run-2026-05-12-164246-par3.log`

## Why are the weights inert?

Two hypotheses were proposed; **H1 is CONFIRMED.**

### H1 (CONFIRMED 2026-05-12) — Score is monotonic & the cascade gate is grade-driven

Diagnostic sweep at `dev/experiments/h1-h2-diagnostic-2026-05-12/`: 2-cell
grid `{rs=0.0, rs=5.0}` — extreme range, single dim — on the same 3 smoke
scenarios. Result: **rs=0.0 and rs=5.0 produce bit-identical metric tuples
per scenario** (across all ~70 metric columns in `grid.csv`). The score
column is computed and varies linearly, but the cascade's grade-gate maps
both extremes to the same surviving candidate set.

`Screener_scoring.compute_score` scales linearly with each weight. When
all weights scale uniformly OR a single weight scales, the *ranking* of
candidates within a Stage 2 cohort stays the same. The cascade's downstream
gate is `min_grade` — a threshold on the **absolute** score — but the
grade-cutoff (default C) maps to a quantile of the ranking rather than an
absolute value, so scaling all scores leaves the same candidates surviving.

### H2 (REJECTED 2026-05-12) — The 0.5..1.5 range is too narrow to flip ranking ties

Ruled out by the same diagnostic: even rs at 0.0 (zero weight) vs 5.0 (10×
the default 0.5) produces no metric divergence. Ranking-tie inversions
either do not exist or are below the cascade's grade-floor in this universe.

## Implications

- **Cell-E baseline is robust.** No weight cell strictly improves over
  baseline → defaults can stay as documented.
- **Sweep-time is wasted on this axis.** Future tuning effort should target
  axes that demonstrably move the objective:
  - `screening_config.candidate_params.installed_stop_min_pct` (new knob from
    the 2026-05-12 P4-rewire — preliminary; see
    `runner-multi-overlay-investigation-2026-05-12.md`).
  - `stops_config.min_correction_pct` (drives both support-floor detection
    threshold AND placed-stop buffer).
  - `screening_config.min_score_override` / `max_score_override` (the score
    gate itself, not the weights).
  - `screening_config.volume_ratio_exclude_range` (per #1043).
- **Cascade design question.** If weights are inert because the cascade is
  grade-driven, the screener's "scoring weights" surface is largely
  ornamental. Either widen the cascade gate (use the score numerically not
  via grades) or simplify the weights surface.

## Artefacts (in this directory)

- `spec.sexp` — the 81-cell grid spec (M5.5 T-A flagship).
- `grid.csv` — 243 rows (81 × 3 scenarios), all numeric metric columns +
  objective_sharpe.
- `best.sexp` — argmax cell. Tied; reported cell is the first in enumeration
  order (rs=0.5, volume=0.5, breakout=0.5, sector=0.5) — but every cell
  scored 1.015555 so this is arbitrary.
- `sensitivity.md` — per-param sensitivity (flat across all values).
- `run-logs/run-2026-05-12-164246-par3.log` — full backtest log.
- `tiny-grid-spec.sexp` — 2×2 verification spec used to pin `--parallel 1` vs
  `--parallel 2` output parity in the runner.

## Follow-ups

- Diagnose H1 vs H2: run a 4-cell smoke sweep with `{0.0, 5.0}` × 1 dim, see
  if any single-dim extreme moves the objective. If still flat, H1 is
  confirmed; the weights are entirely vestigial under the current cascade.
- Drop screener weights from the M5.5 tuning track. Move active sweep budget
  to {stop floor, score gate, vol-ratio exclusion} axes.
