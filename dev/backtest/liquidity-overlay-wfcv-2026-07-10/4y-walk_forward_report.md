# Walk-forward CV report

## 1. Per-fold metrics

| Fold | Variant | Return % | CAGR % | Sharpe | MaxDD % | Calmar |
|------|---------|---------:|-------:|-------:|--------:|-------:|
| fold-000 | baseline | 56.91 | 11.93 | 0.645 | 40.72 | 0.293 |
| fold-001 | baseline | 13.13 | 3.13 | 0.278 | 20.41 | 0.154 |
| fold-002 | baseline | 16.13 | 3.81 | 0.308 | 18.15 | 0.210 |
| fold-003 | baseline | 182.13 | 29.63 | 1.654 | 12.17 | 2.437 |
| fold-004 | baseline | 66.51 | 13.61 | 0.928 | 18.60 | 0.732 |
| fold-005 | baseline | 51.39 | 10.93 | 0.499 | 50.16 | 0.218 |
| fold-000 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0 | 56.91 | 11.93 | 0.645 | 40.72 | 0.293 |
| fold-001 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0 | 13.13 | 3.13 | 0.278 | 20.41 | 0.154 |
| fold-002 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0 | 16.13 | 3.81 | 0.308 | 18.15 | 0.210 |
| fold-003 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0 | 182.13 | 29.63 | 1.654 | 12.17 | 2.437 |
| fold-004 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0 | 66.51 | 13.61 | 0.928 | 18.60 | 0.732 |
| fold-005 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0 | 51.39 | 10.93 | 0.499 | 50.16 | 0.218 |
| fold-000 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0 | 55.96 | 11.76 | 0.642 | 40.72 | 0.289 |
| fold-001 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0 | 60.98 | 12.65 | 0.805 | 15.63 | 0.810 |
| fold-002 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0 | 1.55 | 0.39 | 0.100 | 19.30 | 0.020 |
| fold-003 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0 | 89.62 | 17.36 | 1.192 | 14.63 | 1.188 |
| fold-004 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0 | 19.28 | 4.51 | 0.392 | 22.57 | 0.200 |
| fold-005 | min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0 | 66.90 | 13.67 | 0.624 | 43.53 | 0.314 |
| fold-000 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0 | 50.71 | 10.81 | 0.582 | 40.65 | 0.266 |
| fold-001 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0 | 66.40 | 13.59 | 0.898 | 17.28 | 0.787 |
| fold-002 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0 | 28.05 | 6.38 | 0.462 | 14.61 | 0.437 |
| fold-003 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0 | 76.43 | 15.26 | 0.791 | 11.30 | 1.352 |
| fold-004 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0 | 33.21 | 7.44 | 0.527 | 18.94 | 0.393 |
| fold-005 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0 | 86.02 | 16.80 | 0.802 | 30.67 | 0.548 |
| fold-000 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0 | 50.71 | 10.81 | 0.582 | 40.65 | 0.266 |
| fold-001 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0 | 66.40 | 13.59 | 0.898 | 17.28 | 0.787 |
| fold-002 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0 | 28.05 | 6.38 | 0.462 | 14.61 | 0.437 |
| fold-003 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0 | 83.37 | 16.38 | 0.835 | 11.30 | 1.451 |
| fold-004 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0 | 22.33 | 5.17 | 0.398 | 18.78 | 0.276 |
| fold-005 | min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0 | 94.03 | 18.04 | 0.846 | 29.82 | 0.605 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| baseline | 64.37 ± 61.72 | 12.17 ± 9.59 | 0.719 ± 0.517 | 26.70 ± 15.07 | 0.674 ± 0.889 |
| min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0 | 64.37 ± 61.72 | 12.17 ± 9.59 | 0.719 ± 0.517 | 26.70 ± 15.07 | 0.674 ± 0.889 |
| min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0 | 49.05 ± 32.55 | 10.06 ± 6.33 | 0.626 ± 0.370 | 26.06 ± 12.79 | 0.470 ± 0.439 |
| min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0 | 56.80 ± 23.46 | 11.71 ± 4.23 | 0.677 ± 0.176 | 22.24 ± 11.16 | 0.630 ± 0.394 |
| min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0 | 57.48 ± 29.10 | 11.73 ± 5.24 | 0.670 ± 0.217 | 22.07 ± 11.05 | 0.637 ± 0.446 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 6 folds total; gate metric marked **\***):

| Variant | Sharpe wins* | Calmar wins | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|
| min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0 | 0 | 0 | 0 | 0 | 6 |
| min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0 | 2 | 2 | 2 | 2 | 6 |
| min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0 | 3 | 3 | 3 | 5 | 6 |
| min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0 | 3 | 3 | 3 | 5 | 6 |

## 4. Go/no-go verdict

Gate: variant wins ≥4 of 6 folds on **Sharpe** vs baseline `baseline`, no fold worse by Δ>0.0000.

- **min_entry_dollar_adv=0.0__min_hold_dollar_adv=0.0**: FAIL (0 / 6 wins; worst fold `fold-000` gap 0.0000). Reason: M-threshold miss: 0 wins < 4 required
- **min_entry_dollar_adv=0.0__min_hold_dollar_adv=500000.0**: FAIL (2 / 6 wins; worst fold `fold-004` gap 0.5354). Reason: M-threshold miss: 2 wins < 4 required; worst fold fold-004 trails by 0.5354 > Δ=0.0000
- **min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=0.0**: FAIL (3 / 6 wins; worst fold `fold-003` gap 0.8628). Reason: M-threshold miss: 3 wins < 4 required; worst fold fold-003 trails by 0.8628 > Δ=0.0000
- **min_entry_dollar_adv=1000000.0__min_hold_dollar_adv=500000.0**: FAIL (3 / 6 wins; worst fold `fold-003` gap 0.8194). Reason: M-threshold miss: 3 wins < 4 required; worst fold fold-003 trails by 0.8194 > Δ=0.0000