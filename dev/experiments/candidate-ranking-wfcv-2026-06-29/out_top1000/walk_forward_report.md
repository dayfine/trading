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
| fold-000 | quality_ranking | 26.62 | 12.54 | 0.804 | 17.83 | 0.704 |
| fold-001 | quality_ranking | 8.74 | 4.28 | 0.361 | 23.09 | 0.186 |
| fold-002 | quality_ranking | 25.59 | 12.08 | 0.937 | 17.21 | 0.703 |
| fold-003 | quality_ranking | 9.30 | 4.55 | 0.393 | 10.19 | 0.447 |
| fold-004 | quality_ranking | 20.22 | 9.65 | 0.679 | 14.67 | 0.659 |
| fold-005 | quality_ranking | 9.56 | 4.68 | 0.372 | 12.93 | 0.362 |
| fold-006 | quality_ranking | 16.51 | 7.95 | 0.742 | 11.94 | 0.666 |
| fold-007 | quality_ranking | 22.13 | 10.52 | 1.024 | 7.83 | 1.346 |
| fold-008 | quality_ranking | 41.79 | 19.09 | 1.478 | 9.31 | 2.053 |
| fold-009 | quality_ranking | 21.88 | 10.41 | 0.792 | 13.21 | 0.789 |
| fold-010 | quality_ranking | 14.78 | 7.14 | 0.488 | 14.86 | 0.481 |
| fold-011 | quality_ranking | 4.23 | 2.10 | 0.227 | 22.54 | 0.093 |
| fold-012 | quality_ranking | 8.86 | 4.34 | 0.362 | 21.55 | 0.202 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| baseline | 18.68 ± 15.50 | 8.73 ± 7.16 | 0.660 ± 0.462 | 17.29 ± 6.89 | 0.690 ± 0.600 |
| quality_ranking | 17.71 ± 10.21 | 8.41 ± 4.64 | 0.666 ± 0.350 | 15.17 ± 5.01 | 0.669 ± 0.529 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 13 folds total; gate metric marked **\***):

| Variant | Sharpe wins* | Calmar wins | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|
| quality_ranking | 6 | 6 | 5 | 7 | 13 |

## 4. Go/no-go verdict

Gate: variant wins ≥7 of 13 folds on **Sharpe** vs baseline `baseline`, no fold worse by Δ>0.3000.

- **quality_ranking**: FAIL (6 / 13 wins; worst fold `fold-010` gap 0.6682). Reason: M-threshold miss: 6 wins < 7 required; worst fold fold-010 trails by 0.6682 > Δ=0.3000