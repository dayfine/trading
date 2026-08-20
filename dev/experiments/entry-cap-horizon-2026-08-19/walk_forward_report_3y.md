# Walk-forward CV report

## 1. Per-fold metrics

| Fold | Variant | Return % | CAGR % | Sharpe | MaxDD % | Calmar |
|------|---------|---------:|-------:|-------:|--------:|-------:|
| fold-000 | baseline | 57.08 | 16.26 | 1.257 | 12.63 | 1.289 |
| fold-001 | baseline | 50.82 | 14.69 | 1.296 | 10.02 | 1.468 |
| fold-002 | baseline | 3.97 | 1.31 | 0.183 | 21.45 | 0.061 |
| fold-003 | baseline | 61.75 | 17.40 | 1.142 | 14.54 | 1.198 |
| fold-004 | baseline | 53.84 | 15.45 | 1.109 | 13.48 | 1.147 |
| fold-000 | entry_extension_max_pct=1.0 | 56.48 | 16.11 | 1.257 | 12.58 | 1.282 |
| fold-001 | entry_extension_max_pct=1.0 | 56.03 | 16.00 | 1.382 | 9.93 | 1.612 |
| fold-002 | entry_extension_max_pct=1.0 | -0.04 | -0.01 | 0.047 | 20.51 | -0.001 |
| fold-003 | entry_extension_max_pct=1.0 | 63.41 | 17.80 | 1.169 | 14.26 | 1.249 |
| fold-004 | entry_extension_max_pct=1.0 | 42.92 | 12.65 | 0.950 | 14.61 | 0.867 |
| fold-000 | entry_extension_max_pct=2.0 | 57.08 | 16.26 | 1.257 | 12.63 | 1.289 |
| fold-001 | entry_extension_max_pct=2.0 | 50.82 | 14.69 | 1.296 | 10.02 | 1.468 |
| fold-002 | entry_extension_max_pct=2.0 | 3.97 | 1.31 | 0.183 | 21.45 | 0.061 |
| fold-003 | entry_extension_max_pct=2.0 | 61.75 | 17.40 | 1.142 | 14.54 | 1.198 |
| fold-004 | entry_extension_max_pct=2.0 | 53.84 | 15.45 | 1.109 | 13.48 | 1.147 |
| fold-000 | entry_extension_max_pct=5.0 | 51.82 | 14.94 | 1.185 | 11.21 | 1.334 |
| fold-001 | entry_extension_max_pct=5.0 | 32.77 | 9.92 | 0.953 | 8.60 | 1.154 |
| fold-002 | entry_extension_max_pct=5.0 | -2.40 | -0.81 | -0.036 | 21.10 | -0.038 |
| fold-003 | entry_extension_max_pct=5.0 | 53.72 | 15.42 | 1.010 | 15.68 | 0.984 |
| fold-004 | entry_extension_max_pct=5.0 | 51.67 | 14.91 | 1.073 | 13.49 | 1.106 |
| fold-000 | entry_extension_max_pct=10.0 | 55.72 | 15.92 | 1.269 | 11.11 | 1.434 |
| fold-001 | entry_extension_max_pct=10.0 | 32.64 | 9.88 | 0.950 | 8.60 | 1.150 |
| fold-002 | entry_extension_max_pct=10.0 | 4.92 | 1.61 | 0.214 | 15.18 | 0.106 |
| fold-003 | entry_extension_max_pct=10.0 | 55.90 | 15.97 | 1.056 | 14.63 | 1.092 |
| fold-004 | entry_extension_max_pct=10.0 | 48.89 | 14.20 | 1.050 | 13.48 | 1.054 |
| fold-000 | entry_extension_max_pct=15.0 | 55.72 | 15.92 | 1.269 | 11.11 | 1.434 |
| fold-001 | entry_extension_max_pct=15.0 | 32.64 | 9.88 | 0.950 | 8.60 | 1.150 |
| fold-002 | entry_extension_max_pct=15.0 | 4.92 | 1.61 | 0.214 | 15.18 | 0.106 |
| fold-003 | entry_extension_max_pct=15.0 | 55.90 | 15.97 | 1.056 | 14.63 | 1.092 |
| fold-004 | entry_extension_max_pct=15.0 | 48.53 | 14.11 | 1.044 | 13.49 | 1.047 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| baseline | 45.49 ± 23.56 | 13.02 ± 6.63 | 0.998 ± 0.462 | 14.42 ± 4.27 | 1.033 ± 0.557 |
| entry_extension_max_pct=1.0 | 43.76 ± 25.58 | 12.51 ± 7.24 | 0.961 ± 0.535 | 14.38 ± 3.89 | 1.002 ± 0.619 |
| entry_extension_max_pct=2.0 | 45.49 ± 23.56 | 13.02 ± 6.63 | 0.998 ± 0.462 | 14.42 ± 4.27 | 1.033 ± 0.557 |
| entry_extension_max_pct=5.0 | 37.52 ± 23.89 | 10.88 ± 6.91 | 0.837 ± 0.496 | 14.02 ± 4.75 | 0.908 ± 0.544 |
| entry_extension_max_pct=10.0 | 39.62 ± 21.58 | 11.52 ± 6.06 | 0.908 ± 0.405 | 12.60 ± 2.73 | 0.967 ± 0.504 |
| entry_extension_max_pct=15.0 | 39.54 ± 21.54 | 11.50 ± 6.05 | 0.907 ± 0.404 | 12.60 ± 2.73 | 0.966 ± 0.504 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 5 folds total; gate metric marked **\***):

| Variant | Sharpe wins | Calmar wins* | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|
| entry_extension_max_pct=1.0 | 2 | 2 | 2 | 4 | 5 |
| entry_extension_max_pct=2.0 | 0 | 0 | 0 | 0 | 5 |
| entry_extension_max_pct=5.0 | 0 | 1 | 0 | 3 | 5 |
| entry_extension_max_pct=10.0 | 2 | 2 | 1 | 3 | 5 |
| entry_extension_max_pct=15.0 | 2 | 2 | 1 | 3 | 5 |

## 4. Go/no-go verdict

Gate: variant wins ≥3 of 5 folds on **Calmar** vs baseline `baseline`, no fold worse by Δ>0.0000.

- **entry_extension_max_pct=1.0**: FAIL (2 / 5 wins; worst fold `fold-004` gap 0.2805). Reason: M-threshold miss: 2 wins < 3 required; worst fold fold-004 trails by 0.2805 > Δ=0.0000
- **entry_extension_max_pct=2.0**: FAIL (0 / 5 wins; worst fold `fold-000` gap 0.0000). Reason: M-threshold miss: 0 wins < 3 required
- **entry_extension_max_pct=5.0**: FAIL (1 / 5 wins; worst fold `fold-001` gap 0.3134). Reason: M-threshold miss: 1 wins < 3 required; worst fold fold-001 trails by 0.3134 > Δ=0.0000
- **entry_extension_max_pct=10.0**: FAIL (2 / 5 wins; worst fold `fold-001` gap 0.3171). Reason: M-threshold miss: 2 wins < 3 required; worst fold fold-001 trails by 0.3171 > Δ=0.0000
- **entry_extension_max_pct=15.0**: FAIL (2 / 5 wins; worst fold `fold-001` gap 0.3171). Reason: M-threshold miss: 2 wins < 3 required; worst fold fold-001 trails by 0.3171 > Δ=0.0000