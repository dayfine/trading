# Walk-forward CV report

## 1. Per-fold metrics

| Fold | Variant | Return % | CAGR % | Sharpe | MaxDD % | Calmar |
|------|---------|---------:|-------:|-------:|--------:|-------:|
| fold-000 | baseline | -11.93 | -11.93 | -0.770 | 22.80 | -0.525 |
| fold-001 | baseline | 5.90 | 5.90 | 1.311 | 10.16 | 2.386 |
| fold-002 | baseline | 33.21 | 33.24 | 1.842 | 8.86 | 3.213 |
| fold-003 | baseline | 2.03 | 2.04 | -0.302 | 15.99 | -0.326 |
| fold-004 | baseline | 8.86 | 8.87 | 1.281 | 7.41 | 2.765 |
| fold-005 | baseline | 6.77 | 6.78 | 0.613 | 10.88 | 0.912 |
| fold-006 | baseline | 24.72 | 24.74 | 2.478 | 4.84 | 6.431 |
| fold-007 | baseline | 2.19 | 2.19 | -0.611 | 18.30 | -0.696 |
| fold-008 | baseline | -0.94 | -0.95 | 1.384 | 5.74 | 3.563 |
| fold-009 | baseline | 30.69 | 30.71 | 0.756 | 24.63 | 0.689 |
| fold-010 | baseline | 76.33 | 76.40 | 0.654 | 16.28 | 0.701 |
| fold-011 | baseline | -19.01 | -19.02 | -1.350 | 22.63 | -0.895 |
| fold-012 | baseline | 3.44 | 3.44 | 1.216 | 16.26 | 1.366 |
| fold-013 | baseline | 15.77 | 15.78 | 0.444 | 7.61 | 0.646 |
| fold-014 | baseline | 16.22 | 16.23 | 0.698 | 29.47 | 0.496 |
| fold-000 | enable_stage3_force_exit=true__enable_stage2_ma_hold=false | -11.93 | -11.93 | -0.770 | 22.80 | -0.525 |
| fold-001 | enable_stage3_force_exit=true__enable_stage2_ma_hold=false | 5.90 | 5.90 | 1.311 | 10.16 | 2.386 |
| fold-002 | enable_stage3_force_exit=true__enable_stage2_ma_hold=false | 33.21 | 33.24 | 1.842 | 8.86 | 3.213 |
| fold-003 | enable_stage3_force_exit=true__enable_stage2_ma_hold=false | 2.03 | 2.04 | -0.302 | 15.99 | -0.326 |
| fold-004 | enable_stage3_force_exit=true__enable_stage2_ma_hold=false | 8.86 | 8.87 | 1.281 | 7.41 | 2.765 |
| fold-005 | enable_stage3_force_exit=true__enable_stage2_ma_hold=false | 6.77 | 6.78 | 0.613 | 10.88 | 0.912 |
| fold-006 | enable_stage3_force_exit=true__enable_stage2_ma_hold=false | 24.72 | 24.74 | 2.478 | 4.84 | 6.431 |
| fold-007 | enable_stage3_force_exit=true__enable_stage2_ma_hold=false | 2.19 | 2.19 | -0.611 | 18.30 | -0.696 |
| fold-008 | enable_stage3_force_exit=true__enable_stage2_ma_hold=false | -0.94 | -0.95 | 1.384 | 5.74 | 3.563 |
| fold-009 | enable_stage3_force_exit=true__enable_stage2_ma_hold=false | 30.69 | 30.71 | 0.756 | 24.63 | 0.689 |
| fold-010 | enable_stage3_force_exit=true__enable_stage2_ma_hold=false | 76.33 | 76.40 | 0.654 | 16.28 | 0.701 |
| fold-011 | enable_stage3_force_exit=true__enable_stage2_ma_hold=false | -19.01 | -19.02 | -1.350 | 22.63 | -0.895 |
| fold-012 | enable_stage3_force_exit=true__enable_stage2_ma_hold=false | 3.44 | 3.44 | 1.216 | 16.26 | 1.366 |
| fold-013 | enable_stage3_force_exit=true__enable_stage2_ma_hold=false | 15.77 | 15.78 | 0.444 | 7.61 | 0.646 |
| fold-014 | enable_stage3_force_exit=true__enable_stage2_ma_hold=false | 16.22 | 16.23 | 0.698 | 29.47 | 0.496 |
| fold-000 | enable_stage3_force_exit=true__enable_stage2_ma_hold=true | -11.87 | -11.88 | -0.763 | 22.75 | -0.524 |
| fold-001 | enable_stage3_force_exit=true__enable_stage2_ma_hold=true | -2.53 | -2.54 | 0.849 | 10.41 | 1.239 |
| fold-002 | enable_stage3_force_exit=true__enable_stage2_ma_hold=true | 33.76 | 33.79 | 1.870 | 8.83 | 3.285 |
| fold-003 | enable_stage3_force_exit=true__enable_stage2_ma_hold=true | 8.25 | 8.25 | 0.110 | 11.22 | 0.051 |
| fold-004 | enable_stage3_force_exit=true__enable_stage2_ma_hold=true | 3.25 | 3.25 | 0.984 | 9.55 | 1.538 |
| fold-005 | enable_stage3_force_exit=true__enable_stage2_ma_hold=true | 13.25 | 13.26 | 0.938 | 11.98 | 1.387 |
| fold-006 | enable_stage3_force_exit=true__enable_stage2_ma_hold=true | 36.75 | 36.78 | 2.705 | 4.21 | 9.390 |
| fold-007 | enable_stage3_force_exit=true__enable_stage2_ma_hold=true | 2.19 | 2.19 | -0.611 | 18.30 | -0.696 |
| fold-008 | enable_stage3_force_exit=true__enable_stage2_ma_hold=true | -2.42 | -2.42 | 1.542 | 5.84 | 3.623 |
| fold-009 | enable_stage3_force_exit=true__enable_stage2_ma_hold=true | 28.50 | 28.52 | 0.717 | 22.50 | 0.667 |
| fold-010 | enable_stage3_force_exit=true__enable_stage2_ma_hold=true | 79.07 | 79.15 | 0.732 | 16.28 | 0.808 |
| fold-011 | enable_stage3_force_exit=true__enable_stage2_ma_hold=true | -18.66 | -18.67 | -1.349 | 22.61 | -0.895 |
| fold-012 | enable_stage3_force_exit=true__enable_stage2_ma_hold=true | 1.79 | 1.79 | 1.125 | 15.70 | 1.290 |
| fold-013 | enable_stage3_force_exit=true__enable_stage2_ma_hold=true | 10.51 | 10.52 | 0.055 | 11.99 | -0.015 |
| fold-014 | enable_stage3_force_exit=true__enable_stage2_ma_hold=true | -24.22 | -24.23 | -1.615 | 30.53 | -0.831 |
| fold-000 | enable_stage3_force_exit=false__enable_stage2_ma_hold=false | -11.93 | -11.93 | -0.770 | 22.80 | -0.525 |
| fold-001 | enable_stage3_force_exit=false__enable_stage2_ma_hold=false | 5.69 | 5.70 | 1.296 | 10.17 | 2.358 |
| fold-002 | enable_stage3_force_exit=false__enable_stage2_ma_hold=false | 33.21 | 33.24 | 1.842 | 8.86 | 3.213 |
| fold-003 | enable_stage3_force_exit=false__enable_stage2_ma_hold=false | 2.03 | 2.04 | -0.302 | 15.99 | -0.326 |
| fold-004 | enable_stage3_force_exit=false__enable_stage2_ma_hold=false | 8.86 | 8.87 | 1.281 | 7.41 | 2.765 |
| fold-005 | enable_stage3_force_exit=false__enable_stage2_ma_hold=false | 6.77 | 6.78 | 0.613 | 10.88 | 0.912 |
| fold-006 | enable_stage3_force_exit=false__enable_stage2_ma_hold=false | 40.92 | 40.95 | 3.261 | 4.73 | 10.317 |
| fold-007 | enable_stage3_force_exit=false__enable_stage2_ma_hold=false | -7.10 | -7.10 | -0.707 | 17.61 | -0.675 |
| fold-008 | enable_stage3_force_exit=false__enable_stage2_ma_hold=false | -0.94 | -0.95 | 1.384 | 5.74 | 3.563 |
| fold-009 | enable_stage3_force_exit=false__enable_stage2_ma_hold=false | 25.88 | 25.90 | 0.628 | 24.60 | 0.550 |
| fold-010 | enable_stage3_force_exit=false__enable_stage2_ma_hold=false | 76.26 | 76.33 | 0.652 | 16.31 | 0.697 |
| fold-011 | enable_stage3_force_exit=false__enable_stage2_ma_hold=false | -19.01 | -19.02 | -1.350 | 22.63 | -0.895 |
| fold-012 | enable_stage3_force_exit=false__enable_stage2_ma_hold=false | 3.44 | 3.44 | 1.216 | 16.26 | 1.366 |
| fold-013 | enable_stage3_force_exit=false__enable_stage2_ma_hold=false | 15.77 | 15.78 | 0.444 | 7.61 | 0.646 |
| fold-014 | enable_stage3_force_exit=false__enable_stage2_ma_hold=false | 16.22 | 16.23 | 0.698 | 29.47 | 0.496 |
| fold-000 | enable_stage3_force_exit=false__enable_stage2_ma_hold=true | -11.87 | -11.88 | -0.763 | 22.75 | -0.524 |
| fold-001 | enable_stage3_force_exit=false__enable_stage2_ma_hold=true | -2.53 | -2.54 | 0.849 | 10.41 | 1.239 |
| fold-002 | enable_stage3_force_exit=false__enable_stage2_ma_hold=true | 33.76 | 33.79 | 1.870 | 8.83 | 3.285 |
| fold-003 | enable_stage3_force_exit=false__enable_stage2_ma_hold=true | 8.25 | 8.25 | 0.110 | 11.22 | 0.051 |
| fold-004 | enable_stage3_force_exit=false__enable_stage2_ma_hold=true | 3.25 | 3.25 | 0.984 | 9.55 | 1.538 |
| fold-005 | enable_stage3_force_exit=false__enable_stage2_ma_hold=true | 13.25 | 13.26 | 0.938 | 11.98 | 1.387 |
| fold-006 | enable_stage3_force_exit=false__enable_stage2_ma_hold=true | 21.40 | 21.42 | 2.449 | 3.00 | 8.097 |
| fold-007 | enable_stage3_force_exit=false__enable_stage2_ma_hold=true | -9.15 | -9.16 | -0.874 | 19.49 | -0.711 |
| fold-008 | enable_stage3_force_exit=false__enable_stage2_ma_hold=true | -2.42 | -2.42 | 1.542 | 5.84 | 3.623 |
| fold-009 | enable_stage3_force_exit=false__enable_stage2_ma_hold=true | 42.35 | 42.38 | 1.169 | 20.91 | 1.360 |
| fold-010 | enable_stage3_force_exit=false__enable_stage2_ma_hold=true | 75.91 | 75.98 | 0.638 | 16.31 | 0.684 |
| fold-011 | enable_stage3_force_exit=false__enable_stage2_ma_hold=true | -18.66 | -18.67 | -1.349 | 22.61 | -0.895 |
| fold-012 | enable_stage3_force_exit=false__enable_stage2_ma_hold=true | 1.79 | 1.79 | 1.125 | 15.70 | 1.290 |
| fold-013 | enable_stage3_force_exit=false__enable_stage2_ma_hold=true | 10.51 | 10.52 | 0.055 | 11.99 | -0.015 |
| fold-014 | enable_stage3_force_exit=false__enable_stage2_ma_hold=true | -27.62 | -27.64 | -1.888 | 31.22 | -0.920 |

