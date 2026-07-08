feature_screen: 162632 rows, 118729 complete-case; report (stdout)
# Feature screen — all-eligible trades

Rows parsed: 162632; complete-case rows (full fit): 118729.

## Feature coverage (pre complete-case)

| Feature | Present | Total | % |
|---|---|---|---|
| cascade_score | 162632 | 162632 | 100.0% |
| rs_value | 118884 | 162632 | 73.1% |
| volume_ratio | 162632 | 162632 | 100.0% |
| rs_trend | 118884 | 162632 | 73.1% |
| resistance_quality | 162458 | 162632 | 99.9% |

## OLS — return_pct on features (HC1-robust SE)

n = 118729, p = 11, R² = 0.003429

| term | coef | se | t |
|---|---|---|---|
| intercept | +5.904881 | 2.804827 | +2.105 |
| cascade_score | -1.620417 | 2.204919 | -0.735 |
| rs_value | +16.203321 | 9.398747 | +1.724 |
| volume_ratio | -0.449937 | 0.364928 | -1.233 |
| rs_trend=Positive_rising | -10.088810 | 4.917793 | -2.051 |
| rs_trend=Positive_flat | -8.087298 | 3.597106 | -2.248 |
| rs_trend=Negative_improving | +0.886444 | 1.824127 | +0.486 |
| rs_trend=Bearish_crossover | -0.516746 | 1.354161 | -0.382 |
| resistance_quality=Clean | +2.200804 | 3.004608 | +0.732 |
| resistance_quality=Moderate_resistance | -1.905618 | 1.775300 | -1.073 |
| resistance_quality=Heavy_resistance | -1.791542 | 2.400924 | -0.746 |

## Logistic — P(win) on features

n = 118729, p = 11, in-sample AUC = 0.7449, converged = true

| term | coef | se | z |
|---|---|---|---|
| intercept | -3.688594 | 0.064337 | -57.333 |
| cascade_score | +0.084219 | 0.032899 | +2.560 |
| rs_value | +0.394395 | 0.016268 | +24.244 |
| volume_ratio | -0.029686 | 0.019730 | -1.505 |
| rs_trend=Positive_rising | +0.422234 | 0.039322 | +10.738 |
| rs_trend=Positive_flat | -0.177841 | 0.063862 | -2.785 |
| rs_trend=Negative_improving | -1.194855 | 0.091481 | -13.061 |
| rs_trend=Bearish_crossover | -1.273967 | 0.151582 | -8.404 |
| resistance_quality=Clean | +1.338246 | 0.041105 | +32.556 |
| resistance_quality=Moderate_resistance | +1.144654 | 0.044905 | +25.491 |
| resistance_quality=Heavy_resistance | +1.417170 | 0.057888 | +24.481 |

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
| rs_trend=Bearish_crossover | - | - - + | NO |
| resistance_quality=Clean | + | + + - | NO |
| resistance_quality=Moderate_resistance | - | - - - | yes |
| resistance_quality=Heavy_resistance | - | - - - | yes |

## Screen-rigor caveats

- IN-SAMPLE fit only — no out-of-sample / walk-forward validation. R² and AUC are optimistic by construction.
- COMPLETE-CASE bias: rows missing any selected feature are dropped; the coverage table above quantifies the loss. Stage-2-only features (weeks_advancing, stage2_late) and RS features are the None-heavy ones.
- SURVIVORSHIP / population: the all-eligible CSV reflects the universe snapshot it was generated from; delisted-name coverage is bounded by the source snapshot.
- This is a READ-ONLY SCREEN. It can support a no-build DECISION or an escalate-to-WF-CV decision; it CANNOT claim causal or deployable alpha. A mechanism is only rejected by the real test (default-off flag + walk-forward CV + confirmation grid).
