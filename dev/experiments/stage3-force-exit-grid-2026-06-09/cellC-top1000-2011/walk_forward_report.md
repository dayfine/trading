# Walk-forward CV report

## 1. Per-fold metrics

| Fold | Variant | Return % | CAGR % | Sharpe | MaxDD % | Calmar |
|------|---------|---------:|-------:|-------:|--------:|-------:|
| fold-000 | force_exit_off | -22.75 | -22.76 | -0.942 | 35.17 | -0.649 |
| fold-001 | force_exit_off | -12.98 | -12.99 | -0.059 | 16.72 | -0.210 |
| fold-002 | force_exit_off | 39.69 | 39.72 | 1.701 | 7.26 | 4.043 |
| fold-003 | force_exit_off | 17.53 | 17.55 | 0.394 | 9.43 | 0.456 |
| fold-004 | force_exit_off | 16.35 | 16.36 | 0.797 | 9.04 | 1.154 |
| fold-005 | force_exit_off | 10.31 | 10.32 | 0.704 | 14.11 | 0.732 |
| fold-006 | force_exit_off | 17.91 | 17.93 | 0.879 | 6.69 | 1.718 |
| fold-007 | force_exit_off | 18.12 | 18.13 | 0.565 | 9.09 | 0.974 |
| fold-008 | force_exit_off | -12.16 | -12.17 | 0.838 | 8.52 | 1.056 |
| fold-009 | force_exit_off | 25.90 | 25.92 | 0.578 | 20.87 | 0.493 |
| fold-010 | force_exit_off | 56.14 | 56.19 | 0.620 | 60.45 | 0.322 |
| fold-011 | force_exit_off | -26.73 | -26.74 | -1.699 | 27.53 | -0.920 |
| fold-012 | force_exit_off | -8.14 | -8.15 | 0.394 | 19.02 | 0.248 |
| fold-013 | force_exit_off | 28.50 | 28.53 | 0.644 | 9.29 | 0.909 |
| fold-014 | force_exit_off | 2.71 | 2.71 | 0.503 | 20.71 | 0.335 |
| fold-000 | baseline | -22.75 | -22.76 | -0.942 | 35.17 | -0.649 |
| fold-001 | baseline | -12.29 | -12.30 | -0.025 | 16.72 | -0.164 |
| fold-002 | baseline | 39.69 | 39.72 | 1.701 | 7.26 | 4.043 |
| fold-003 | baseline | 17.53 | 17.55 | 0.394 | 9.43 | 0.456 |
| fold-004 | baseline | 16.35 | 16.36 | 0.797 | 9.04 | 1.154 |
| fold-005 | baseline | 10.31 | 10.32 | 0.704 | 14.11 | 0.732 |
| fold-006 | baseline | 17.91 | 17.93 | 0.879 | 6.69 | 1.718 |
| fold-007 | baseline | 17.68 | 17.70 | 0.879 | 15.46 | 1.095 |
| fold-008 | baseline | -12.16 | -12.17 | 0.838 | 8.52 | 1.056 |
| fold-009 | baseline | 25.90 | 25.92 | 0.578 | 20.87 | 0.493 |
| fold-010 | baseline | 56.14 | 56.19 | 0.620 | 60.45 | 0.322 |
| fold-011 | baseline | -26.73 | -26.74 | -1.699 | 27.53 | -0.920 |
| fold-012 | baseline | -8.14 | -8.15 | 0.394 | 19.02 | 0.248 |
| fold-013 | baseline | 28.50 | 28.53 | 0.644 | 9.29 | 0.909 |
| fold-014 | baseline | 2.71 | 2.71 | 0.503 | 20.71 | 0.335 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| force_exit_off | 10.03 ± 23.38 | 10.04 ± 23.40 | 0.394 ± 0.800 | 18.26 ± 14.30 | 0.711 ± 1.150 |
| baseline | 10.04 ± 23.32 | 10.05 ± 23.34 | 0.418 ± 0.807 | 18.68 ± 14.10 | 0.722 ± 1.150 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 15 folds total; gate metric marked **\***):

| Variant | Sharpe wins* | Calmar wins | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|
| force_exit_off | 0 | 0 | 1 | 1 | 15 |

## 4. Go/no-go verdict

Gate: variant wins ≥8 of 15 folds on **Sharpe** vs baseline `baseline`, no fold worse by Δ>0.3000.

- **force_exit_off**: FAIL (0 / 15 wins; worst fold `fold-007` gap 0.3135). Reason: M-threshold miss: 0 wins < 8 required; worst fold fold-007 trails by 0.3135 > Δ=0.3000