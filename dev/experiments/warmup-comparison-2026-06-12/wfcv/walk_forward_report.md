# Walk-forward CV report

## 1. Per-fold metrics

| Fold | Variant | Return % | CAGR % | Sharpe | MaxDD % | Calmar |
|------|---------|---------:|-------:|-------:|--------:|-------:|
| fold-000 | baseline | -25.91 | -25.92 | -0.848 | 18.53 | -0.834 |
| fold-001 | baseline | 38.31 | 38.34 | 1.374 | 14.05 | 2.738 |
| fold-002 | baseline | 50.61 | 50.66 | 1.310 | 9.67 | 2.225 |
| fold-003 | baseline | 31.82 | 31.84 | 0.555 | 20.97 | 0.438 |
| fold-004 | baseline | 24.05 | 24.07 | -0.037 | 19.75 | -0.090 |
| fold-005 | baseline | -4.65 | -4.66 | -0.477 | 15.37 | -0.525 |
| fold-006 | baseline | -23.41 | -23.42 | -2.390 | 24.27 | -0.790 |
| fold-007 | baseline | -11.03 | -11.03 | -0.029 | 18.23 | -0.131 |
| fold-008 | baseline | 49.36 | 49.40 | 0.575 | 29.34 | 0.468 |
| fold-009 | baseline | 16.22 | 16.23 | 0.178 | 29.59 | -0.067 |
| fold-010 | baseline | -21.94 | -21.96 | -0.688 | 17.68 | -0.424 |
| fold-011 | baseline | 38.34 | 38.37 | 2.051 | 5.14 | 6.758 |
| fold-012 | baseline | 21.92 | 21.94 | 0.694 | 7.98 | 0.957 |
| fold-013 | baseline | 40.56 | 40.59 | 1.097 | 19.16 | 1.969 |
| fold-014 | baseline | 13.24 | 13.25 | 0.730 | 13.33 | 0.811 |
| fold-015 | baseline | 54.87 | 54.91 | 1.922 | 8.32 | 4.177 |
| fold-016 | baseline | 2.22 | 2.22 | 0.263 | 20.30 | 0.166 |
| fold-017 | baseline | 10.51 | 10.52 | 0.419 | 9.70 | 0.498 |
| fold-018 | baseline | 32.65 | 32.68 | 0.928 | 18.00 | 0.994 |
| fold-019 | baseline | 29.55 | 29.57 | 0.902 | 9.34 | 1.409 |
| fold-020 | baseline | -6.78 | -6.78 | -1.471 | 18.78 | -0.829 |
| fold-021 | baseline | 8.56 | 8.57 | 1.128 | 15.30 | 1.084 |
| fold-000 | suppress_warmup_trading=true | -8.00 | -8.00 | -0.519 | 16.64 | -0.482 |
| fold-001 | suppress_warmup_trading=true | 38.31 | 38.34 | 1.374 | 14.05 | 2.738 |
| fold-002 | suppress_warmup_trading=true | -3.01 | -3.02 | -0.132 | 14.31 | -0.211 |
| fold-003 | suppress_warmup_trading=true | 5.85 | 5.86 | 0.455 | 19.84 | 0.296 |
| fold-004 | suppress_warmup_trading=true | -5.06 | -5.06 | -0.343 | 18.76 | -0.270 |
| fold-005 | suppress_warmup_trading=true | -6.05 | -6.05 | -0.276 | 22.54 | -0.269 |
| fold-006 | suppress_warmup_trading=true | -12.03 | -12.04 | -1.868 | 12.26 | -0.984 |
| fold-007 | suppress_warmup_trading=true | -2.38 | -2.38 | -0.029 | 18.24 | -0.131 |
| fold-008 | suppress_warmup_trading=true | 9.65 | 9.66 | 0.580 | 18.07 | 0.536 |
| fold-009 | suppress_warmup_trading=true | -14.30 | -14.31 | -0.876 | 25.11 | -0.571 |
| fold-010 | suppress_warmup_trading=true | -3.43 | -3.43 | -0.246 | 15.77 | -0.218 |
| fold-011 | suppress_warmup_trading=true | 20.88 | 20.90 | 1.256 | 8.72 | 2.403 |
| fold-012 | suppress_warmup_trading=true | -4.19 | -4.19 | -0.290 | 19.05 | -0.221 |
| fold-013 | suppress_warmup_trading=true | 27.50 | 27.52 | 0.849 | 23.13 | 1.194 |
| fold-014 | suppress_warmup_trading=true | 17.64 | 17.65 | 1.142 | 13.33 | 1.329 |
| fold-015 | suppress_warmup_trading=true | 45.29 | 45.33 | 2.318 | 10.37 | 4.387 |
| fold-016 | suppress_warmup_trading=true | -3.08 | -3.09 | -0.080 | 18.07 | -0.171 |
| fold-017 | suppress_warmup_trading=true | 10.97 | 10.98 | 0.853 | 9.31 | 1.183 |
| fold-018 | suppress_warmup_trading=true | 29.95 | 29.97 | 1.424 | 13.24 | 2.271 |
| fold-019 | suppress_warmup_trading=true | 10.56 | 10.56 | 0.768 | 9.22 | 1.149 |
| fold-020 | suppress_warmup_trading=true | -16.13 | -16.14 | -1.567 | 20.18 | -0.802 |
| fold-021 | suppress_warmup_trading=true | 11.14 | 11.15 | 0.760 | 12.12 | 0.923 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| baseline | 16.78 ± 24.81 | 16.79 ± 24.83 | 0.372 ± 1.065 | 16.49 ± 6.53 | 0.955 ± 1.803 |
| suppress_warmup_trading=true | 6.82 ± 17.14 | 6.83 ± 17.15 | 0.252 ± 1.006 | 16.01 ± 4.71 | 0.640 ± 1.351 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 22 folds total; gate metric marked **\***):

| Variant | Sharpe wins* | Calmar wins | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|
| suppress_warmup_trading=true | 9 | 9 | 7 | 13 | 22 |

## 4. Go/no-go verdict

Gate: variant wins ≥11 of 22 folds on **Sharpe** vs baseline `baseline`, no fold worse by Δ>0.3000.

- **suppress_warmup_trading=true**: FAIL (9 / 22 wins; worst fold `fold-002` gap 1.4415). Reason: M-threshold miss: 9 wins < 11 required; worst fold fold-002 trails by 1.4415 > Δ=0.3000