## 2. Stability (mean ± stdev across folds)

| Variant | Return % (μ ± σ) | CAGR % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|---------------:|----------------:|--------------:|
| baseline | 12.95 ± 22.62 | 12.96 ± 22.64 | 0.643 ± 1.036 | 14.79 ± 7.63 | 1.382 ± 1.983 |
| enable_stage3_force_exit=true__enable_stage2_ma_hold=false | 12.95 ± 22.62 | 12.96 ± 22.64 | 0.643 ± 1.036 | 14.79 ± 7.63 | 1.382 ± 1.983 |
| enable_stage3_force_exit=true__enable_stage2_ma_hold=true | 10.51 ± 25.86 | 10.52 ± 25.88 | 0.486 ± 1.193 | 14.85 ± 7.32 | 1.354 ± 2.611 |
| enable_stage3_force_exit=false__enable_stage2_ma_hold=false | 13.07 ± 23.81 | 13.08 ± 23.83 | 0.679 ± 1.156 | 14.74 ± 7.62 | 1.631 ± 2.785 |
| enable_stage3_force_exit=false__enable_stage2_ma_hold=true | 9.21 ± 26.18 | 9.22 ± 26.20 | 0.457 ± 1.227 | 14.79 ± 7.50 | 1.299 ± 2.336 |

