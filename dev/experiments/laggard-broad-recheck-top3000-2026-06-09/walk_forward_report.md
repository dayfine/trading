# Walk-forward CV report

## 1. Per-fold metrics

| Fold | Variant | Return % | CAGR % | Sharpe | MaxDD % | Calmar |
|------|---------|---------:|-------:|-------:|--------:|-------:|
| fold-000 | baseline | -11.93 | -11.93 | -0.770 | 22.80 | -0.525 |
| fold-001 | baseline | 5.90 | 5.90 | 1.311 | 10.16 | 2.386 |
| fold-002 | baseline | 33.21 | 33.24 | 1.842 | 8.86 | 3.213 |
| fold-003 | baseline | 2.03 | 2.04 | -0.302 | 15.99 | -0.326 |
| fold-004 | baseline | 8.86 | 8.87 | 1.281 | 7.41 | 2.765 |
| fold-005 | baseline | 6.77 | 6.78 | 0.613 | 10.88 | 0.912 |
| fold-006 | baseline | 24.72 | 24.74 | 2.478 | 4.84 | 6.431 |
| fold-007 | baseline | 2.19 | 2.19 | -0.611 | 18.30 | -0.696 |
| fold-008 | baseline | -0.94 | -0.95 | 1.384 | 5.74 | 3.563 |
| fold-009 | baseline | 30.69 | 30.71 | 0.756 | 24.63 | 0.689 |
| fold-010 | baseline | 76.33 | 76.40 | 0.654 | 16.28 | 0.701 |
| fold-011 | baseline | -19.01 | -19.02 | -1.350 | 22.63 | -0.895 |
| fold-012 | baseline | 3.44 | 3.44 | 1.216 | 16.26 | 1.366 |
| fold-013 | baseline | 15.77 | 15.78 | 0.444 | 7.61 | 0.646 |
| fold-014 | baseline | 16.22 | 16.23 | 0.698 | 29.47 | 0.496 |
| fold-000 | enable_laggard_rotation=false | -14.26 | -14.27 | -0.673 | 22.85 | -0.626 |
| fold-001 | enable_laggard_rotation=false | -20.22 | -20.23 | 0.077 | 18.52 | -0.023 |
| fold-002 | enable_laggard_rotation=false | 25.65 | 25.67 | 1.777 | 5.95 | 3.705 |
| fold-003 | enable_laggard_rotation=false | -1.31 | -1.31 | -0.473 | 20.89 | -0.409 |
| fold-004 | enable_laggard_rotation=false | 20.21 | 20.22 | 1.565 | 9.83 | 3.435 |
| fold-005 | enable_laggard_rotation=false | 4.87 | 4.87 | 0.514 | 13.98 | 0.565 |
| fold-006 | enable_laggard_rotation=false | 14.57 | 14.58 | 1.354 | 6.20 | 2.950 |
| fold-007 | enable_laggard_rotation=false | -8.37 | -8.38 | -1.032 | 28.78 | -0.728 |
| fold-008 | enable_laggard_rotation=false | 8.04 | 8.04 | 1.769 | 5.47 | 5.182 |
| fold-009 | enable_laggard_rotation=false | 12.44 | 12.45 | 0.339 | 24.17 | 0.225 |
| fold-010 | enable_laggard_rotation=false | 93.99 | 94.08 | 1.663 | 10.13 | 3.889 |
| fold-011 | enable_laggard_rotation=false | -21.82 | -21.83 | -1.527 | 24.24 | -0.912 |
| fold-012 | enable_laggard_rotation=false | -19.70 | -19.71 | -0.214 | 18.77 | -0.277 |
| fold-013 | enable_laggard_rotation=false | 24.56 | 24.57 | 1.180 | 9.85 | 1.680 |
| fold-014 | enable_laggard_rotation=false | 29.98 | 30.01 | 1.016 | 28.01 | 0.768 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| baseline | 12.95 ± 22.62 | 12.96 ± 22.64 | 0.643 ± 1.036 | 14.79 ± 7.63 | 1.382 ± 1.983 |
| enable_laggard_rotation=false | 9.91 ± 29.20 | 9.92 ± 29.22 | 0.489 ± 1.091 | 16.51 ± 8.22 | 1.295 ± 2.015 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 15 folds total; gate metric marked **\***):

| Variant | Sharpe wins* | Calmar wins | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|
| enable_laggard_rotation=false | 6 | 6 | 5 | 5 | 15 |

## 4. Go/no-go verdict

Gate: variant wins ≥8 of 14 folds on **Sharpe** vs baseline `baseline`, no fold worse by Δ>0.2000.

- **enable_laggard_rotation=false**: SKIPPED — fold-pair count mismatch: measured 15, gate expects 14