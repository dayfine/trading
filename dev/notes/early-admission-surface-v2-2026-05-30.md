# Early-admission surface (re-run on repaired data) — ACCEPT (mechanism), promotion held

**Date:** 2026-05-30 (PM, session 2)
**Supersedes the INCONCLUSIVE result in** `dev/notes/early-admission-surface-2026-05-30.md`
**Mechanism:** PR #1378 `Stage.config.early_admission_ma_period` (default-off).
**Verdict:** **ACCEPT the mechanism direction** — but no single period value generalises
cleanly; the global-default flip is deliberately held for review.

## What changed since the INCONCLUSIVE run

The first run was compromised by the `GSPC.INDX` golden only covering 2017-2026
(issue #1380) → the macro gate zeroed out 13 of 31 folds, so the surface only
tested 2017-2026. **This run repairs the golden** (prepended EODHD 2009-2016;
2017+ bytes untouched) so the macro gate trades across the full 2010-2026
window. Confirmation: 0 zero-trade folds (was 13), and the baseline now
**reconciles** with the canonical exit-timing baseline (Sharpe 0.62 / MaxDD 12.4
≈ exit-timing's 0.54 / 12.28) — proof the truncation was the artifact.

## Result — two independent windows

**15y (2010-2026, 31 folds, repaired golden):**

| Variant | Sharpe | Calmar | MaxDD% | Return% | Frontier | DSR |
|---|---:|---:|---:|---:|:--:|---:|
| baseline | 0.622 | 1.479 | 12.42 | 16.44 | no | — |
| ma=5 | 0.663 | 1.476 | 12.19 | 17.18 | no | — |
| ma=7 | 0.637 | 1.429 | 10.05 | 9.24 | **yes** | — |
| **ma=10** | **0.816** | 1.743 | 10.12 | 12.16 | **yes** | **1.0000** |
| ma=13 | 0.815 | 1.707 | 10.45 | 11.40 | no | — |

ma=10 best (24/31 Sharpe wins; on a >0.2 margin, 14 ma=10-wins vs 11 baseline-wins).

**5y (2019-2023, 9 folds, *different universe snapshot*, unaffected by the floor):**

| Variant | Sharpe | Calmar | MaxDD% | Return% | Frontier | DSR |
|---|---:|---:|---:|---:|:--:|---:|
| baseline | 0.435 | 0.679 | 14.17 | 7.25 | no | — |
| ma=5 | 0.410 | 1.082 | 15.54 | 7.85 | no | — |
| ma=7 | 0.606 | 1.109 | 14.95 | 11.41 | **yes** | — |
| ma=10 | 0.463 | 0.755 | 15.10 | 8.75 | no | — |
| **ma=13** | **0.615** | 1.083 | 13.56 | 10.93 | **yes** | 0.8977 |

## The two findings

1. **The mechanism direction GENERALISES (the ACCEPT).** Baseline is Pareto-
   *dominated* on **both** independent windows. This is the **first** mechanism
   in the experiment program to beat baseline out-of-window (exit-timing and
   hysteresis both *lost* on the long window). The edge is risk-reduction: early
   admission + holding on the fast MA turns several losing folds positive and
   cuts MaxDD (15y 10.1 vs 12.4; 5y 13.6 vs 14.2), at a modest return cost.

2. **No single period value generalises (why promotion is held).** The 15y
   DSR-1.0 winner **ma=10 does NOT generalise** — it collapses to ≈baseline on
   5y (0.463 vs 0.435). The best period is regime-dependent: ma=10 wins 15y,
   ma=13 wins 5y. **ma=7 is the only cell on the Pareto frontier of *both*
   windows** (but its 15y Sharpe edge is marginal, 0.637 vs 0.622); **ma=13** is
   the best cross-window *aggregate* (15y 0.815 ≈ best, 5y 0.615 best). ma=5 is
   weak on both. Promoting the headline ma=10 would repeat the single-window-
   overfit failure mode the loop exists to prevent.

## Promotion recommendation (held for review)

- **Do NOT auto-promote ma=10** (the 15y winner) — it does not generalise.
- If a single value is promoted, **ma=13** is the robust choice (best cross-
  window aggregate; risk-reduction holds on both), with **ma=7** the
  conservative both-frontier alternative.
- The global-default flip (`Stage.default_config.early_admission_ma_period`
  None → Some 13) is **high-stakes**: it re-baselines *every* golden (5y, 15y,
  custom-universe) and changes live-strategy behaviour. Held for explicit
  review + ideally one broader-universe confirmation to pin the period.

## Reproduction

15y spec: `early_admission_ma_period ∈ {5,7,10,13}`, Rolling 2010-2026
test_days=365 step_days=182 (31 folds), base
`goldens-sp500-historical/sp500-2010-2026.sexp`. 5y spec: same axes, Rolling
2019-2023 (9 folds), base `goldens-sp500/sp500-2019-2023.sexp`. Both run with
`TRADING_DATA_DIR` → repo `trading/test_data` (repaired GSPC golden). Ranked via
`Variant_ranking` (Pareto) + `Backtest_stats.Deflated_sharpe` (best-of-4).
