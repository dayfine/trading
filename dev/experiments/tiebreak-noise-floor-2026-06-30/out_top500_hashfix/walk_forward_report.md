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
| fold-000 | hash_random | 12.91 | 6.27 | 0.426 | 20.93 | 0.300 |
| fold-001 | hash_random | 4.42 | 2.19 | 0.225 | 15.44 | 0.142 |
| fold-002 | hash_random | 4.97 | 2.46 | 0.261 | 12.77 | 0.193 |
| fold-003 | hash_random | 10.18 | 4.97 | 0.439 | 10.33 | 0.482 |
| fold-004 | hash_random | 22.84 | 10.84 | 0.731 | 18.34 | 0.592 |
| fold-005 | hash_random | 11.97 | 5.82 | 0.439 | 14.66 | 0.398 |
| fold-006 | hash_random | 40.03 | 18.35 | 1.638 | 7.04 | 2.610 |
| fold-007 | hash_random | 15.27 | 7.37 | 0.817 | 8.48 | 0.870 |
| fold-008 | hash_random | 35.76 | 16.53 | 1.346 | 7.11 | 2.329 |
| fold-009 | hash_random | 4.71 | 2.33 | 0.240 | 17.39 | 0.134 |
| fold-010 | hash_random | 30.74 | 14.35 | 0.860 | 13.69 | 1.050 |
| fold-011 | hash_random | 21.21 | 10.10 | 0.887 | 11.94 | 0.847 |
| fold-012 | hash_random | -2.71 | -1.36 | 0.008 | 30.60 | -0.045 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| baseline | 17.80 ± 16.72 | 8.29 ± 7.64 | 0.667 ± 0.544 | 14.79 ± 6.64 | 0.850 ± 0.945 |
| hash_random | 16.33 ± 13.07 | 7.71 ± 6.01 | 0.640 ± 0.470 | 14.52 ± 6.45 | 0.762 ± 0.826 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 13 folds total; gate metric marked **\***):

| Variant | Sharpe wins* | Calmar wins | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|
| hash_random | 7 | 8 | 8 | 9 | 13 |

## 4. Go/no-go verdict

Gate: variant wins ≥7 of 13 folds on **Sharpe** vs baseline `baseline`, no fold worse by Δ>0.3000.

- **hash_random**: FAIL (7 / 13 wins; worst fold `fold-002` gap 1.3480). Reason: Δ-threshold miss: fold fold-002 trails by 1.3480 > Δ=0.3000