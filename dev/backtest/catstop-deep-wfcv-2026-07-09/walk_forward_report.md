# Walk-forward CV report

## 1. Per-fold metrics

| Fold | Variant | Return % | CAGR % | Sharpe | MaxDD % | Calmar |
|------|---------|---------:|-------:|-------:|--------:|-------:|
| fold-000 | baseline | 40.84 | 40.88 | 1.821 | 12.48 | 3.286 |
| fold-001 | baseline | 1.42 | 1.42 | 0.207 | 8.55 | 0.167 |
| fold-002 | baseline | -2.36 | -2.36 | -0.121 | 9.09 | -0.260 |
| fold-003 | baseline | 24.74 | 24.76 | 1.539 | 9.33 | 2.662 |
| fold-004 | baseline | 10.01 | 10.02 | 0.768 | 9.38 | 1.071 |
| fold-005 | baseline | 8.02 | 8.03 | 0.688 | 9.48 | 0.849 |
| fold-006 | baseline | 3.78 | 3.78 | 0.395 | 9.79 | 0.387 |
| fold-007 | baseline | 11.59 | 11.60 | 0.684 | 16.66 | 0.698 |
| fold-008 | baseline | -7.74 | -7.75 | -1.003 | 10.60 | -0.733 |
| fold-009 | baseline | 8.04 | 8.05 | 0.490 | 13.13 | 0.615 |
| fold-010 | baseline | 25.02 | 25.04 | 1.294 | 15.34 | 1.637 |
| fold-011 | baseline | -5.52 | -5.53 | -0.295 | 17.97 | -0.308 |
| fold-012 | baseline | 9.88 | 9.89 | 0.891 | 7.53 | 1.318 |
| fold-013 | baseline | 29.76 | 29.78 | 1.269 | 11.50 | 2.597 |
| fold-014 | baseline | 10.76 | 10.77 | 0.823 | 12.63 | 0.855 |
| fold-015 | baseline | -1.04 | -1.04 | -0.024 | 10.43 | -0.100 |
| fold-016 | baseline | 10.99 | 11.00 | 0.915 | 8.02 | 1.376 |
| fold-017 | baseline | 31.55 | 31.58 | 3.050 | 4.20 | 7.538 |
| fold-018 | baseline | 2.79 | 2.79 | 0.253 | 10.38 | 0.270 |
| fold-019 | baseline | 1.85 | 1.85 | 0.209 | 11.95 | 0.156 |
| fold-020 | baseline | 4.37 | 4.38 | 0.327 | 13.58 | 0.323 |
| fold-021 | baseline | 4.50 | 4.51 | 0.301 | 24.03 | 0.188 |
| fold-022 | baseline | -4.93 | -4.93 | -0.272 | 15.59 | -0.317 |
| fold-023 | baseline | 7.33 | 7.34 | 0.634 | 14.07 | 0.523 |
| fold-024 | baseline | -7.01 | -7.02 | -0.585 | 12.13 | -0.580 |
| fold-025 | baseline | -16.63 | -16.64 | -1.470 | 17.09 | -0.976 |
| fold-000 | catastrophic_stop_pct=0.0 | 40.84 | 40.88 | 1.821 | 12.48 | 3.286 |
| fold-001 | catastrophic_stop_pct=0.0 | 1.85 | 1.85 | 0.263 | 8.41 | 0.221 |
| fold-002 | catastrophic_stop_pct=0.0 | -5.51 | -5.52 | -0.370 | 11.75 | -0.471 |
| fold-003 | catastrophic_stop_pct=0.0 | 27.18 | 27.20 | 1.585 | 9.40 | 2.902 |
| fold-004 | catastrophic_stop_pct=0.0 | 10.01 | 10.02 | 0.768 | 9.38 | 1.071 |
| fold-005 | catastrophic_stop_pct=0.0 | 8.02 | 8.03 | 0.688 | 9.48 | 0.849 |
| fold-006 | catastrophic_stop_pct=0.0 | 3.78 | 3.78 | 0.395 | 9.79 | 0.387 |
| fold-007 | catastrophic_stop_pct=0.0 | 11.59 | 11.60 | 0.684 | 16.66 | 0.698 |
| fold-008 | catastrophic_stop_pct=0.0 | -9.85 | -9.86 | -1.101 | 13.09 | -0.755 |
| fold-009 | catastrophic_stop_pct=0.0 | 8.04 | 8.05 | 0.490 | 13.13 | 0.615 |
| fold-010 | catastrophic_stop_pct=0.0 | 25.02 | 25.04 | 1.294 | 15.34 | 1.637 |
| fold-011 | catastrophic_stop_pct=0.0 | -4.87 | -4.87 | -0.250 | 17.97 | -0.272 |
| fold-012 | catastrophic_stop_pct=0.0 | 9.88 | 9.89 | 0.891 | 7.53 | 1.318 |
| fold-013 | catastrophic_stop_pct=0.0 | 29.76 | 29.78 | 1.269 | 11.50 | 2.597 |
| fold-014 | catastrophic_stop_pct=0.0 | 10.76 | 10.77 | 0.823 | 12.63 | 0.855 |
| fold-015 | catastrophic_stop_pct=0.0 | -1.04 | -1.04 | -0.024 | 10.43 | -0.100 |
| fold-016 | catastrophic_stop_pct=0.0 | 10.99 | 11.00 | 0.915 | 8.02 | 1.376 |
| fold-017 | catastrophic_stop_pct=0.0 | 31.55 | 31.58 | 3.050 | 4.20 | 7.538 |
| fold-018 | catastrophic_stop_pct=0.0 | 2.79 | 2.79 | 0.253 | 10.38 | 0.270 |
| fold-019 | catastrophic_stop_pct=0.0 | 1.85 | 1.85 | 0.209 | 11.95 | 0.156 |
| fold-020 | catastrophic_stop_pct=0.0 | 9.61 | 9.62 | 0.553 | 13.58 | 0.710 |
| fold-021 | catastrophic_stop_pct=0.0 | 4.50 | 4.51 | 0.301 | 24.03 | 0.188 |
| fold-022 | catastrophic_stop_pct=0.0 | -5.27 | -5.27 | -0.236 | 15.60 | -0.339 |
| fold-023 | catastrophic_stop_pct=0.0 | 7.33 | 7.34 | 0.634 | 14.07 | 0.523 |
| fold-024 | catastrophic_stop_pct=0.0 | -7.01 | -7.02 | -0.585 | 12.13 | -0.580 |
| fold-025 | catastrophic_stop_pct=0.0 | -16.63 | -16.64 | -1.470 | 17.09 | -0.976 |
| fold-000 | catastrophic_stop_pct=0.10 | 40.84 | 40.88 | 1.821 | 12.48 | 3.286 |
| fold-001 | catastrophic_stop_pct=0.10 | 1.42 | 1.42 | 0.207 | 8.55 | 0.167 |
| fold-002 | catastrophic_stop_pct=0.10 | -2.36 | -2.36 | -0.121 | 9.09 | -0.260 |
| fold-003 | catastrophic_stop_pct=0.10 | 24.74 | 24.76 | 1.539 | 9.33 | 2.662 |
| fold-004 | catastrophic_stop_pct=0.10 | 10.01 | 10.02 | 0.768 | 9.38 | 1.071 |
| fold-005 | catastrophic_stop_pct=0.10 | 8.02 | 8.03 | 0.688 | 9.48 | 0.849 |
| fold-006 | catastrophic_stop_pct=0.10 | 3.78 | 3.78 | 0.395 | 9.79 | 0.387 |
| fold-007 | catastrophic_stop_pct=0.10 | 11.59 | 11.60 | 0.684 | 16.66 | 0.698 |
| fold-008 | catastrophic_stop_pct=0.10 | -7.74 | -7.75 | -1.003 | 10.60 | -0.733 |
| fold-009 | catastrophic_stop_pct=0.10 | 8.04 | 8.05 | 0.490 | 13.13 | 0.615 |
| fold-010 | catastrophic_stop_pct=0.10 | 25.02 | 25.04 | 1.294 | 15.34 | 1.637 |
| fold-011 | catastrophic_stop_pct=0.10 | -5.52 | -5.53 | -0.295 | 17.97 | -0.308 |
| fold-012 | catastrophic_stop_pct=0.10 | 9.88 | 9.89 | 0.891 | 7.53 | 1.318 |
| fold-013 | catastrophic_stop_pct=0.10 | 29.76 | 29.78 | 1.269 | 11.50 | 2.597 |
| fold-014 | catastrophic_stop_pct=0.10 | 10.76 | 10.77 | 0.823 | 12.63 | 0.855 |
| fold-015 | catastrophic_stop_pct=0.10 | -1.04 | -1.04 | -0.024 | 10.43 | -0.100 |
| fold-016 | catastrophic_stop_pct=0.10 | 10.99 | 11.00 | 0.915 | 8.02 | 1.376 |
| fold-017 | catastrophic_stop_pct=0.10 | 31.55 | 31.58 | 3.050 | 4.20 | 7.538 |
| fold-018 | catastrophic_stop_pct=0.10 | 2.79 | 2.79 | 0.253 | 10.38 | 0.270 |
| fold-019 | catastrophic_stop_pct=0.10 | 1.85 | 1.85 | 0.209 | 11.95 | 0.156 |
| fold-020 | catastrophic_stop_pct=0.10 | 4.37 | 4.38 | 0.327 | 13.58 | 0.323 |
| fold-021 | catastrophic_stop_pct=0.10 | 4.50 | 4.51 | 0.301 | 24.03 | 0.188 |
| fold-022 | catastrophic_stop_pct=0.10 | -4.93 | -4.93 | -0.272 | 15.59 | -0.317 |
| fold-023 | catastrophic_stop_pct=0.10 | 7.33 | 7.34 | 0.634 | 14.07 | 0.523 |
| fold-024 | catastrophic_stop_pct=0.10 | -7.01 | -7.02 | -0.585 | 12.13 | -0.580 |
| fold-025 | catastrophic_stop_pct=0.10 | -16.63 | -16.64 | -1.470 | 17.09 | -0.976 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| baseline | 7.77 ± 13.39 | 7.78 ± 13.40 | 0.492 ± 0.909 | 12.11 ± 4.05 | 0.894 ± 1.712 |
| catastrophic_stop_pct=0.0 | 7.89 ± 13.70 | 7.90 ± 13.71 | 0.494 ± 0.922 | 12.31 ± 4.00 | 0.912 ± 1.724 |
| catastrophic_stop_pct=0.10 | 7.77 ± 13.39 | 7.78 ± 13.40 | 0.492 ± 0.909 | 12.11 ± 4.05 | 0.894 ± 1.712 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 26 folds total; gate metric marked **\***):

| Variant | Sharpe wins* | Calmar wins | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|
| catastrophic_stop_pct=0.0 | 5 | 4 | 4 | 1 | 26 |
| catastrophic_stop_pct=0.10 | 0 | 0 | 0 | 0 | 26 |

## 4. Go/no-go verdict

Gate: variant wins ≥14 of 26 folds on **Sharpe** vs baseline `baseline`, no fold worse by Δ>0.0000.

- **catastrophic_stop_pct=0.0**: FAIL (5 / 26 wins; worst fold `fold-002` gap 0.2490). Reason: M-threshold miss: 5 wins < 14 required; worst fold fold-002 trails by 0.2490 > Δ=0.0000
- **catastrophic_stop_pct=0.10**: FAIL (0 / 26 wins; worst fold `fold-000` gap 0.0000). Reason: M-threshold miss: 0 wins < 14 required