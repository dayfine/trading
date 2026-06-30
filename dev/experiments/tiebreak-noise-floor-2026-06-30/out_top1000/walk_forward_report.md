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
| fold-000 | reverse_alpha | 19.67 | 9.40 | 0.758 | 17.39 | 0.541 |
| fold-001 | reverse_alpha | 8.77 | 4.30 | 0.370 | 22.54 | 0.191 |
| fold-002 | reverse_alpha | 27.82 | 13.07 | 1.043 | 10.96 | 1.194 |
| fold-003 | reverse_alpha | 6.95 | 3.42 | 0.323 | 10.51 | 0.326 |
| fold-004 | reverse_alpha | 2.66 | 1.32 | 0.166 | 20.37 | 0.065 |
| fold-005 | reverse_alpha | 10.92 | 5.32 | 0.415 | 14.61 | 0.365 |
| fold-006 | reverse_alpha | 41.85 | 19.12 | 1.547 | 9.56 | 2.002 |
| fold-007 | reverse_alpha | 2.54 | 1.27 | 0.177 | 10.30 | 0.123 |
| fold-008 | reverse_alpha | 25.84 | 12.19 | 0.971 | 12.31 | 0.991 |
| fold-009 | reverse_alpha | 23.47 | 11.12 | 0.815 | 14.24 | 0.782 |
| fold-010 | reverse_alpha | 20.47 | 9.77 | 0.616 | 15.66 | 0.624 |
| fold-011 | reverse_alpha | 15.17 | 7.32 | 0.537 | 21.82 | 0.336 |
| fold-012 | reverse_alpha | -4.80 | -2.43 | -0.085 | 28.64 | -0.085 |
| fold-000 | symbol_length | -5.27 | -2.67 | -0.083 | 19.59 | -0.137 |
| fold-001 | symbol_length | 4.57 | 2.26 | 0.221 | 27.35 | 0.083 |
| fold-002 | symbol_length | 30.23 | 14.13 | 1.101 | 16.27 | 0.869 |
| fold-003 | symbol_length | 16.35 | 7.87 | 0.635 | 11.04 | 0.714 |
| fold-004 | symbol_length | -3.16 | -1.59 | -0.057 | 21.88 | -0.073 |
| fold-005 | symbol_length | 12.42 | 6.03 | 0.477 | 12.77 | 0.473 |
| fold-006 | symbol_length | 24.16 | 11.43 | 0.960 | 12.45 | 0.919 |
| fold-007 | symbol_length | 8.88 | 4.35 | 0.477 | 9.13 | 0.477 |
| fold-008 | symbol_length | 23.51 | 11.14 | 0.980 | 7.63 | 1.463 |
| fold-009 | symbol_length | -5.06 | -2.56 | -0.114 | 22.71 | -0.113 |
| fold-010 | symbol_length | 51.78 | 23.22 | 1.158 | 13.54 | 1.717 |
| fold-011 | symbol_length | 3.42 | 1.70 | 0.191 | 28.41 | 0.060 |
| fold-012 | symbol_length | -13.14 | -6.80 | -0.456 | 28.95 | -0.235 |
| fold-000 | hash_random | -5.27 | -2.67 | -0.083 | 19.59 | -0.137 |
| fold-001 | hash_random | 4.57 | 2.26 | 0.221 | 27.35 | 0.083 |
| fold-002 | hash_random | 30.23 | 14.13 | 1.101 | 16.27 | 0.869 |
| fold-003 | hash_random | 16.35 | 7.87 | 0.635 | 11.04 | 0.714 |
| fold-004 | hash_random | -3.16 | -1.59 | -0.057 | 21.88 | -0.073 |
| fold-005 | hash_random | 12.42 | 6.03 | 0.477 | 12.77 | 0.473 |
| fold-006 | hash_random | 24.16 | 11.43 | 0.960 | 12.45 | 0.919 |
| fold-007 | hash_random | 8.88 | 4.35 | 0.477 | 9.13 | 0.477 |
| fold-008 | hash_random | 23.51 | 11.14 | 0.980 | 7.63 | 1.463 |
| fold-009 | hash_random | -5.06 | -2.56 | -0.114 | 22.71 | -0.113 |
| fold-010 | hash_random | 51.78 | 23.22 | 1.158 | 13.54 | 1.717 |
| fold-011 | hash_random | 3.42 | 1.70 | 0.191 | 28.41 | 0.060 |
| fold-012 | hash_random | -13.14 | -6.80 | -0.456 | 28.95 | -0.235 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| baseline | 18.68 ± 15.50 | 8.73 ± 7.16 | 0.660 ± 0.462 | 17.29 ± 6.89 | 0.690 ± 0.600 |
| reverse_alpha | 15.49 ± 12.72 | 7.32 ± 5.89 | 0.589 ± 0.438 | 16.07 ± 5.81 | 0.574 ± 0.566 |
| symbol_length | 11.44 ± 17.79 | 5.27 ± 8.27 | 0.422 ± 0.524 | 17.83 ± 7.48 | 0.478 ± 0.631 |
| hash_random | 11.44 ± 17.79 | 5.27 ± 8.27 | 0.422 ± 0.524 | 17.83 ± 7.48 | 0.478 ± 0.631 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 13 folds total; gate metric marked **\***):

| Variant | Sharpe wins* | Calmar wins | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|
| reverse_alpha | 5 | 6 | 4 | 9 | 13 |
| symbol_length | 4 | 3 | 2 | 4 | 13 |
| hash_random | 4 | 3 | 2 | 4 | 13 |

## 4. Go/no-go verdict

Gate: variant wins ≥7 of 13 folds on **Sharpe** vs baseline `baseline`, no fold worse by Δ>0.3000.

- **reverse_alpha**: FAIL (5 / 13 wins; worst fold `fold-007` gap 0.8234). Reason: M-threshold miss: 5 wins < 7 required; worst fold fold-007 trails by 0.8234 > Δ=0.3000
- **symbol_length**: FAIL (4 / 13 wins; worst fold `fold-000` gap 1.0268). Reason: M-threshold miss: 4 wins < 7 required; worst fold fold-000 trails by 1.0268 > Δ=0.3000
- **hash_random**: FAIL (4 / 13 wins; worst fold `fold-000` gap 1.0268). Reason: M-threshold miss: 4 wins < 7 required; worst fold fold-000 trails by 1.0268 > Δ=0.3000