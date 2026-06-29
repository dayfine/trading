# Walk-forward CV report

## 1. Per-fold metrics

| Fold | Variant | Return % | CAGR % | Sharpe | MaxDD % | Calmar |
|------|---------|---------:|-------:|-------:|--------:|-------:|
| fold-000 | baseline | 17.03 | 8.19 | 0.513 | 21.13 | 0.388 |
| fold-001 | baseline | 12.85 | 6.24 | 0.495 | 15.56 | 0.401 |
| fold-002 | baseline | 51.08 | 22.93 | 1.609 | 7.58 | 3.029 |
| fold-003 | baseline | 10.66 | 5.20 | 0.446 | 11.16 | 0.466 |
| fold-004 | baseline | 9.52 | 4.66 | 0.373 | 19.06 | 0.245 |
| fold-005 | baseline | 4.70 | 2.32 | 0.229 | 18.46 | 0.126 |
| fold-006 | baseline | 35.52 | 16.42 | 1.476 | 8.61 | 1.911 |
| fold-007 | baseline | 7.42 | 3.65 | 0.431 | 9.76 | 0.374 |
| fold-008 | baseline | 33.72 | 15.65 | 1.256 | 7.78 | 2.015 |
| fold-009 | baseline | 2.95 | 1.47 | 0.176 | 19.44 | 0.075 |
| fold-010 | baseline | 34.69 | 16.07 | 0.969 | 12.69 | 1.269 |
| fold-011 | baseline | 20.65 | 9.85 | 0.936 | 10.80 | 0.913 |
| fold-012 | baseline | -9.42 | -4.83 | -0.242 | 30.20 | -0.160 |
| fold-000 | quality_ranking | -5.32 | -2.70 | -0.053 | 24.55 | -0.110 |
| fold-001 | quality_ranking | 12.08 | 5.87 | 0.496 | 14.06 | 0.418 |
| fold-002 | quality_ranking | 47.05 | 21.28 | 1.568 | 10.85 | 1.964 |
| fold-003 | quality_ranking | 15.61 | 7.53 | 0.598 | 11.50 | 0.655 |
| fold-004 | quality_ranking | 18.06 | 8.66 | 0.597 | 19.08 | 0.455 |
| fold-005 | quality_ranking | 8.80 | 4.31 | 0.349 | 18.12 | 0.238 |
| fold-006 | quality_ranking | 14.29 | 6.91 | 0.743 | 9.82 | 0.705 |
| fold-007 | quality_ranking | 10.20 | 4.98 | 0.567 | 8.86 | 0.563 |
| fold-008 | quality_ranking | 45.47 | 20.63 | 1.489 | 9.90 | 2.087 |
| fold-009 | quality_ranking | 4.39 | 2.17 | 0.229 | 13.57 | 0.160 |
| fold-010 | quality_ranking | 35.38 | 16.36 | 0.980 | 13.64 | 1.201 |
| fold-011 | quality_ranking | 11.83 | 5.75 | 0.581 | 13.36 | 0.431 |
| fold-012 | quality_ranking | 1.23 | 0.61 | 0.118 | 29.91 | 0.021 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| baseline | 17.80 ± 16.72 | 8.29 ± 7.64 | 0.667 ± 0.544 | 14.79 ± 6.64 | 0.850 ± 0.945 |
| quality_ranking | 16.85 ± 16.15 | 7.88 ± 7.32 | 0.636 ± 0.478 | 15.17 ± 6.24 | 0.676 ± 0.684 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 13 folds total; gate metric marked **\***):

| Variant | Sharpe wins* | Calmar wins | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|
| quality_ranking | 9 | 8 | 8 | 5 | 13 |

## 4. Go/no-go verdict

Gate: variant wins ≥7 of 13 folds on **Sharpe** vs baseline `baseline`, no fold worse by Δ>0.3000.

- **quality_ranking**: FAIL (9 / 13 wins; worst fold `fold-006` gap 0.7324). Reason: Δ-threshold miss: fold fold-006 trails by 0.7324 > Δ=0.3000