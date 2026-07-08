feature_screen: 111895 rows, 78727 complete-case; report (stdout)
# Feature screen — all-eligible trades

Rows parsed: 111895; complete-case rows (full fit): 78727.

## Feature coverage (pre complete-case)

| Feature | Present | Total | % |
|---|---|---|---|
| cascade_score | 111895 | 111895 | 100.0% |
| rs_value | 78831 | 111895 | 70.5% |
| volume_ratio | 111895 | 111895 | 100.0% |
| rs_trend | 78831 | 111895 | 70.5% |
| resistance_quality | 111782 | 111895 | 99.9% |

## OLS — return_pct on features (HC1-robust SE)

n = 78727, p = 11, R² = 0.004547

| term | coef | se | t |
|---|---|---|---|
| intercept | +6.250907 | 2.863848 | +2.183 |
| cascade_score | -1.860958 | 3.178503 | -0.585 |
| rs_value | +22.498070 | 12.148994 | +1.852 |
| volume_ratio | -0.694433 | 0.566661 | -1.225 |
| rs_trend=Positive_rising | -11.870070 | 5.542458 | -2.142 |
| rs_trend=Positive_flat | -9.403553 | 3.862485 | -2.435 |
| rs_trend=Negative_improving | +0.720789 | 2.208177 | +0.326 |
| rs_trend=Bearish_crossover | -0.800054 | 1.985400 | -0.403 |
| resistance_quality=Clean | +3.269826 | 4.540809 | +0.720 |
| resistance_quality=Moderate_resistance | -2.062427 | 2.299263 | -0.897 |
| resistance_quality=Heavy_resistance | -2.121769 | 3.366320 | -0.630 |

## Logistic — P(win) on features

n = 78727, p = 11, in-sample AUC = 0.7625, converged = true

| term | coef | se | z |
|---|---|---|---|
| intercept | -3.384755 | 0.074738 | -45.289 |
| cascade_score | +0.058798 | 0.039528 | +1.488 |
| rs_value | +0.342322 | 0.020058 | +17.067 |
| volume_ratio | -0.030742 | 0.024060 | -1.278 |
| rs_trend=Positive_rising | +0.496127 | 0.043866 | +11.310 |
| rs_trend=Positive_flat | -0.283088 | 0.072941 | -3.881 |
| rs_trend=Negative_improving | -1.408749 | 0.101083 | -13.936 |
| rs_trend=Bearish_crossover | -1.490514 | 0.160174 | -9.306 |
| resistance_quality=Clean | +1.332380 | 0.046919 | +28.398 |
| resistance_quality=Moderate_resistance | +1.166145 | 0.051634 | +22.585 |
| resistance_quality=Heavy_resistance | +1.327603 | 0.065602 | +20.237 |

## Era-split coefficient sign stability (OLS)

Eras: 2000-2008, 2009-2017, 2018-2026 (`.` = era not fit; sign order matches header)

| term | full | 2000-2008 | 2009-2017 | 2018-2026 | stable |
|---|---|---|---|---|---|
| intercept | + | + + + | yes |
| cascade_score | - | - - - | yes |
| rs_value | + | + + + | yes |
| volume_ratio | - | - - - | yes |
| rs_trend=Positive_rising | - | - - - | yes |
| rs_trend=Positive_flat | - | - - - | yes |
| rs_trend=Negative_improving | + | - + + | NO |
| rs_trend=Bearish_crossover | - | - - - | yes |
| resistance_quality=Clean | + | + + - | NO |
| resistance_quality=Moderate_resistance | - | - - - | yes |
| resistance_quality=Heavy_resistance | - | - - - | yes |

## Screen-rigor caveats

- IN-SAMPLE fit only — no out-of-sample / walk-forward validation. R² and AUC are optimistic by construction.
- COMPLETE-CASE bias: rows missing any selected feature are dropped; the coverage table above quantifies the loss. Stage-2-only features (weeks_advancing, stage2_late) and RS features are the None-heavy ones.
- SURVIVORSHIP / population: the all-eligible CSV reflects the universe snapshot it was generated from; delisted-name coverage is bounded by the source snapshot.
- This is a READ-ONLY SCREEN. It can support a no-build DECISION or an escalate-to-WF-CV decision; it CANNOT claim causal or deployable alpha. A mechanism is only rejected by the real test (default-off flag + walk-forward CV + confirmation grid).
