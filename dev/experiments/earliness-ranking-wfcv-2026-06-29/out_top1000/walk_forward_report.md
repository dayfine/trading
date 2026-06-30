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
| fold-000 | earliness_ranking | 12.83 | 6.22 | 0.516 | 21.31 | 0.293 |
| fold-001 | earliness_ranking | 17.26 | 8.29 | 0.636 | 18.01 | 0.461 |
| fold-002 | earliness_ranking | 19.09 | 9.14 | 0.741 | 16.02 | 0.571 |
| fold-003 | earliness_ranking | 27.49 | 12.92 | 0.910 | 8.95 | 1.445 |
| fold-004 | earliness_ranking | -5.65 | -2.87 | -0.155 | 22.75 | -0.126 |
| fold-005 | earliness_ranking | 6.86 | 3.37 | 0.290 | 13.66 | 0.247 |
| fold-006 | earliness_ranking | 23.39 | 11.09 | 0.974 | 11.94 | 0.930 |
| fold-007 | earliness_ranking | 17.70 | 8.49 | 0.831 | 8.06 | 1.055 |
| fold-008 | earliness_ranking | 20.40 | 9.73 | 0.802 | 9.55 | 1.020 |
| fold-009 | earliness_ranking | 20.94 | 9.98 | 0.732 | 20.14 | 0.496 |
| fold-010 | earliness_ranking | 32.20 | 14.99 | 0.859 | 15.35 | 0.978 |
| fold-011 | earliness_ranking | 16.58 | 7.98 | 0.643 | 21.66 | 0.369 |
| fold-012 | earliness_ranking | -5.01 | -2.54 | -0.112 | 21.74 | -0.117 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| baseline | 18.68 ± 15.50 | 8.73 ± 7.16 | 0.660 ± 0.462 | 17.29 ± 6.89 | 0.690 ± 0.600 |
| earliness_ranking | 15.70 ± 11.22 | 7.45 ± 5.33 | 0.590 ± 0.367 | 16.09 ± 5.29 | 0.586 ± 0.474 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 13 folds total; gate metric marked **\***):

| Variant | Sharpe wins* | Calmar wins | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|
| earliness_ranking | 6 | 5 | 6 | 5 | 13 |

## 4. Go/no-go verdict

Gate: variant wins ≥7 of 13 folds on **Sharpe** vs baseline `baseline`, no fold worse by Δ>0.3000.

- **earliness_ranking**: FAIL (6 / 13 wins; worst fold `fold-002` gap 0.5977). Reason: M-threshold miss: 6 wins < 7 required; worst fold fold-002 trails by 0.5977 > Δ=0.3000