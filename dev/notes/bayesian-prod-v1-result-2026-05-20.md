# Bayesian production v1 result (2026-05-20)

V1 of the production Bayesian sweep completed overnight. This doc
captures the winner, the promote-gate evaluation per plan §6, and the
v2 recommendation.

## What ran

- **Spec**: `dev/experiments/bayesian-production-sweep-2026-05-18/spec_prod.sexp`
  - 4 knobs: `portfolio_config.max_position_pct_long` ∈ [0.05, 0.20],
    `portfolio_config.max_long_exposure_pct` ∈ [0.50, 0.95],
    `initial_stop_buffer` ∈ [1.00, 1.10],
    `screening_config.candidate_params.installed_stop_min_pct` ∈ [0.04, 0.15].
  - `acquisition` = Expected_improvement
  - `initial_random` = 10, `total_budget` = 60, `seed` = 2026
  - `objective` = Sharpe (shipped scorer: mean_sharpe − 0.1 × max(0,
    cand_maxdd − base_maxdd) − 10 × gate_fail)
  - `holdout_folds` = (27 28 29 30)
- **Walk-forward fixture**: `cell_e_30fold_2026_05_16.sexp` (31 folds,
  rolling 365d test, 182d step over 2010-01-01..2026-04-30).
- **Wall**: ~11.5 hours at parallel=4 (3720 BO backtests + 62 OOS
  re-run backtests = 3782 total).

## Winner (iter 26)

| Knob | Value | Bound | Note |
|---|---:|---|---|
| `max_position_pct_long` | **0.054** | [0.05, 0.20] | at lower bound |
| `max_long_exposure_pct` | **0.516** | [0.50, 0.95] | at lower bound |
| `initial_stop_buffer` | **1.007** | [1.00, 1.10] | at lower bound |
| `installed_stop_min_pct` | 0.127 | [0.04, 0.15] | upper-mid |

The winner clusters at the LOWER bounds of 3 of 4 knobs. Interpretation:
- Smaller positions (~5% max each).
- Lower total long exposure (~52% net).
- Tighter initial stop (just-above-zero buffer).
- Wider installed minimum stop (~13% breathing room post-entry).

This is a "fewer + smaller + tighter-entry-stop-but-wider-installed-stop"
regime. The fact that 3 knobs are at the LOWER bound suggests the
search wants to go BELOW these bounds; v2 should widen.

## Headline metrics (31 folds, full sp500-2010-2026 window)

| Metric | cell-E baseline | v1-winner | Δ |
|---|---:|---:|---:|
| Mean Sharpe | 0.560 | **0.796** | **+0.236** (+42%) |
| Median Sharpe | 0.462 | **0.802** | **+0.340** |
| Mean CAGR % | 8.75 | **11.98** | **+3.23pp** |
| Mean MaxDD % | 11.98 | **10.57** | **-1.41pp** |
| Mean Calmar | 1.310 | **1.837** | **+0.527** |
| Sharpe wins | — | **19 / 31** | majority |
| Sharpe stdev | 1.064 | 1.078 | ~flat |

The mean improvements are substantial — +0.24 Sharpe is a meaningful
risk-adjusted upgrade, +3.2pp CAGR is a big move, and MaxDD doesn't
worsen.

## 5-axis promote-gate (plan §6)

| # | Axis | v1-winner result | Verdict |
|---|---|---|---|
| 1 | Median composite ≥ baseline + 0.05 | +0.340 Sharpe vs hurdle +0.05 | **PASS** |
| 2 | No fold worse by >0.10 Sharpe | **6 folds worse by >0.10** | **FAIL** |
| 3 | OOS Sharpe ≥ 0.50 every fold | fold-028 = 0.498, **fold-029 = -0.855** | **FAIL** |
| 4 | MaxDD ≤ baseline + 5pp every fold | Max diff +4.10pp (fold-019) | **PASS** |
| 5 | N_trades within 2× baseline | Data not in current report | **TBD** |

### Axis 2 detail (folds where v1-winner is worse than cell-E by >0.10 Sharpe)

| Fold | cell-E Sharpe | v1-winner Sharpe | Δ |
|---|---:|---:|---:|
| 004 (2012-01-04..2013-01-02) | 1.171 | 0.334 | -0.837 |
| 010 (2015-01-02..2015-12-31) | 0.851 | -0.071 | -0.922 |
| 011 (2015-07-04..2016-07-02) | 0.072 | -0.634 | -0.706 |
| 017 (2018-07-01..2019-06-30) | 0.274 | -0.494 | -0.768 |
| 019 (2019-06-30..2020-06-28) | -0.355 | -0.728 | -0.373 |
| 028 (2024-01-03..2024-12-30) | 0.703 | 0.498 | -0.205 |

