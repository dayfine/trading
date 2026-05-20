# Bayesian production v2 result (2026-05-21)

V2 of the production Bayesian sweep completed. This doc captures the
winner, the promote-gate evaluation per plan §6, and the v3 / next-step
recommendation.

## What ran

- **Spec**: `dev/experiments/bayesian-production-sweep-2026-05-18/spec_prod_v2.sexp`
  - Same 4 knobs as v1; v1's recommendation (lower-bound clustering on
    3 of 4 knobs) drove the v2 widening:
    - `portfolio_config.max_position_pct_long` widened to [0.02, 0.20]
      (v1 was [0.05, 0.20])
    - `portfolio_config.max_long_exposure_pct` widened to [0.30, 0.95]
      (v1 was [0.50, 0.95])
    - `initial_stop_buffer` widened to [0.97, 1.10] (v1 was [1.00, 1.10])
    - `installed_stop_min_pct` unchanged at [0.04, 0.15].
  - `acquisition` = Expected_improvement; same scoring (Sharpe − 0.1×MaxDD-soft-floor − 10×gate_fail).
  - `initial_random` = 10, `total_budget` = 60, `seed` = 2026.
  - `holdout_folds` = (26 27 28 29) (0-indexed; the last 4 folds).
- **Walk-forward fixture**: same `cell_e_30fold_2026_05_16.sexp` (31 folds).
- **Wall**: ~10-11 hours for BO sweep (2026-05-20 overnight), ~11 minutes
  for the v2-winner full-run at parallel=4.

## Winner (iter 1 — random sample, BO never improved)

| Knob | v1-winner | v2-winner | v2 bound | Δ vs v1 |
|---|---:|---:|---|---:|
| `max_position_pct_long` | 0.054 | **0.061** | [0.02, 0.20] | +0.007 (mid-bound) |
| `max_long_exposure_pct` | 0.516 | **0.330** | [0.30, 0.95] | **-0.186** (now near lower bound) |
| `initial_stop_buffer` | 1.007 | **1.072** | [0.97, 1.10] | **+0.065** (REVERSED v1 intuition) |
| `installed_stop_min_pct` | 0.127 | **0.114** | [0.04, 0.15] | -0.013 (upper-mid) |

**Critical observation**: V2's iter-1 random draw was the global best
across all 60 iterations. The BO never improved on it — every subsequent
suggestion scored worse. Running-best objective stayed at -9.195 from
iter 1 through iter 59 (convergence.md). The Sharpe range across 60
iters was [0.478, 0.805], mean 0.688, suggesting either:
(a) the objective surface is too flat (uninformative gradient), or
(b) the scorer is overwhelmingly dominated by the gate-fail penalty
(10×gate_fail), masking real differences.

The widened bounds were partially correct: `max_long_exposure` did want
to go below the v1 lower bound (settled at 0.330, near v2's new lower
bound 0.30). But `initial_stop_buffer` moved UP (1.072 vs v1's 1.007 at
the lower bound) — the v1 "wants tighter entry stop" intuition was
wrong.

## Headline metrics (31 folds, full sp500-2010-2026 window)

| Metric | cell-E baseline | v2-winner | v1-winner (ref) | Δ v2 vs cell-E |
|---|---:|---:|---:|---:|
| Mean Sharpe | 0.560 | **0.805** | 0.796 | **+0.245** (+44%) |
| Sharpe stdev | 1.064 | 1.037 | 1.078 | -0.027 (slight) |
| Mean CAGR % | 8.75 | **12.65** | 11.98 | **+3.90pp** |
| Mean MaxDD % | 11.98 | **10.48** | 10.57 | -1.50pp (better) |
| Mean Calmar | 1.310 | **1.847** | 1.837 | +0.537 |
| Mean holding days | 33.9 | **66.3** | n/a | **+95%** (positions held ~2× longer) |
| Sharpe wins | — | **20 / 31** | 19 / 31 | majority |

V2-winner edges out V1-winner on every aggregate metric (Sharpe
+0.009, CAGR +0.67pp, MaxDD -0.09pp, Calmar +0.010). The improvement
is marginal — within sampling noise of v1's full-run.

The avg-holding-days near-doubling (33.9 → 66.3) is the most concrete
behavioural shift: V2's wider initial_stop_buffer (1.072 vs cell-E
default ~1.00) plus higher installed_stop_min_pct (0.114 vs cell-E ~0.08)
means positions get more breathing room, so they exit less often, so
holding periods expand. Lower long-exposure (0.33 vs ~0.70) is the other
half — fewer simultaneous positions held longer.

