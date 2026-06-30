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
| fold-000 | earliness_ranking | 19.38 | 9.27 | 0.715 | 10.34 | 0.898 |
| fold-001 | earliness_ranking | 65.14 | 28.53 | 1.180 | 16.28 | 1.755 |
| fold-002 | earliness_ranking | 3.24 | 1.61 | 0.184 | 15.24 | 0.106 |
| fold-003 | earliness_ranking | 27.63 | 12.98 | 0.846 | 21.42 | 0.607 |
| fold-004 | earliness_ranking | -1.26 | -0.63 | 0.032 | 26.45 | -0.024 |
| fold-005 | earliness_ranking | 3.54 | 1.76 | 0.190 | 19.15 | 0.092 |
| fold-006 | earliness_ranking | 43.08 | 19.63 | 1.455 | 11.86 | 1.658 |
| fold-007 | earliness_ranking | 7.80 | 3.83 | 0.361 | 8.76 | 0.438 |
| fold-008 | earliness_ranking | 15.05 | 7.27 | 0.621 | 13.35 | 0.545 |
| fold-009 | earliness_ranking | 23.96 | 11.35 | 0.857 | 15.00 | 0.758 |
| fold-010 | earliness_ranking | 81.65 | 34.81 | 1.521 | 14.33 | 2.433 |
| fold-011 | earliness_ranking | 11.19 | 5.45 | 0.435 | 16.78 | 0.325 |
| fold-012 | earliness_ranking | 4.12 | 2.04 | 0.204 | 29.66 | 0.069 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| baseline | 23.73 ± 22.32 | 10.82 ± 10.08 | 0.735 ± 0.549 | 15.72 ± 7.00 | 0.861 ± 0.659 |
| earliness_ranking | 23.43 ± 25.50 | 10.61 ± 10.95 | 0.662 ± 0.493 | 16.82 ± 6.06 | 0.743 ± 0.760 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 13 folds total; gate metric marked **\***):

| Variant | Sharpe wins* | Calmar wins | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|
| earliness_ranking | 6 | 5 | 6 | 5 | 13 |

## 4. Go/no-go verdict

Gate: variant wins ≥7 of 13 folds on **Sharpe** vs baseline `baseline`, no fold worse by Δ>0.3000.

- **earliness_ranking**: FAIL (6 / 13 wins; worst fold `fold-007` gap 0.6175). Reason: M-threshold miss: 6 wins < 7 required; worst fold fold-007 trails by 0.6175 > Δ=0.3000