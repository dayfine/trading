# Walk-forward CV report

## 1. Per-fold metrics

| Fold | Variant | Return % | CAGR % | Sharpe | MaxDD % | Calmar |
|------|---------|---------:|-------:|-------:|--------:|-------:|
| fold-000 | baseline | 7.86 | 3.86 | 0.277 | 28.24 | 0.137 |
| fold-001 | baseline | 1.08 | 0.54 | 0.102 | 9.53 | 0.057 |
| fold-002 | baseline | 9.63 | 4.71 | 0.378 | 12.80 | 0.368 |
| fold-003 | baseline | 9.38 | 4.59 | 0.384 | 14.30 | 0.321 |
| fold-004 | baseline | 25.02 | 11.82 | 0.736 | 12.08 | 0.980 |
| fold-005 | baseline | 5.31 | 2.62 | 0.257 | 15.94 | 0.165 |
| fold-006 | baseline | 42.60 | 19.43 | 1.272 | 15.25 | 1.276 |
| fold-007 | baseline | 41.69 | 19.05 | 1.417 | 6.88 | 2.771 |
| fold-008 | baseline | 23.19 | 11.00 | 0.716 | 12.75 | 0.864 |
| fold-009 | baseline | -8.65 | -4.43 | -0.253 | 21.45 | -0.207 |
| fold-010 | baseline | 51.55 | 23.12 | 0.819 | 25.59 | 0.905 |
| fold-011 | baseline | 26.32 | 12.40 | 0.749 | 18.97 | 0.655 |
| fold-012 | baseline | -26.91 | -14.52 | -1.004 | 35.58 | -0.409 |
| fold-000 | declining_ma_gate_on | 7.86 | 3.86 | 0.277 | 28.24 | 0.137 |
| fold-001 | declining_ma_gate_on | 1.08 | 0.54 | 0.102 | 9.53 | 0.057 |
| fold-002 | declining_ma_gate_on | 9.63 | 4.71 | 0.378 | 12.80 | 0.368 |
| fold-003 | declining_ma_gate_on | 9.38 | 4.59 | 0.384 | 14.30 | 0.321 |
| fold-004 | declining_ma_gate_on | 25.02 | 11.82 | 0.736 | 12.08 | 0.980 |
| fold-005 | declining_ma_gate_on | 5.31 | 2.62 | 0.257 | 15.94 | 0.165 |
| fold-006 | declining_ma_gate_on | 42.60 | 19.43 | 1.272 | 15.25 | 1.276 |
| fold-007 | declining_ma_gate_on | 41.69 | 19.05 | 1.417 | 6.88 | 2.771 |
| fold-008 | declining_ma_gate_on | 23.19 | 11.00 | 0.716 | 12.75 | 0.864 |
| fold-009 | declining_ma_gate_on | 4.07 | 2.01 | 0.211 | 20.04 | 0.101 |
| fold-010 | declining_ma_gate_on | 62.33 | 27.43 | 0.932 | 21.01 | 1.308 |
| fold-011 | declining_ma_gate_on | 26.32 | 12.40 | 0.749 | 18.97 | 0.655 |
| fold-012 | declining_ma_gate_on | -26.91 | -14.52 | -1.004 | 35.58 | -0.409 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| baseline | 16.01 ± 22.00 | 7.25 ± 10.42 | 0.450 ± 0.632 | 17.64 ± 8.13 | 0.606 ± 0.815 |
| declining_ma_gate_on | 17.81 ± 22.70 | 8.07 ± 10.57 | 0.495 ± 0.607 | 17.18 ± 7.80 | 0.661 ± 0.813 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 13 folds total; gate metric marked **\***):

| Variant | Sharpe wins* | Calmar wins | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|
| declining_ma_gate_on | 2 | 2 | 2 | 2 | 13 |

## 4. Go/no-go verdict

Gate: variant wins ≥7 of 13 folds on **Sharpe** vs baseline `baseline`, no fold worse by Δ>0.3000.

- **declining_ma_gate_on**: FAIL (2 / 13 wins; worst fold `fold-000` gap 0.0000). Reason: M-threshold miss: 2 wins < 7 required