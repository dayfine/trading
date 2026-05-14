# Axis-2 main-scenario re-measurement (review addendum)

The PR's original 4-cell sweep ran on `sp500-2019-2023-long-only.sexp` (shorts
off). Behavioral QC flagged that the "axis-2 lifts Calmar 2.8× more than
axis-1" comparison was not apples-to-apples since axis-1 (PR #1079) ran on
the main scenario (`sp500-2019-2023.sexp`, shorts on).

This addendum re-runs the same 4 cells on the main scenario. The qualitative
verdict survives — actually strengthens.

## Main-scenario results

| Cell | Return | Trades | WR | Sharpe | MaxDD | Calmar | AvgHold |
|---|---:|---:|---:|---:|---:|---:|---:|
| 006 | 33.94% | 312 | 36.86% | 0.43 | 28.67% | 0.21 | 33.65d |
| 008 baseline | 50.66% | 264 | 37.50% | 0.56 | 21.56% | 0.40 | 40.78d |
| **010** | **93.76%** | **195** | **36.41%** | **0.88** | **18.36%** | **0.77** | **56.05d** |
| 012 | 92.79% | 183 | 34.97% | 0.87 | 19.61% | 0.72 | 55.41d |

## Apples-to-apples comparison (main vs main)

| Axis | Δ Return | Δ Sharpe | Δ MaxDD | Δ Calmar |
|---|---:|---:|---:|---:|
| **axis-1 winner** (`installed_stop_min_pct = 0.08`, #1079) | +36.4 pp | +0.19 | **+3.9** | +0.13 |
| **axis-2 winner** (`min_correction_pct = 0.10`, this PR) | **+43.1 pp** | **+0.32** | **−3.2** | **+0.37** |

Axis-2 cell-010 is strictly better than axis-1 on every dimension:
- Bigger return lift (+43 pp vs +36 pp)
- Bigger Sharpe lift (+0.32 vs +0.19)
- **MaxDD IMPROVES** (-3.2 pp) where axis-1 MaxDD worsened (+3.9 pp)
- Calmar lift 2.85× larger (+0.37 vs +0.13)

The "2.8× stronger" headline is preserved on main-to-main.

## Long-only result (original PR body) — also valid

The long-only baseline + cell-010 long-only also showed ΔCalmar +0.37
(coincidentally identical). Both scenarios produce the same lift magnitude,
so the conclusion is robust:

**`min_correction_pct = 0.10` is the dominant axis-2 lever, and dominates
axis-1.**

## Recommendation

1. Promote `min_correction_pct = 0.10` as the next Cell E tuning candidate.
2. **Run a 1×2 cross-sweep** of axis-1 (`installed_stop_min_pct = 0.08`) ×
   axis-2 (`min_correction_pct = 0.10`) to see if effects compound. The
   axis-1 sweep widened the installed stop floor; axis-2 widens the
   support-floor + buffer. They may be additive or interact destructively.
3. Validate cell-010 on 10y + 16y goldens before locking in (per the same
   protocol as #1081 for axis-1).

## Files

- Main-scenario cell sexps: `dev/backtest/axis2-main-rerun/cell-*.sexp` (not
  committed; trivially regenerable by stripping `enable_short_side false`
  from the original long-only cells).
- Output dir: `dev/backtest/scenarios-2026-05-14-011236/`
