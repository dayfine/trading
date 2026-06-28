# Walk-forward CV report

## 1. Per-fold metrics

| Fold | Variant | Return % | CAGR % | Sharpe | MaxDD % | Calmar |
|------|---------|---------:|-------:|-------:|--------:|-------:|
| fold-000 | baseline | 48.93 | 22.05 | 1.197 | 9.53 | 2.317 |
| fold-001 | baseline | 9.95 | 4.86 | 0.513 | 9.63 | 0.505 |
| fold-002 | baseline | 75.93 | 32.66 | 2.004 | 7.57 | 4.323 |
| fold-003 | baseline | 29.85 | 13.96 | 0.992 | 14.31 | 0.977 |
| fold-004 | baseline | -4.07 | -2.06 | -0.096 | 15.48 | -0.133 |
| fold-005 | baseline | 22.14 | 10.52 | 0.743 | 12.45 | 0.847 |
| fold-006 | baseline | 29.92 | 13.99 | 1.173 | 8.54 | 1.641 |
| fold-007 | baseline | 12.13 | 5.89 | 0.538 | 11.06 | 0.533 |
| fold-008 | baseline | 41.11 | 18.80 | 1.631 | 11.41 | 1.651 |
| fold-009 | baseline | 7.67 | 3.77 | 0.364 | 13.15 | 0.287 |
| fold-010 | baseline | 27.20 | 12.79 | 0.732 | 15.55 | 0.824 |
| fold-011 | baseline | -14.47 | -7.52 | -0.416 | 22.18 | -0.340 |
| fold-012 | baseline | 0.10 | 0.05 | 0.061 | 14.17 | 0.004 |
| fold-000 | declining_ma_gate_on | 48.93 | 22.05 | 1.197 | 9.53 | 2.317 |
| fold-001 | declining_ma_gate_on | 9.95 | 4.86 | 0.513 | 9.63 | 0.505 |
| fold-002 | declining_ma_gate_on | 75.93 | 32.66 | 2.004 | 7.57 | 4.323 |
| fold-003 | declining_ma_gate_on | 29.85 | 13.96 | 0.992 | 14.31 | 0.977 |
| fold-004 | declining_ma_gate_on | -4.07 | -2.06 | -0.096 | 15.48 | -0.133 |
| fold-005 | declining_ma_gate_on | 22.14 | 10.52 | 0.743 | 12.45 | 0.847 |
| fold-006 | declining_ma_gate_on | 29.92 | 13.99 | 1.173 | 8.54 | 1.641 |
| fold-007 | declining_ma_gate_on | 12.13 | 5.89 | 0.538 | 11.06 | 0.533 |
| fold-008 | declining_ma_gate_on | 41.11 | 18.80 | 1.631 | 11.41 | 1.651 |
| fold-009 | declining_ma_gate_on | 7.67 | 3.77 | 0.364 | 13.15 | 0.287 |
| fold-010 | declining_ma_gate_on | 27.20 | 12.79 | 0.732 | 15.55 | 0.824 |
| fold-011 | declining_ma_gate_on | -14.65 | -7.62 | -0.421 | 22.34 | -0.342 |
| fold-012 | declining_ma_gate_on | 0.10 | 0.05 | 0.061 | 14.17 | 0.004 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| baseline | 22.03 ± 24.30 | 9.98 ± 10.84 | 0.726 ± 0.682 | 12.69 ± 3.85 | 1.034 ± 1.248 |
| declining_ma_gate_on | 22.02 ± 24.33 | 9.98 ± 10.85 | 0.725 ± 0.683 | 12.71 ± 3.89 | 1.033 ± 1.248 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 13 folds total; gate metric marked **\***):

| Variant | Sharpe wins* | Calmar wins | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|
| declining_ma_gate_on | 0 | 0 | 0 | 0 | 13 |

## 4. Go/no-go verdict

Gate: variant wins ≥7 of 13 folds on **Sharpe** vs baseline `baseline`, no fold worse by Δ>0.3000.

- **declining_ma_gate_on**: FAIL (0 / 13 wins; worst fold `fold-011` gap 0.0057). Reason: M-threshold miss: 0 wins < 7 required