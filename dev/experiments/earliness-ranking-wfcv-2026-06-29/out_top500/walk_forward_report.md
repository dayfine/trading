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
| fold-000 | earliness_ranking | 0.55 | 0.27 | 0.107 | 24.84 | 0.011 |
| fold-001 | earliness_ranking | 12.45 | 6.05 | 0.497 | 14.08 | 0.430 |
| fold-002 | earliness_ranking | 11.31 | 5.51 | 0.491 | 9.62 | 0.573 |
| fold-003 | earliness_ranking | 26.15 | 12.33 | 0.911 | 10.34 | 1.194 |
| fold-004 | earliness_ranking | 15.11 | 7.29 | 0.536 | 19.14 | 0.382 |
| fold-005 | earliness_ranking | 8.22 | 4.03 | 0.331 | 20.41 | 0.198 |
| fold-006 | earliness_ranking | 12.24 | 5.95 | 0.690 | 7.02 | 0.849 |
| fold-007 | earliness_ranking | 13.11 | 6.36 | 0.680 | 12.10 | 0.526 |
| fold-008 | earliness_ranking | 34.87 | 16.14 | 1.369 | 10.12 | 1.598 |
| fold-009 | earliness_ranking | 11.69 | 5.69 | 0.494 | 11.52 | 0.494 |
| fold-010 | earliness_ranking | 53.81 | 24.04 | 1.258 | 17.03 | 1.413 |
| fold-011 | earliness_ranking | 19.91 | 9.51 | 0.861 | 12.01 | 0.793 |
| fold-012 | earliness_ranking | 4.18 | 2.07 | 0.210 | 26.54 | 0.078 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| baseline | 17.80 ± 16.72 | 8.29 ± 7.64 | 0.667 ± 0.544 | 14.79 ± 6.64 | 0.850 ± 0.945 |
| earliness_ranking | 17.20 ± 14.14 | 8.09 ± 6.31 | 0.649 ± 0.374 | 14.98 ± 6.12 | 0.657 ± 0.495 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 13 folds total; gate metric marked **\***):

| Variant | Sharpe wins* | Calmar wins | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|
| earliness_ranking | 9 | 8 | 8 | 5 | 13 |

## 4. Go/no-go verdict

Gate: variant wins ≥7 of 13 folds on **Sharpe** vs baseline `baseline`, no fold worse by Δ>0.3000.

- **earliness_ranking**: FAIL (9 / 13 wins; worst fold `fold-002` gap 1.1178). Reason: Δ-threshold miss: fold fold-002 trails by 1.1178 > Δ=0.3000