## 5-axis promote-gate (plan §6)

| # | Axis | v2-winner result | v1 result | Verdict |
|---|---|---|---|---|
| 1 | Mean composite ≥ baseline + 0.05 | +0.245 Sharpe (hurdle +0.05) | +0.236 | **PASS** |
| 2 | No fold worse by >0.10 Sharpe | **9 folds worse by >0.10** | 6 worse | **FAIL** (worse than v1) |
| 3 | OOS Sharpe ≥ 0.50 every fold | **fold-029 = -0.996** | fold-029 = -0.855 | **FAIL** (worse than v1) |
| 4 | MaxDD ≤ baseline + 5pp every fold | **fold-017 = +5.41pp** | max +4.10pp (PASS) | **FAIL** (regression vs v1) |
| 5 | N_trades within 2× baseline | holding days doubled → trades ~halved (borderline) | TBD | **TBD/BORDERLINE** |

### Axis 2 detail — 9 folds where v2-winner is worse than cell-E by >0.10 Sharpe

| Fold | cell-E | v2-winner | Δ | Fold also lost in v1? |
|---|---:|---:|---:|---|
| fold-000 (2010-01..2010-12) | 1.119 | 1.003 | -0.116 | no |
| fold-001 (2010-07..2011-07) | 2.296 | 1.934 | -0.362 | no |
| fold-004 (2011-12..2012-12) | 1.171 | 0.520 | -0.651 | yes (-0.837) |
| fold-006 (2012-12..2013-12) | 2.589 | 2.416 | -0.173 | no |
| fold-007 (2013-06..2014-06) | 1.823 | 1.019 | -0.804 | no |
| fold-008 (2013-12..2014-12) | 0.856 | 0.693 | -0.163 | no |
| fold-010 (2014-12..2015-12) | 0.851 | 0.044 | -0.807 | yes (-0.922) |
| fold-017 (2018-06..2019-06) | 0.274 | -0.678 | -0.952 | yes (-0.768) |
| fold-019 (2019-06..2020-06) | -0.355 | -0.641 | -0.286 | yes (-0.373) |

