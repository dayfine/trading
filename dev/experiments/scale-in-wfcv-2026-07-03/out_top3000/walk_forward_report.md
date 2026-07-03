# Walk-forward CV report

## 1. Per-fold metrics

| Fold | Variant | Return % | CAGR % | Sharpe | MaxDD % | Calmar |
|------|---------|---------:|-------:|-------:|--------:|-------:|
| fold-000 | baseline | 5.39 | 2.66 | 0.254 | 10.28 | 0.259 |
| fold-001 | baseline | 12.24 | 5.95 | 0.489 | 12.81 | 0.465 |
| fold-002 | baseline | 4.75 | 2.35 | 0.234 | 15.85 | 0.148 |
| fold-003 | baseline | 36.32 | 16.77 | 1.087 | 14.18 | 1.184 |
| fold-004 | baseline | 18.71 | 8.96 | 0.616 | 15.38 | 0.583 |
| fold-005 | baseline | 20.72 | 9.88 | 0.611 | 15.58 | 0.635 |
| fold-006 | baseline | 33.66 | 15.62 | 1.190 | 12.29 | 1.273 |
| fold-007 | baseline | 30.15 | 14.10 | 1.157 | 8.90 | 1.586 |
| fold-008 | baseline | 16.56 | 7.97 | 0.576 | 16.30 | 0.489 |
| fold-009 | baseline | 17.97 | 8.62 | 0.558 | 11.24 | 0.768 |
| fold-010 | baseline | 71.99 | 31.17 | 1.296 | 18.45 | 1.692 |
| fold-011 | baseline | -10.20 | -5.24 | -0.421 | 23.64 | -0.222 |
| fold-012 | baseline | 0.69 | 0.34 | 0.112 | 24.75 | 0.014 |
| fold-000 | scale_in_pullback | 19.47 | 9.31 | 0.638 | 15.85 | 0.588 |
| fold-001 | scale_in_pullback | 43.91 | 19.98 | 1.311 | 14.26 | 1.403 |
| fold-002 | scale_in_pullback | 21.81 | 10.37 | 0.753 | 11.45 | 0.907 |
| fold-003 | scale_in_pullback | 8.94 | 4.38 | 0.382 | 12.57 | 0.349 |
| fold-004 | scale_in_pullback | 12.54 | 6.09 | 0.455 | 12.49 | 0.488 |
| fold-005 | scale_in_pullback | 15.30 | 7.38 | 0.516 | 11.77 | 0.628 |
| fold-006 | scale_in_pullback | 40.57 | 18.57 | 1.383 | 9.29 | 2.002 |
| fold-007 | scale_in_pullback | 14.13 | 6.83 | 0.679 | 9.88 | 0.693 |
| fold-008 | scale_in_pullback | 22.41 | 10.65 | 0.827 | 12.39 | 0.860 |
| fold-009 | scale_in_pullback | 12.54 | 6.09 | 0.443 | 12.36 | 0.493 |
| fold-010 | scale_in_pullback | 64.90 | 28.43 | 1.257 | 20.93 | 1.361 |
| fold-011 | scale_in_pullback | -9.39 | -4.81 | -0.409 | 23.34 | -0.207 |
| fold-012 | scale_in_pullback | -6.02 | -3.06 | -0.137 | 25.26 | -0.121 |
| fold-000 | scale_in_either_loose | 18.95 | 9.07 | 0.622 | 15.85 | 0.573 |
| fold-001 | scale_in_either_loose | 38.51 | 17.70 | 1.198 | 14.26 | 1.244 |
| fold-002 | scale_in_either_loose | 25.01 | 11.82 | 0.839 | 11.45 | 1.034 |
| fold-003 | scale_in_either_loose | 6.84 | 3.37 | 0.312 | 12.38 | 0.272 |
| fold-004 | scale_in_either_loose | 14.02 | 6.78 | 0.501 | 12.49 | 0.544 |
| fold-005 | scale_in_either_loose | 8.16 | 4.00 | 0.322 | 12.46 | 0.322 |
| fold-006 | scale_in_either_loose | 48.00 | 21.67 | 1.564 | 9.88 | 2.196 |
| fold-007 | scale_in_either_loose | 17.30 | 8.31 | 0.835 | 8.00 | 1.041 |
| fold-008 | scale_in_either_loose | 17.01 | 8.18 | 0.656 | 12.66 | 0.647 |
| fold-009 | scale_in_either_loose | 14.96 | 7.23 | 0.496 | 12.84 | 0.564 |
| fold-010 | scale_in_either_loose | 54.74 | 24.41 | 1.212 | 15.87 | 1.541 |
| fold-011 | scale_in_either_loose | -1.78 | -0.89 | -0.031 | 18.64 | -0.048 |
| fold-012 | scale_in_either_loose | -0.29 | -0.15 | 0.079 | 23.84 | -0.006 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| baseline | 19.92 ± 20.55 | 9.16 ± 9.11 | 0.597 ± 0.494 | 15.36 ± 4.74 | 0.683 ± 0.596 |
| scale_in_pullback | 20.08 ± 20.11 | 9.25 ± 9.02 | 0.623 ± 0.523 | 14.76 ± 5.15 | 0.727 ± 0.606 |
| scale_in_either_loose | 20.11 ± 17.41 | 9.35 ± 7.79 | 0.662 ± 0.463 | 13.89 ± 4.03 | 0.763 ± 0.637 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 13 folds total; gate metric marked **\***):

| Variant | Sharpe wins* | Calmar wins | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|
| scale_in_pullback | 6 | 6 | 6 | 7 | 13 |
| scale_in_either_loose | 6 | 6 | 6 | 10 | 13 |

## 4. Go/no-go verdict

Gate: variant wins ≥7 of 13 folds on **Sharpe** vs baseline `baseline`, no fold worse by Δ>0.3000.

- **scale_in_pullback**: FAIL (6 / 13 wins; worst fold `fold-003` gap 0.7043). Reason: M-threshold miss: 6 wins < 7 required; worst fold fold-003 trails by 0.7043 > Δ=0.3000
- **scale_in_either_loose**: FAIL (6 / 13 wins; worst fold `fold-003` gap 0.7747). Reason: M-threshold miss: 6 wins < 7 required; worst fold fold-003 trails by 0.7747 > Δ=0.3000