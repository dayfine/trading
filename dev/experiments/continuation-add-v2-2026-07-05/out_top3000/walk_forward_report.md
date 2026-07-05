# Walk-forward CV report

## 1. Per-fold metrics

| Fold | Variant | Return % | CAGR % | Sharpe | MaxDD % | Calmar |
|------|---------|---------:|-------:|-------:|--------:|-------:|
| fold-000 | baseline | 5.39 | 2.66 | 0.254 | 10.28 | 0.259 |
| fold-001 | baseline | 12.24 | 5.95 | 0.489 | 12.81 | 0.465 |
| fold-002 | baseline | 4.75 | 2.35 | 0.234 | 15.85 | 0.148 |
| fold-003 | baseline | 36.32 | 16.77 | 1.087 | 14.18 | 1.184 |
| fold-004 | baseline | 18.71 | 8.96 | 0.616 | 15.38 | 0.583 |
| fold-005 | baseline | 20.72 | 9.88 | 0.611 | 15.58 | 0.635 |
| fold-006 | baseline | 33.66 | 15.62 | 1.190 | 12.29 | 1.273 |
| fold-007 | baseline | 30.15 | 14.10 | 1.157 | 8.90 | 1.586 |
| fold-008 | baseline | 16.56 | 7.97 | 0.576 | 16.30 | 0.489 |
| fold-009 | baseline | 17.97 | 8.62 | 0.558 | 11.24 | 0.768 |
| fold-010 | baseline | 71.99 | 31.17 | 1.296 | 18.45 | 1.692 |
| fold-011 | baseline | -10.20 | -5.24 | -0.421 | 23.64 | -0.222 |
| fold-012 | baseline | 0.69 | 0.34 | 0.112 | 24.75 | 0.014 |
| fold-000 | cont_add | 5.39 | 2.66 | 0.254 | 10.28 | 0.259 |
| fold-001 | cont_add | 12.24 | 5.95 | 0.489 | 12.81 | 0.465 |
| fold-002 | cont_add | 4.50 | 2.23 | 0.225 | 15.85 | 0.141 |
| fold-003 | cont_add | 36.32 | 16.77 | 1.087 | 14.18 | 1.184 |
| fold-004 | cont_add | 18.71 | 8.96 | 0.616 | 15.38 | 0.583 |
| fold-005 | cont_add | 20.83 | 9.93 | 0.614 | 15.49 | 0.642 |
| fold-006 | cont_add | 33.66 | 15.62 | 1.190 | 12.29 | 1.273 |
| fold-007 | cont_add | 14.41 | 6.97 | 0.660 | 8.90 | 0.784 |
| fold-008 | cont_add | 15.13 | 7.31 | 0.537 | 16.30 | 0.449 |
| fold-009 | cont_add | 10.86 | 5.29 | 0.386 | 13.28 | 0.399 |
| fold-010 | cont_add | 82.65 | 35.17 | 1.413 | 18.45 | 1.909 |
| fold-011 | cont_add | -6.99 | -3.56 | -0.251 | 23.33 | -0.153 |
| fold-012 | cont_add | 2.28 | 1.14 | 0.153 | 27.03 | 0.042 |
| fold-000 | cont_add_tight | 5.39 | 2.66 | 0.254 | 10.28 | 0.259 |
| fold-001 | cont_add_tight | 12.24 | 5.95 | 0.489 | 12.81 | 0.465 |
| fold-002 | cont_add_tight | 5.52 | 2.73 | 0.260 | 15.85 | 0.172 |
| fold-003 | cont_add_tight | 36.32 | 16.77 | 1.087 | 14.18 | 1.184 |
| fold-004 | cont_add_tight | 18.71 | 8.96 | 0.616 | 15.38 | 0.583 |
| fold-005 | cont_add_tight | 20.72 | 9.88 | 0.611 | 15.58 | 0.635 |
| fold-006 | cont_add_tight | 33.66 | 15.62 | 1.190 | 12.29 | 1.273 |
| fold-007 | cont_add_tight | 14.41 | 6.97 | 0.660 | 8.90 | 0.784 |
| fold-008 | cont_add_tight | 15.13 | 7.31 | 0.537 | 16.30 | 0.449 |
| fold-009 | cont_add_tight | 18.49 | 8.86 | 0.568 | 12.29 | 0.722 |
| fold-010 | cont_add_tight | 71.99 | 31.17 | 1.296 | 18.45 | 1.692 |
| fold-011 | cont_add_tight | -12.29 | -6.35 | -0.509 | 23.40 | -0.272 |
| fold-012 | cont_add_tight | 8.21 | 4.03 | 0.305 | 21.93 | 0.184 |
| fold-000 | cont_add_vol | 5.39 | 2.66 | 0.254 | 10.28 | 0.259 |
| fold-001 | cont_add_vol | 12.24 | 5.95 | 0.489 | 12.81 | 0.465 |
| fold-002 | cont_add_vol | 4.50 | 2.23 | 0.225 | 15.85 | 0.141 |
| fold-003 | cont_add_vol | 36.32 | 16.77 | 1.087 | 14.18 | 1.184 |
| fold-004 | cont_add_vol | 18.71 | 8.96 | 0.616 | 15.38 | 0.583 |
| fold-005 | cont_add_vol | 20.83 | 9.93 | 0.614 | 15.49 | 0.642 |
| fold-006 | cont_add_vol | 33.66 | 15.62 | 1.190 | 12.29 | 1.273 |
| fold-007 | cont_add_vol | 29.77 | 13.93 | 1.143 | 8.90 | 1.567 |
| fold-008 | cont_add_vol | 15.13 | 7.31 | 0.537 | 16.30 | 0.449 |
| fold-009 | cont_add_vol | 10.86 | 5.29 | 0.386 | 13.28 | 0.399 |
| fold-010 | cont_add_vol | 82.65 | 35.17 | 1.413 | 18.45 | 1.909 |
| fold-011 | cont_add_vol | -9.33 | -4.78 | -0.378 | 23.20 | -0.206 |
| fold-012 | cont_add_vol | 2.28 | 1.14 | 0.153 | 27.03 | 0.042 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| baseline | 19.92 ± 20.55 | 9.16 ± 9.11 | 0.597 ± 0.494 | 15.36 ± 4.74 | 0.683 ± 0.596 |
| cont_add | 19.23 ± 22.49 | 8.80 ± 9.68 | 0.567 ± 0.455 | 15.66 ± 4.99 | 0.614 ± 0.565 |
| cont_add_tight | 19.12 ± 20.15 | 8.81 ± 8.91 | 0.566 ± 0.468 | 15.20 ± 4.21 | 0.625 ± 0.525 |
| cont_add_vol | 20.23 ± 22.86 | 9.24 ± 9.91 | 0.595 ± 0.502 | 15.65 ± 4.97 | 0.670 ± 0.629 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 13 folds total; gate metric marked **\***):

| Variant | Sharpe wins* | Calmar wins | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|
| cont_add | 4 | 4 | 4 | 2 | 13 |
| cont_add_tight | 3 | 2 | 3 | 2 | 13 |
| cont_add_vol | 4 | 4 | 4 | 2 | 13 |

## 4. Go/no-go verdict

Gate: variant wins ≥7 of 13 folds on **Sharpe** vs baseline `baseline`, no fold worse by Δ>0.3000.

- **cont_add**: FAIL (4 / 13 wins; worst fold `fold-007` gap 0.4973). Reason: M-threshold miss: 4 wins < 7 required; worst fold fold-007 trails by 0.4973 > Δ=0.3000
- **cont_add_tight**: FAIL (3 / 13 wins; worst fold `fold-007` gap 0.4973). Reason: M-threshold miss: 3 wins < 7 required; worst fold fold-007 trails by 0.4973 > Δ=0.3000
- **cont_add_vol**: FAIL (4 / 13 wins; worst fold `fold-009` gap 0.1717). Reason: M-threshold miss: 4 wins < 7 required