## 3. Cross-fold sensitivity

Variant wins per fold on each metric (vs baseline `baseline`, 15 folds total; gate metric marked **\***):

| Variant | Sharpe wins* | Calmar wins | Return wins | MaxDD wins | of |
|---------|----------:|----------:|----------:|----------:|---:|
| enable_stage3_force_exit=true__enable_stage2_ma_hold=false | 0 | 0 | 0 | 0 | 15 |
| enable_stage3_force_exit=true__enable_stage2_ma_hold=true | 8 | 8 | 7 | 7 | 15 |
| enable_stage3_force_exit=false__enable_stage2_ma_hold=false | 1 | 2 | 1 | 3 | 15 |
| enable_stage3_force_exit=false__enable_stage2_ma_hold=true | 7 | 8 | 6 | 7 | 15 |

## 4. Go/no-go verdict

Gate: variant wins ≥8 of 15 folds on **Sharpe** vs baseline `baseline`, no fold worse by Δ>0.2000.

- **enable_stage3_force_exit=true__enable_stage2_ma_hold=false**: FAIL (0 / 15 wins; worst fold `fold-000` gap 0.0000). Reason: M-threshold miss: 0 wins < 8 required
- **enable_stage3_force_exit=true__enable_stage2_ma_hold=true**: FAIL (8 / 15 wins; worst fold `fold-014` gap 2.3123). Reason: Δ-threshold miss: fold fold-014 trails by 2.3123 > Δ=0.2000
- **enable_stage3_force_exit=false__enable_stage2_ma_hold=false**: FAIL (1 / 15 wins; worst fold `fold-009` gap 0.1276). Reason: M-threshold miss: 1 wins < 8 required
- **enable_stage3_force_exit=false__enable_stage2_ma_hold=true**: FAIL (7 / 15 wins; worst fold `fold-014` gap 2.5856). Reason: M-threshold miss: 7 wins < 8 required; worst fold fold-014 trails by 2.5856 > Δ=0.2000