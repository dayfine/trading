# Walk-forward CV report

## 1. Per-fold metrics

| Fold | Variant | Return % | CAGR % | Sharpe | MaxDD % | Calmar |
|------|---------|---------:|-------:|-------:|--------:|-------:|
| fold-000 | baseline | 32.91 | 15.30 | 0.944 | 14.55 | 1.053 |
| fold-001 | baseline | 8.95 | 4.38 | 0.339 | 25.82 | 0.170 |
| fold-002 | baseline | 39.24 | 18.01 | 1.339 | 15.49 | 1.165 |
| fold-003 | baseline | 16.47 | 7.93 | 0.549 | 20.72 | 0.383 |
| fold-004 | baseline | 5.63 | 2.78 | 0.274 | 21.60 | 0.129 |
| fold-005 | baseline | 13.74 | 6.65 | 0.466 | 15.16 | 0.440 |
| fold-006 | baseline | 22.05 | 10.48 | 0.911 | 10.83 | 0.969 |
| fold-007 | baseline | 22.09 | 10.50 | 1.000 | 7.11 | 1.479 |
| fold-008 | baseline | 31.07 | 14.50 | 1.116 | 12.53 | 1.159 |
| fold-009 | baseline | 4.74 | 2.34 | 0.240 | 17.55 | 0.134 |
| fold-010 | baseline | 44.89 | 20.39 | 1.156 | 11.69 | 1.747 |
| fold-011 | baseline | 11.63 | 5.66 | 0.526 | 18.60 | 0.305 |
| fold-012 | baseline | -10.57 | -5.43 | -0.281 | 33.09 | -0.164 |
| fold-000 | hash_random | 3.88 | 1.92 | 0.200 | 15.69 | 0.123 |
| fold-001 | hash_random | 12.22 | 5.94 | 0.436 | 25.06 | 0.237 |
| fold-002 | hash_random | 7.56 | 3.72 | 0.349 | 17.64 | 0.211 |
| fold-003 | hash_random | 8.28 | 4.06 | 0.335 | 19.49 | 0.209 |
| fold-004 | hash_random | 3.81 | 1.89 | 0.207 | 19.83 | 0.095 |
| fold-005 | hash_random | 0.15 | 0.07 | 0.079 | 14.27 | 0.005 |
| fold-006 | hash_random | 25.92 | 12.22 | 1.111 | 11.46 | 1.068 |
| fold-007 | hash_random | 8.71 | 4.27 | 0.453 | 8.58 | 0.498 |
| fold-008 | hash_random | 27.14 | 12.77 | 1.050 | 9.38 | 1.363 |
| fold-009 | hash_random | 8.14 | 3.99 | 0.348 | 16.35 | 0.245 |
| fold-010 | hash_random | 38.46 | 17.68 | 1.019 | 11.36 | 1.559 |
| fold-011 | hash_random | -5.67 | -2.88 | -0.165 | 23.51 | -0.123 |
| fold-012 | hash_random | -13.65 | -7.08 | -0.380 | 31.22 | -0.227 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| baseline | 18.68 ± 15.50 | 8.73 ± 7.16 | 0.660 ± 0.462 | 17.29 ± 6.89 | 0.690 ± 0.600 |
| hash_random | 9.61 ± 14.00 | 4.51 ± 6.62 | 0.388 ± 0.450 | 17.22 ± 6.61 | 0.405 ± 0.566 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 13 folds total; gate metric marked **\***):

| Variant | Sharpe wins* | Calmar wins | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|
| hash_random | 3 | 4 | 3 | 8 | 13 |

## 4. Go/no-go verdict

Gate: variant wins ≥7 of 13 folds on **Sharpe** vs baseline `baseline`, no fold worse by Δ>0.3000.

- **hash_random**: FAIL (3 / 13 wins; worst fold `fold-002` gap 0.9896). Reason: M-threshold miss: 3 wins < 7 required; worst fold fold-002 trails by 0.9896 > Δ=0.3000