The pattern: v1-winner loses harder in late-cycle / topping years
(2015, 2018-2019, 2024) while winning bigger in trending years.
Consistent with the tighter-entry-stop / lower-exposure regime —
fewer chances to recover from mid-cycle drawdowns.

### Axis 3 detail (OOS folds 27-30, the held-out tail)

Note the bayesian_runner's `Oos_validator` reported **ACCEPT** because
it uses a softer rule (within-0.10-gap of in-sample mean). Plan §6's
"every OOS fold ≥ 0.50" is stricter and fails here.

| Fold | v1-winner Sharpe | Verdict |
|---|---:|---|
| 026 (2023-07-02..2024-06-30) | 1.409 | ✓ |
| 027 (2024-01-03..2024-12-30) | 1.985 | ✓ |
| 028 (2024-07-04..2025-07-03) | 0.498 | **borderline** — 0.002 below hurdle |
| 029 (2025-01-04..2026-01-03) | -0.855 | **FAIL** — large negative |
| 030 (2025-07-06..2026-04-30, truncated) | 0.957 | ✓ |

Note: oos_report.md indexes 026-029 (4 folds), plan indexes 27-30
(probably 1-indexed). The substance is the same — the held-out
2024-2026 window has at least one big fail.

## Verdict

**REJECT per plan §6 strict 5-axis gate.** The winner shows real
aggregate improvement (Sharpe +43%, CAGR +37%, MaxDD better) but
fails the "no fold left behind" + "every OOS fold ≥ 0.50" tests.
Six folds are >0.10 Sharpe worse than baseline, including a hard
late-2025 OOS failure (-0.855).

## V2 recommendations

1. **Widen knob bounds**. Three of four knobs converged to the LOWER
   bound — the BO wants to go below. Open:
   - `max_position_pct_long` lower from 0.05 → 0.02
   - `max_long_exposure_pct` lower from 0.50 → 0.30
   - `initial_stop_buffer` lower from 1.00 → 0.97 (i.e., stop ABOVE
     entry — a "no slippage on entry" mode)

2. **Reconsider the objective**. The shipped scorer is single-term
   Sharpe with a maxdd soft-floor. Plan #1196 (Composite scorer) is
   load-bearing for axis 2 — adding a "worst-fold-penalty" term would
   shape the BO to avoid the 6 fold-losers. Implement the 3-term
   Composite (Sharpe + Calmar + MaxDD weights, no CVaR) from #1196
   and re-run.

3. **Investigate the 6 bad folds + fold-029 OOS**. Per the
   hold-period deep-dive findings (dev/plans/hold-period-deep-dive-2026-05-19.md),
   stop_loss exits are net-negative drag (-1239pp aggregate). The bad
   folds may share a common pattern (frequent topping signals →
   whipsaw stop_loss). Reading the trades.csv for those folds is the
   quickest follow-up. Add to v2's hypothesis list.

4. **Defer to v2 before promoting**. Don't ship the v1 winner to
   `dayfine/trading-configs-private` yet — the axis 2/3 failures are
   real risk-management concerns.

## What landed alongside this result

- #1207 Shiller M1 cross-cycle validation (1871-2025 monthly Weinstein
  reduction). Key finding: at MA=10 the stage framework beats B&H on
  every dimension over 155y.
- #1209 Kenneth French 49-Industry daily ingest (M2 PR-C). Next:
  M2 PR-D (rotation strategy) on top.

## Files

- `dev/experiments/bayesian-production-sweep-2026-05-18/output-v1-parallel4/`
  — full BO sweep output: `best.sexp`, `bo_log.csv`, `convergence.md`,
  `oos_report.md`.
- `dev/experiments/bayesian-production-sweep-2026-05-18/v1-winner-fullrun/`
  — winner re-run at full 31-fold resolution: `aggregate.sexp`,
  `fold_actuals.sexp`, `walk_forward_report.md`.
- `dev/experiments/bayesian-production-sweep-2026-05-18/walk_forward_v1_best.sexp`
  — the walk-forward spec used for the re-run (2 variants: cell-E +
  v1-winner).
