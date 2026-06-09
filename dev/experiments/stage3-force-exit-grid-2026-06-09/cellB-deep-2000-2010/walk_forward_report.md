# Walk-forward CV report

## 1. Per-fold metrics

| Fold | Variant | Return % | CAGR % | Sharpe | MaxDD % | Calmar |
|------|---------|---------:|-------:|-------:|--------:|-------:|
| fold-000 | force_exit_off | 82.57 | 82.64 | 2.365 | 6.13 | 13.531 |
| fold-001 | force_exit_off | 2.51 | 2.52 | 0.330 | 7.82 | 0.322 |
| fold-002 | force_exit_off | -5.10 | -5.11 | -0.276 | 16.57 | -0.309 |
| fold-003 | force_exit_off | 26.43 | 26.45 | 1.529 | 11.39 | 2.329 |
| fold-004 | force_exit_off | 17.85 | 17.87 | 1.309 | 9.34 | 1.919 |
| fold-005 | force_exit_off | 30.39 | 30.41 | 2.046 | 8.27 | 3.689 |
| fold-006 | force_exit_off | 10.20 | 10.21 | 0.836 | 11.88 | 0.862 |
| fold-007 | force_exit_off | 15.30 | 15.31 | 0.853 | 15.37 | 0.999 |
| fold-008 | force_exit_off | -8.14 | -8.15 | -0.779 | 13.48 | -0.606 |
| fold-009 | force_exit_off | 6.85 | 6.85 | 0.436 | 13.13 | 0.523 |
| fold-010 | force_exit_off | 17.96 | 17.97 | 1.075 | 11.13 | 1.620 |
| fold-000 | baseline | 82.57 | 82.64 | 2.365 | 6.13 | 13.531 |
| fold-001 | baseline | 2.51 | 2.52 | 0.330 | 7.82 | 0.322 |
| fold-002 | baseline | -5.10 | -5.11 | -0.276 | 16.57 | -0.309 |
| fold-003 | baseline | 26.43 | 26.45 | 1.529 | 11.39 | 2.329 |
| fold-004 | baseline | 17.85 | 17.87 | 1.309 | 9.34 | 1.919 |
| fold-005 | baseline | 30.39 | 30.41 | 2.046 | 8.27 | 3.689 |
| fold-006 | baseline | 10.20 | 10.21 | 0.836 | 11.88 | 0.862 |
| fold-007 | baseline | 15.30 | 15.31 | 0.853 | 15.37 | 0.999 |
| fold-008 | baseline | -8.14 | -8.15 | -0.779 | 13.48 | -0.606 |
| fold-009 | baseline | 6.85 | 6.85 | 0.436 | 13.13 | 0.523 |
| fold-010 | baseline | 17.96 | 17.97 | 1.075 | 11.13 | 1.620 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| force_exit_off | 17.89 ± 24.58 | 17.91 ± 24.60 | 0.884 ± 0.938 | 11.32 ± 3.24 | 2.262 ± 3.934 |
| baseline | 17.89 ± 24.58 | 17.91 ± 24.60 | 0.884 ± 0.938 | 11.32 ± 3.24 | 2.262 ± 3.934 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 11 folds total; gate metric marked **\***):

| Variant | Sharpe wins* | Calmar wins | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|
| force_exit_off | 0 | 0 | 0 | 0 | 11 |

## 4. Go/no-go verdict

Gate: variant wins ≥6 of 10 folds on **Sharpe** vs baseline `baseline`, no fold worse by Δ>0.3000.

- **force_exit_off**: SKIPPED — fold-pair count mismatch: measured 11, gate expects 10