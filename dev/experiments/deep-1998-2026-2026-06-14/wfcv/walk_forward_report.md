# Walk-forward CV report

## 1. Per-fold metrics

| Fold | Variant | Return % | CAGR % | Sharpe | MaxDD % | Calmar |
|------|---------|---------:|-------:|-------:|--------:|-------:|
| fold-000 | baseline | 26.98 | 27.00 | 1.226 | 13.08 | 2.071 |
| fold-001 | baseline | 82.06 | 82.13 | 2.461 | 10.53 | 7.830 |
| fold-002 | baseline | 4.73 | 4.74 | 0.300 | 28.53 | 0.167 |
| fold-003 | baseline | -4.56 | -4.56 | -0.354 | 11.03 | -0.415 |
| fold-004 | baseline | -7.63 | -7.63 | -0.477 | 14.18 | -0.540 |
| fold-005 | baseline | 27.08 | 27.10 | 1.500 | 8.89 | 3.056 |
| fold-006 | baseline | 8.36 | 8.37 | 0.624 | 13.43 | 0.625 |
| fold-007 | baseline | 8.79 | 8.79 | 0.458 | 13.36 | 0.660 |
| fold-008 | baseline | 5.31 | 5.31 | 0.457 | 11.10 | 0.480 |
| fold-009 | baseline | 9.02 | 9.03 | 0.545 | 18.64 | 0.486 |
| fold-010 | baseline | -4.63 | -4.63 | -0.089 | 17.38 | -0.267 |
| fold-011 | baseline | 9.54 | 9.55 | 0.599 | 16.61 | 0.577 |
| fold-012 | baseline | 34.11 | 34.14 | 1.296 | 19.84 | 1.726 |
| fold-013 | baseline | 4.82 | 4.83 | 0.350 | 17.94 | 0.270 |
| fold-014 | baseline | 19.70 | 19.72 | 1.298 | 12.33 | 1.604 |
| fold-015 | baseline | 39.35 | 39.38 | 2.242 | 6.43 | 6.144 |
| fold-016 | baseline | 4.91 | 4.92 | 0.352 | 20.19 | 0.244 |
| fold-017 | baseline | 2.50 | 2.50 | 0.252 | 12.33 | 0.203 |
| fold-018 | baseline | 3.07 | 3.08 | 0.267 | 7.85 | 0.393 |
| fold-019 | baseline | 41.59 | 41.62 | 2.156 | 9.50 | 4.394 |
| fold-020 | baseline | -8.16 | -8.16 | -0.477 | 15.77 | -0.519 |
| fold-021 | baseline | 14.38 | 14.39 | 1.003 | 5.91 | 2.444 |
| fold-022 | baseline | 30.17 | 30.19 | 0.837 | 25.59 | 1.184 |
| fold-023 | baseline | 14.08 | 14.09 | 0.887 | 9.71 | 1.455 |
| fold-024 | baseline | 10.55 | 10.56 | 0.652 | 12.51 | 0.847 |
| fold-025 | baseline | 9.46 | 9.47 | 0.598 | 15.77 | 0.602 |
| fold-026 | baseline | -21.94 | -21.96 | -1.541 | 22.44 | -0.981 |
| fold-027 | baseline | 6.22 | 6.23 | 0.415 | 20.93 | 0.298 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| baseline | 13.21 ± 19.98 | 13.22 ± 19.99 | 0.637 ± 0.857 | 14.71 ± 5.61 | 1.251 ± 2.001 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 28 folds total; gate metric marked **\***):

| Variant | Sharpe wins* | Calmar wins | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|

## 4. Go/no-go verdict

Gate: variant wins ≥1 of 28 folds on **Sharpe** vs baseline `baseline`, no fold worse by Δ>0.3000.
