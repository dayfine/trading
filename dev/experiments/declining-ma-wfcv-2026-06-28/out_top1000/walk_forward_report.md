# Walk-forward CV report

## 1. Per-fold metrics

| Fold | Variant | Return % | CAGR % | Sharpe | MaxDD % | Calmar |
|------|---------|---------:|-------:|-------:|--------:|-------:|
| fold-000 | baseline | 23.74 | 11.25 | 0.756 | 18.18 | 0.619 |
| fold-001 | baseline | 10.13 | 4.94 | 0.439 | 11.02 | 0.449 |
| fold-002 | baseline | 34.68 | 16.06 | 1.136 | 8.76 | 1.836 |
| fold-003 | baseline | 14.36 | 6.94 | 0.508 | 20.99 | 0.331 |
| fold-004 | baseline | 28.13 | 13.21 | 0.840 | 15.41 | 0.858 |
| fold-005 | baseline | 1.46 | 0.73 | 0.122 | 14.81 | 0.049 |
| fold-006 | baseline | 21.88 | 10.41 | 0.844 | 17.44 | 0.598 |
| fold-007 | baseline | 34.46 | 15.97 | 1.198 | 9.74 | 1.641 |
| fold-008 | baseline | 32.10 | 14.95 | 1.115 | 10.95 | 1.367 |
| fold-009 | baseline | 10.77 | 5.25 | 0.438 | 17.37 | 0.303 |
| fold-010 | baseline | 47.74 | 21.57 | 1.230 | 11.75 | 1.838 |
| fold-011 | baseline | 5.99 | 2.95 | 0.307 | 19.68 | 0.150 |
| fold-012 | baseline | -15.84 | -8.26 | -0.443 | 38.08 | -0.217 |
| fold-000 | declining_ma_gate_on | 23.74 | 11.25 | 0.756 | 18.18 | 0.619 |
| fold-001 | declining_ma_gate_on | 10.13 | 4.94 | 0.439 | 11.02 | 0.449 |
| fold-002 | declining_ma_gate_on | 34.68 | 16.06 | 1.136 | 8.76 | 1.836 |
| fold-003 | declining_ma_gate_on | 14.36 | 6.94 | 0.508 | 20.99 | 0.331 |
| fold-004 | declining_ma_gate_on | 28.13 | 13.21 | 0.840 | 15.41 | 0.858 |
| fold-005 | declining_ma_gate_on | 1.46 | 0.73 | 0.122 | 14.81 | 0.049 |
| fold-006 | declining_ma_gate_on | 21.88 | 10.41 | 0.844 | 17.44 | 0.598 |
| fold-007 | declining_ma_gate_on | 34.46 | 15.97 | 1.198 | 9.74 | 1.641 |
| fold-008 | declining_ma_gate_on | 32.10 | 14.95 | 1.115 | 10.95 | 1.367 |
| fold-009 | declining_ma_gate_on | 10.95 | 5.34 | 0.444 | 17.37 | 0.308 |
| fold-010 | declining_ma_gate_on | 47.74 | 21.57 | 1.230 | 11.75 | 1.838 |
| fold-011 | declining_ma_gate_on | 5.99 | 2.95 | 0.307 | 19.68 | 0.150 |
| fold-012 | declining_ma_gate_on | -16.03 | -8.37 | -0.443 | 38.03 | -0.220 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| baseline | 19.20 ± 16.97 | 8.92 ± 7.93 | 0.653 ± 0.489 | 16.48 ± 7.60 | 0.756 ± 0.698 |
| declining_ma_gate_on | 19.20 ± 16.99 | 8.92 ± 7.94 | 0.654 ± 0.489 | 16.47 ± 7.59 | 0.756 ± 0.698 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 13 folds total; gate metric marked **\***):

| Variant | Sharpe wins* | Calmar wins | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|
| declining_ma_gate_on | 1 | 1 | 1 | 1 | 13 |

## 4. Go/no-go verdict

Gate: variant wins ≥7 of 13 folds on **Sharpe** vs baseline `baseline`, no fold worse by Δ>0.3000.

- **declining_ma_gate_on**: FAIL (1 / 13 wins; worst fold `fold-012` gap 0.0003). Reason: M-threshold miss: 1 wins < 7 required