# Walk-forward CV report

## 1. Per-fold metrics

| Fold | Variant | Return % | CAGR % | Sharpe | MaxDD % | Calmar |
|------|---------|---------:|-------:|-------:|--------:|-------:|
| fold-000 | baseline | 21.72 | 10.33 | 0.827 | 10.16 | 1.019 |
| fold-001 | baseline | 60.98 | 26.90 | 1.161 | 15.85 | 1.700 |
| fold-002 | baseline | 22.29 | 10.59 | 0.795 | 10.27 | 1.033 |
| fold-003 | baseline | 21.18 | 10.09 | 0.734 | 12.85 | 0.786 |
| fold-004 | baseline | 10.12 | 4.94 | 0.396 | 20.76 | 0.238 |
| fold-005 | baseline | 6.47 | 3.19 | 0.283 | 16.18 | 0.197 |
| fold-006 | baseline | 42.86 | 19.54 | 1.597 | 12.11 | 1.616 |
| fold-007 | baseline | 19.88 | 9.50 | 0.979 | 9.87 | 0.963 |
| fold-008 | baseline | 16.10 | 7.75 | 0.611 | 16.85 | 0.461 |
| fold-009 | baseline | 17.93 | 8.60 | 0.722 | 10.85 | 0.794 |
| fold-010 | baseline | 64.49 | 28.28 | 1.387 | 13.70 | 2.068 |
| fold-011 | baseline | 25.07 | 11.84 | 0.694 | 19.09 | 0.621 |
| fold-012 | baseline | -20.53 | -10.86 | -0.630 | 35.85 | -0.303 |
| fold-000 | quality_ranking | 25.04 | 11.83 | 0.816 | 11.89 | 0.997 |
| fold-001 | quality_ranking | 50.97 | 22.89 | 1.000 | 15.62 | 1.468 |
| fold-002 | quality_ranking | 17.47 | 8.39 | 0.628 | 11.92 | 0.704 |
| fold-003 | quality_ranking | 7.45 | 3.66 | 0.339 | 11.18 | 0.328 |
| fold-004 | quality_ranking | -1.90 | -0.96 | 0.024 | 25.63 | -0.037 |
| fold-005 | quality_ranking | -3.12 | -1.57 | -0.010 | 25.70 | -0.061 |
| fold-006 | quality_ranking | 60.85 | 26.85 | 1.870 | 12.15 | 2.214 |
| fold-007 | quality_ranking | 14.72 | 7.11 | 0.640 | 6.70 | 1.062 |
| fold-008 | quality_ranking | 19.43 | 9.29 | 0.735 | 13.73 | 0.678 |
| fold-009 | quality_ranking | 21.58 | 10.27 | 0.770 | 12.77 | 0.805 |
| fold-010 | quality_ranking | 43.19 | 19.68 | 1.088 | 18.36 | 1.073 |
| fold-011 | quality_ranking | 14.25 | 6.89 | 0.517 | 12.55 | 0.550 |
| fold-012 | quality_ranking | 6.06 | 2.99 | 0.251 | 25.31 | 0.118 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| baseline | 23.73 ± 22.32 | 10.82 ± 10.08 | 0.735 ± 0.549 | 15.72 ± 7.00 | 0.861 ± 0.659 |
| quality_ranking | 21.23 ± 19.60 | 9.79 ± 8.71 | 0.667 ± 0.496 | 15.66 ± 6.21 | 0.761 ± 0.634 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 13 folds total; gate metric marked **\***):

| Variant | Sharpe wins* | Calmar wins | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|
| quality_ranking | 4 | 5 | 5 | 6 | 13 |

## 4. Go/no-go verdict

Gate: variant wins ≥7 of 13 folds on **Sharpe** vs baseline `baseline`, no fold worse by Δ>0.3000.

- **quality_ranking**: FAIL (4 / 13 wins; worst fold `fold-003` gap 0.3951). Reason: M-threshold miss: 4 wins < 7 required; worst fold fold-003 trails by 0.3951 > Δ=0.3000