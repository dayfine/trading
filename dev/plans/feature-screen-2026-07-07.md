# Plan — `feature_screen` multivariate screen over all-eligible trades CSV

**Date:** 2026-07-07
**Track:** experiments (P0b analysis half, `dev/notes/next-session-priorities-2026-07-07.md`)
**Branch:** `feat/feature-screen`

## Goal

Definitively close (or escalate) entry-selection by jointly regressing the
counterfactual trade outcome (`return_pct`) on the FULL decision-time feature
vector over the 26y broad all-eligible population. Prior work rejected features
one-at-a-time (cascade-inversion, score anti-predictive); this tests them
*jointly* to rule out a multivariate signal that univariate screens miss.

This is a **read-only screen**, not a strategy change. The verdict it feeds is a
no-build decision vs escalate-to-WF-CV — per `.claude/rules/mechanism-validation-rigor.md`
it may NOT claim deployable alpha.

## Input

`trades.csv` written by `All_eligible_runner.write_trades_csv` — 19 columns
(header verified against `_csv_header` in `all_eligible_runner.ml`). Feature cells
may be empty (None). Response = `return_pct`; win = `return_pct > 0`.

Categorical string encodings (verified against `Weinstein_types` sexp):
- `rs_trend` ∈ {Bullish_crossover, Positive_rising, Positive_flat,
  Negative_improving, Negative_declining, Bearish_crossover}
- `resistance_quality` ∈ {Virgin_territory, Clean, Moderate_resistance,
  Heavy_resistance}

## Module layout (`trading/trading/backtest/feature_screen/`)

- `lib/csv_rows.ml(i)` — `row` record + `parse_rows` (header-validated, empty→None).
- `lib/feature_matrix.ml(i)` — `feature` enum, selection, one-hot (drop-first
  reference), complete-case filter, per-feature None-coverage counts, era split,
  standardized design-matrix builder.
- `lib/regression.ml(i)` — dense linalg (solve/inverse via Gaussian elimination),
  OLS with HC1 robust SE + R², logistic (Newton/IRLS) with z-stats + rank AUC.
- `lib/report.ml(i)` — markdown renderer (coverage, OLS, logistic, era-split
  sign-stability, rigor caveats footer).
- `lib/feature_screen.ml(i)` — facade: `screen` orchestrates full + era fits.
- `bin/feature_screen_bin.ml` — CLI (`--trades-csv` repeatable, `--out`, `--features`).

## Tests (`test/`, OUnit2 + Matchers)

- parse: header validation, empty→None, malformed row → error.
- OLS recovers known coefficients on noise-free synthetic (y = 2·x1 − 1·x2).
- logistic recovers sign + AUC≈1 on linearly-separated synthetic.
- one-hot: category→column mapping pinned (drop-first reference).
- era split: rows partitioned correctly by signal_date.

## Statistical honesty

In-sample only, complete-case bias reported, survivorship noted. No stepwise
selection / p-hacking helpers. Verdict calibrated to a proxy screen.

## Standardization convention

Continuous numerics (cascade_score, rs_value, volume_ratio, weeks_advancing)
z-scored → coefficients read as return_pct per 1 SD. Booleans + one-hot dummies
left as 0/1 indicators. Response `return_pct` left in raw units.
