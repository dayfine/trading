# Walk-forward CV report

## 1. Per-fold metrics

| Fold | Variant | Return % | CAGR % | Sharpe | MaxDD % | Calmar |
|------|---------|---------:|-------:|-------:|--------:|-------:|
| fold-000 | baseline | 80.19 | 34.26 | 1.321 | 12.50 | 2.745 |
| fold-001 | baseline | 23.48 | 11.13 | 0.995 | 10.10 | 1.104 |
| fold-002 | baseline | 146.10 | 56.92 | 2.820 | 9.37 | 6.084 |
| fold-003 | baseline | 36.51 | 16.85 | 1.038 | 15.66 | 1.077 |
| fold-004 | baseline | 6.06 | 2.99 | 0.296 | 15.07 | 0.199 |
| fold-005 | baseline | 19.48 | 9.31 | 0.676 | 15.06 | 0.619 |
| fold-006 | baseline | 52.21 | 23.39 | 1.505 | 13.02 | 1.798 |
| fold-007 | baseline | 25.37 | 11.98 | 1.007 | 9.25 | 1.297 |
| fold-008 | baseline | 65.58 | 28.70 | 1.923 | 9.25 | 3.108 |
| fold-009 | baseline | -8.84 | -4.53 | -0.334 | 17.28 | -0.262 |
| fold-010 | baseline | 22.54 | 10.70 | 0.583 | 22.14 | 0.484 |
| fold-011 | baseline | -7.24 | -3.69 | -0.183 | 25.57 | -0.144 |
| fold-012 | baseline | 7.79 | 3.83 | 0.348 | 19.04 | 0.201 |
| fold-000 | scale_in_pullback | 55.22 | 24.61 | 1.356 | 8.44 | 2.919 |
| fold-001 | scale_in_pullback | 17.59 | 8.44 | 0.818 | 11.05 | 0.765 |
| fold-002 | scale_in_pullback | 55.02 | 24.53 | 1.598 | 11.94 | 2.058 |
| fold-003 | scale_in_pullback | 26.76 | 12.60 | 0.813 | 13.72 | 0.920 |
| fold-004 | scale_in_pullback | -0.52 | -0.26 | 0.041 | 19.52 | -0.013 |
| fold-005 | scale_in_pullback | 22.05 | 10.48 | 0.725 | 18.90 | 0.556 |
| fold-006 | scale_in_pullback | 31.43 | 14.65 | 1.181 | 7.81 | 1.880 |
| fold-007 | scale_in_pullback | 13.53 | 6.56 | 0.627 | 9.47 | 0.693 |
| fold-008 | scale_in_pullback | 71.50 | 30.98 | 2.328 | 8.00 | 3.879 |
| fold-009 | scale_in_pullback | 8.68 | 4.25 | 0.344 | 10.61 | 0.401 |
| fold-010 | scale_in_pullback | 2.45 | 1.22 | 0.154 | 22.06 | 0.055 |
| fold-011 | scale_in_pullback | -15.51 | -8.08 | -0.528 | 24.72 | -0.328 |
| fold-012 | scale_in_pullback | 15.79 | 7.61 | 0.618 | 18.80 | 0.405 |
| fold-000 | scale_in_either | 55.22 | 24.61 | 1.356 | 8.44 | 2.919 |
| fold-001 | scale_in_either | 17.59 | 8.44 | 0.818 | 11.05 | 0.765 |
| fold-002 | scale_in_either | 55.02 | 24.53 | 1.598 | 11.94 | 2.058 |
| fold-003 | scale_in_either | 26.76 | 12.60 | 0.813 | 13.72 | 0.920 |
| fold-004 | scale_in_either | -0.52 | -0.26 | 0.041 | 19.52 | -0.013 |
| fold-005 | scale_in_either | 22.05 | 10.48 | 0.725 | 18.90 | 0.556 |
| fold-006 | scale_in_either | 31.43 | 14.65 | 1.181 | 7.81 | 1.880 |
| fold-007 | scale_in_either | 13.53 | 6.56 | 0.627 | 9.47 | 0.693 |
| fold-008 | scale_in_either | 71.50 | 30.98 | 2.328 | 8.00 | 3.879 |
| fold-009 | scale_in_either | 8.68 | 4.25 | 0.344 | 10.61 | 0.401 |
| fold-010 | scale_in_either | 2.45 | 1.22 | 0.154 | 22.06 | 0.055 |
| fold-011 | scale_in_either | -15.51 | -8.08 | -0.528 | 24.72 | -0.328 |
| fold-012 | scale_in_either | 15.79 | 7.61 | 0.618 | 18.80 | 0.405 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| baseline | 36.09 ± 42.34 | 15.53 ± 16.98 | 0.923 ± 0.858 | 14.87 ± 5.13 | 1.408 ± 1.744 |
| scale_in_pullback | 23.39 ± 24.72 | 10.58 ± 11.00 | 0.775 ± 0.733 | 14.23 ± 5.82 | 1.092 ± 1.242 |
| scale_in_either | 23.39 ± 24.72 | 10.58 ± 11.00 | 0.775 ± 0.733 | 14.23 ± 5.82 | 1.092 ± 1.242 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 13 folds total; gate metric marked **\***):

| Variant | Sharpe wins* | Calmar wins | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|
| scale_in_pullback | 5 | 5 | 4 | 8 | 13 |
| scale_in_either | 5 | 5 | 4 | 8 | 13 |

## 4. Go/no-go verdict

Gate: variant wins ≥7 of 13 folds on **Sharpe** vs baseline `baseline`, no fold worse by Δ>0.3000.

- **scale_in_pullback**: FAIL (5 / 13 wins; worst fold `fold-002` gap 1.2221). Reason: M-threshold miss: 5 wins < 7 required; worst fold fold-002 trails by 1.2221 > Δ=0.3000
- **scale_in_either**: FAIL (5 / 13 wins; worst fold `fold-002` gap 1.2221). Reason: M-threshold miss: 5 wins < 7 required; worst fold fold-002 trails by 1.2221 > Δ=0.3000