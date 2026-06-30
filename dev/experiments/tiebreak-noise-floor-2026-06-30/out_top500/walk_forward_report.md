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
| fold-000 | reverse_alpha | 2.38 | 1.19 | 0.157 | 24.53 | 0.048 |
| fold-001 | reverse_alpha | 0.94 | 0.47 | 0.102 | 19.46 | 0.024 |
| fold-002 | reverse_alpha | 3.89 | 1.93 | 0.220 | 13.52 | 0.143 |
| fold-003 | reverse_alpha | 15.63 | 7.54 | 0.625 | 10.38 | 0.727 |
| fold-004 | reverse_alpha | 15.25 | 7.36 | 0.548 | 19.53 | 0.377 |
| fold-005 | reverse_alpha | 10.25 | 5.00 | 0.384 | 18.72 | 0.268 |
| fold-006 | reverse_alpha | 25.18 | 11.89 | 1.255 | 10.45 | 1.140 |
| fold-007 | reverse_alpha | 14.03 | 6.79 | 0.722 | 6.38 | 1.066 |
| fold-008 | reverse_alpha | 39.98 | 18.33 | 1.548 | 7.32 | 2.506 |
| fold-009 | reverse_alpha | 15.58 | 7.51 | 0.606 | 12.31 | 0.611 |
| fold-010 | reverse_alpha | 28.13 | 13.21 | 0.811 | 13.26 | 0.997 |
| fold-011 | reverse_alpha | 19.16 | 9.17 | 0.680 | 15.70 | 0.585 |
| fold-012 | reverse_alpha | 5.58 | 2.75 | 0.254 | 26.48 | 0.104 |
| fold-000 | symbol_length | 2.99 | 1.48 | 0.174 | 22.14 | 0.067 |
| fold-001 | symbol_length | 4.01 | 1.99 | 0.206 | 19.67 | 0.101 |
| fold-002 | symbol_length | 45.95 | 20.82 | 1.515 | 11.72 | 1.779 |
| fold-003 | symbol_length | 7.81 | 3.83 | 0.360 | 12.37 | 0.310 |
| fold-004 | symbol_length | 22.55 | 10.71 | 0.673 | 20.73 | 0.517 |
| fold-005 | symbol_length | 14.14 | 6.84 | 0.506 | 19.16 | 0.358 |
| fold-006 | symbol_length | 32.38 | 15.07 | 1.391 | 8.81 | 1.712 |
| fold-007 | symbol_length | 13.16 | 6.38 | 0.697 | 12.32 | 0.518 |
| fold-008 | symbol_length | 34.47 | 15.97 | 1.384 | 10.53 | 1.519 |
| fold-009 | symbol_length | 0.91 | 0.46 | 0.101 | 18.19 | 0.025 |
| fold-010 | symbol_length | 28.65 | 13.43 | 0.785 | 18.69 | 0.720 |
| fold-011 | symbol_length | 31.77 | 14.80 | 1.046 | 12.43 | 1.193 |
| fold-012 | symbol_length | -1.26 | -0.63 | 0.023 | 23.91 | -0.026 |
| fold-000 | hash_random | 2.99 | 1.48 | 0.174 | 22.14 | 0.067 |
| fold-001 | hash_random | 4.01 | 1.99 | 0.206 | 19.67 | 0.101 |
| fold-002 | hash_random | 45.95 | 20.82 | 1.515 | 11.72 | 1.779 |
| fold-003 | hash_random | 7.81 | 3.83 | 0.360 | 12.37 | 0.310 |
| fold-004 | hash_random | 22.55 | 10.71 | 0.673 | 20.73 | 0.517 |
| fold-005 | hash_random | 14.14 | 6.84 | 0.506 | 19.16 | 0.358 |
| fold-006 | hash_random | 32.38 | 15.07 | 1.391 | 8.81 | 1.712 |
| fold-007 | hash_random | 13.16 | 6.38 | 0.697 | 12.32 | 0.518 |
| fold-008 | hash_random | 34.47 | 15.97 | 1.384 | 10.53 | 1.519 |
| fold-009 | hash_random | 0.91 | 0.46 | 0.101 | 18.19 | 0.025 |
| fold-010 | hash_random | 28.65 | 13.43 | 0.785 | 18.69 | 0.720 |
| fold-011 | hash_random | 31.77 | 14.80 | 1.046 | 12.43 | 1.193 |
| fold-012 | hash_random | -1.26 | -0.63 | 0.023 | 23.91 | -0.026 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| baseline | 17.80 ± 16.72 | 8.29 ± 7.64 | 0.667 ± 0.544 | 14.79 ± 6.64 | 0.850 ± 0.945 |
| reverse_alpha | 15.08 ± 11.22 | 7.16 ± 5.16 | 0.609 ± 0.423 | 15.24 ± 6.22 | 0.661 ± 0.678 |
| symbol_length | 18.27 ± 15.30 | 8.55 ± 7.00 | 0.682 ± 0.518 | 16.21 ± 4.97 | 0.676 ± 0.657 |
| hash_random | 18.27 ± 15.30 | 8.55 ± 7.00 | 0.682 ± 0.518 | 16.21 ± 4.97 | 0.676 ± 0.657 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 13 folds total; gate metric marked **\***):

| Variant | Sharpe wins* | Calmar wins | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|
| reverse_alpha | 7 | 7 | 7 | 5 | 13 |
| symbol_length | 6 | 5 | 6 | 2 | 13 |
| hash_random | 6 | 5 | 6 | 2 | 13 |

## 4. Go/no-go verdict

Gate: variant wins ≥7 of 13 folds on **Sharpe** vs baseline `baseline`, no fold worse by Δ>0.3000.

- **reverse_alpha**: FAIL (7 / 13 wins; worst fold `fold-002` gap 1.3890). Reason: Δ-threshold miss: fold fold-002 trails by 1.3890 > Δ=0.3000
- **symbol_length**: FAIL (6 / 13 wins; worst fold `fold-000` gap 0.3386). Reason: M-threshold miss: 6 wins < 7 required; worst fold fold-000 trails by 0.3386 > Δ=0.3000
- **hash_random**: FAIL (6 / 13 wins; worst fold `fold-000` gap 0.3386). Reason: M-threshold miss: 6 wins < 7 required; worst fold fold-000 trails by 0.3386 > Δ=0.3000