V2 hurts 9 folds vs v1's 6 — and 5 of v1's 6 bad folds remain bad in v2
(only fold-011 and fold-028 recovered). V2's broader bound did NOT
fix axis 2; it added 3 new losing folds (001, 006, 007, 008 — all
*trending* years where v2's lower exposure missed upside).

### Axis 3 detail (OOS folds 26-29, the held-out tail)

The bayesian_runner's `Oos_validator` reported **ACCEPT** because it
uses a softer rule (within-0.10-gap of in-sample mean: 0.739 vs 0.815,
gap 0.076 < 0.10). Plan §6's strict "every OOS fold ≥ 0.50" floor
fails.

| Fold | v2-Sharpe | Verdict |
|---|---:|---|
| fold-026 (2023-01..2023-12) | 1.312 | ✓ |
| fold-027 (2023-07..2024-06) | 2.023 | ✓ |
| fold-028 (2024-01..2024-12) | 0.618 | ✓ (above 0.50 — recovered from v1's 0.498 borderline) |
| fold-029 (2024-07..2025-07) | **-0.996** | **FAIL** — worse than v1's -0.855 |
| fold-030 (2025-01..2026-04, truncated) | 0.707 | ✓ (recovered from v1's 0.957 — slightly worse but pass) |

V2 made fold-029 WORSE than v1 (-0.996 vs -0.855). The 2025 OOS
disaster is amplified, not fixed, by widening the bounds.

### Axis 4 detail — MaxDD blowout on fold-017

V2's tighter exposure should reduce MaxDD across the board, but
fold-017 (2018 mid-cycle) blew up: 14.30% MaxDD vs cell-E's 8.89%
(+5.41pp, above the +5pp floor). V1-winner on fold-017 was 12.17%
(+3.28pp — within floor).

This is a v2-specific regression: the wider `initial_stop_buffer`
(1.072) is letting losing positions run further before stopping out
in 2018's choppy mid-cycle conditions. The "give positions room"
intuition cost this fold ~5.4 drawdown points.

## Verdict

**REJECT per plan §6 strict 5-axis gate. WORSE than V1 on axes 2, 3, 4.**

V2 was supposed to fix v1's axis-2/3 failures by widening the
search space. Instead, it tied v1 on aggregate Sharpe (0.805 vs
0.796, statistical noise) while regressing on every per-fold safety
floor:
- **Axis 2**: 9 bad folds vs v1's 6.
- **Axis 3**: fold-029 OOS = -0.996 vs v1's -0.855.
- **Axis 4**: NEW failure on fold-017 (+5.41pp MaxDD).

The Bayesian search itself never converged — iter 1 (random sample)
beat all 59 subsequent BO suggestions. This indicates the objective
function is the bottleneck, not the search.

## Why V2 failed (mechanism)

1. **Lower exposure (0.33 vs v1's 0.52) sacrificed trending-year
   alpha.** Folds 001, 006, 007, 008 — all bull or trending markets
   in 2010-2014 — lost Sharpe vs cell-E because v2 simply ran fewer
   positions. The mean Sharpe boost came from down-market folds
   (021, 027) where being lighter helped — Sharpe averaging masks the
   per-fold trade-off.

2. **Wider initial_stop_buffer (1.072) gave losers more rope.** This
   is the fold-017 MaxDD blowout mechanism: with no installed-stop
   ceiling triggered yet, V2 lets losing trades drift further before
   the 30-week-MA cross or other exit fires. In choppy 2018 conditions,
   this added drawdown without rescuing P&L.

3. **The scorer is the actual problem.** With 10×gate_fail dominating
   the BO objective, the search collapsed to "pick any not-disastrous
   config." The convergence chart shows running-best stuck at iter 1's
   random sample for 59 iterations — that's not optimization, that's
   a flat penalty landscape.

## Recommendation for next step

**Branch A — IMPLEMENT PR-2 of #1196 (Composite scorer) and run V3.**
This is the agreed path in `dev/notes/next-session-priorities-2026-05-21.md`
P0-reject branch. The composite scorer (Sharpe + Calmar + MaxDD weighted,
no CVaR per Q3) directly addresses why V2 failed: it would replace the
10×gate_fail penalty with a smooth multi-objective surface, giving BO
real gradients to climb.

V3 spec changes from V2:
- Same 4 knobs.
- Tighten `max_long_exposure_pct` lower bound back to 0.45 (V2's 0.33
  hurt trending years).
- Tighten `initial_stop_buffer` upper bound to 1.05 (V2's 1.072 caused
  fold-017 MaxDD blowout).
- Switch `objective` to `Composite` (PR-2 #1196).
- Worst-fold-penalty term in scorer (axis-2 directly enforced in BO,
  not just in promote-gate).

**Branch B — Stop tuning these 4 knobs and pivot to a different axis.**
The Bayesian search has now converged twice (v1: iter 26 winner; v2:
iter 1 winner) on configs that hit a ceiling near Sharpe 0.80 on this
universe. The aggregate improvement is real (+44% Sharpe vs cell-E)
but the per-fold safety floors keep tripping. Possible pivots:
- Sector concentration cap (M5.5 axis-4, dormant).
- Short-side margin (long+short hedged book).
- Universe expansion (Russell 3000 with PIT membership — see #1191
  random-universe v2 result; sample-size limitation #1180).

Branch A is the lower-risk continuation: it's already-designed work
(~300 LOC) and converts the V2 dataset (60 BO iters × walk_forward
metrics) into evidence about whether the scorer was the bottleneck.
Branch B is the higher-reward pivot if the composite scorer doesn't
move the needle either.

## Files

- `dev/experiments/bayesian-production-sweep-2026-05-18/output-v2-parallel4/`
  — V2 BO sweep output: `best.sexp`, `bo_log.csv` (60 iters),
  `convergence.md`, `oos_report.md`.
- `dev/experiments/bayesian-production-sweep-2026-05-18/v2-winner-fullrun/`
  — V2 winner re-run at full 31-fold resolution: `aggregate.sexp`,
  `fold_actuals.sexp`, `walk_forward_report.md`.
- `dev/experiments/bayesian-production-sweep-2026-05-18/walk_forward_v2_best.sexp`
  — the walk-forward spec used for the re-run (2 variants: cell-E +
  v2-winner).
- `dev/notes/bayesian-prod-v1-result-2026-05-20.md` — V1 result for
  comparison.
- `dev/plans/wire-spec-objective-into-score-cell-2026-05-18.md` —
  Branch A (PR-2) implementation plan.
