# Walk-forward CV report

## 1. Per-fold metrics

| Fold | Variant | Return % | CAGR % | Sharpe | MaxDD % | Calmar |
|------|---------|---------:|-------:|-------:|--------:|-------:|
| fold-000 | baseline | 17.13 | 8.23 | 0.427 | 40.72 | 0.202 |
| fold-001 | baseline | 33.96 | 15.75 | 1.226 | 8.61 | 1.832 |
| fold-002 | baseline | 16.84 | 8.10 | 0.568 | 14.37 | 0.564 |
| fold-003 | baseline | -5.18 | -2.62 | -0.093 | 16.41 | -0.160 |
| fold-004 | baseline | 10.62 | 5.18 | 0.377 | 17.21 | 0.301 |
| fold-005 | baseline | 6.05 | 2.98 | 0.275 | 16.78 | 0.178 |
| fold-006 | baseline | 90.79 | 38.16 | 1.695 | 12.17 | 3.141 |
| fold-007 | baseline | 75.29 | 32.42 | 0.934 | 58.62 | 0.554 |
| fold-008 | baseline | 69.73 | 30.30 | 1.827 | 7.83 | 3.875 |
| fold-009 | baseline | -13.66 | -7.09 | -0.424 | 26.72 | -0.266 |
| fold-010 | baseline | 104.32 | 42.98 | 1.128 | 31.20 | 1.380 |
| fold-011 | baseline | -1.28 | -0.64 | 0.008 | 26.88 | -0.024 |
| fold-012 | baseline | 20.63 | 9.84 | 0.548 | 29.21 | 0.337 |
| fold-000 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0 | 17.13 | 8.23 | 0.427 | 40.72 | 0.202 |
| fold-001 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0 | 33.96 | 15.75 | 1.226 | 8.61 | 1.832 |
| fold-002 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0 | 16.84 | 8.10 | 0.568 | 14.37 | 0.564 |
| fold-003 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0 | -5.18 | -2.62 | -0.093 | 16.41 | -0.160 |
| fold-004 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0 | 10.62 | 5.18 | 0.377 | 17.21 | 0.301 |
| fold-005 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0 | 6.05 | 2.98 | 0.275 | 16.78 | 0.178 |
| fold-006 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0 | 90.79 | 38.16 | 1.695 | 12.17 | 3.141 |
| fold-007 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0 | 75.29 | 32.42 | 0.934 | 58.62 | 0.554 |
| fold-008 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0 | 69.73 | 30.30 | 1.827 | 7.83 | 3.875 |
| fold-009 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0 | -13.66 | -7.09 | -0.424 | 26.72 | -0.266 |
| fold-010 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0 | 104.32 | 42.98 | 1.128 | 31.20 | 1.380 |
| fold-011 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0 | -1.28 | -0.64 | 0.008 | 26.88 | -0.024 |
| fold-012 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0 | 20.63 | 9.84 | 0.548 | 29.21 | 0.337 |
| fold-000 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0 | 17.76 | 8.53 | 0.437 | 40.72 | 0.210 |
| fold-001 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0 | 32.76 | 15.23 | 1.247 | 7.43 | 2.053 |
| fold-002 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0 | 12.16 | 5.91 | 0.424 | 15.63 | 0.379 |
| fold-003 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0 | 43.38 | 19.76 | 1.241 | 12.48 | 1.586 |
| fold-004 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0 | -2.24 | -1.13 | 0.001 | 19.30 | -0.058 |
| fold-005 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0 | 11.01 | 5.36 | 0.434 | 14.43 | 0.372 |
| fold-006 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0 | 35.14 | 16.26 | 1.143 | 10.84 | 1.503 |
| fold-007 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0 | 70.27 | 30.51 | 2.180 | 7.44 | 4.109 |
| fold-008 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0 | 23.89 | 11.31 | 0.868 | 10.68 | 1.061 |
| fold-009 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0 | 5.50 | 2.71 | 0.254 | 16.33 | 0.166 |
| fold-010 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0 | 144.71 | 56.48 | 1.519 | 19.58 | 2.890 |
| fold-011 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0 | -18.21 | -9.57 | -0.793 | 34.84 | -0.275 |
| fold-012 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0 | 37.60 | 17.32 | 0.836 | 24.69 | 0.702 |
| fold-000 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0 | 19.80 | 9.46 | 0.468 | 40.65 | 0.233 |
| fold-001 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0 | 25.80 | 12.17 | 0.858 | 11.29 | 1.079 |
| fold-002 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0 | 5.53 | 2.73 | 0.254 | 17.28 | 0.158 |
| fold-003 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0 | 15.08 | 7.28 | 0.570 | 14.08 | 0.518 |
| fold-004 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0 | 12.17 | 5.91 | 0.437 | 14.61 | 0.405 |
| fold-005 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0 | 9.62 | 4.70 | 0.380 | 13.50 | 0.349 |
| fold-006 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0 | 23.44 | 11.11 | 0.526 | 11.30 | 0.985 |
| fold-007 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0 | 53.36 | 23.86 | 1.701 | 9.01 | 2.652 |
| fold-008 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0 | 16.85 | 8.10 | 0.598 | 12.06 | 0.673 |
| fold-009 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0 | 7.12 | 3.50 | 0.299 | 16.82 | 0.209 |
| fold-010 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0 | 113.67 | 46.21 | 1.477 | 15.39 | 3.007 |
| fold-011 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0 | 1.47 | 0.73 | 0.119 | 23.10 | 0.032 |
| fold-012 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0 | 21.27 | 10.13 | 0.562 | 27.36 | 0.371 |
| fold-000 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0 | 19.80 | 9.46 | 0.468 | 40.65 | 0.233 |
| fold-001 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0 | 25.80 | 12.17 | 0.858 | 11.29 | 1.079 |
| fold-002 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0 | 5.53 | 2.73 | 0.254 | 17.28 | 0.158 |
| fold-003 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0 | 15.08 | 7.28 | 0.570 | 14.08 | 0.518 |
| fold-004 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0 | 12.17 | 5.91 | 0.437 | 14.61 | 0.405 |
| fold-005 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0 | 9.62 | 4.70 | 0.380 | 13.50 | 0.349 |
| fold-006 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0 | 23.44 | 11.11 | 0.526 | 11.30 | 0.985 |
| fold-007 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0 | 53.36 | 23.86 | 1.701 | 9.01 | 2.652 |
| fold-008 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0 | 13.48 | 6.53 | 0.497 | 12.34 | 0.530 |
| fold-009 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0 | 7.53 | 3.70 | 0.312 | 16.82 | 0.220 |
| fold-010 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0 | 113.67 | 46.21 | 1.477 | 15.39 | 3.007 |
| fold-011 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0 | -4.43 | -2.24 | -0.120 | 26.28 | -0.085 |
| fold-012 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0 | 21.27 | 10.13 | 0.562 | 27.36 | 0.371 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| baseline | 32.71 ± 39.02 | 14.12 ± 16.46 | 0.654 ± 0.678 | 23.59 ± 14.31 | 0.917 ± 1.298 |
| min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0 | 32.71 ± 39.02 | 14.12 ± 16.46 | 0.654 ± 0.678 | 23.59 ± 14.31 | 0.917 ± 1.298 |
| min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0 | 31.83 ± 40.66 | 13.75 ± 16.37 | 0.753 ± 0.752 | 18.03 ± 10.12 | 1.131 ± 1.280 |
| min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0 | 25.01 ± 29.62 | 11.22 ± 12.00 | 0.634 ± 0.463 | 17.42 ± 8.58 | 0.821 ± 0.945 |
| min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0 | 24.33 ± 30.12 | 10.89 ± 12.27 | 0.609 ± 0.490 | 17.69 ± 8.79 | 0.802 ± 0.956 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 13 folds total; gate metric marked **\***):

| Variant | Sharpe wins* | Calmar wins | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|
| min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0 | 0 | 0 | 0 | 0 | 13 |
| min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0 | 8 | 8 | 6 | 8 | 13 |
| min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0 | 9 | 9 | 8 | 10 | 13 |
| min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0 | 8 | 8 | 7 | 10 | 13 |

## 4. Go/no-go verdict

Gate: variant wins ≥7 of 13 folds on **Sharpe** vs baseline `baseline`, no fold worse by Δ>0.0000.

- **min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0**: FAIL (0 / 13 wins; worst fold `fold-000` gap 0.0000). Reason: M-threshold miss: 0 wins < 7 required
- **min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0**: FAIL (8 / 13 wins; worst fold `fold-008` gap 0.9589). Reason: Δ-threshold miss: fold fold-008 trails by 0.9589 > Δ=0.0000
- **min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0**: FAIL (9 / 13 wins; worst fold `fold-008` gap 1.2293). Reason: Δ-threshold miss: fold fold-008 trails by 1.2293 > Δ=0.0000
- **min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0**: FAIL (8 / 13 wins; worst fold `fold-008` gap 1.3301). Reason: Δ-threshold miss: fold fold-008 trails by 1.3301 > Δ=0.0000