# Status: tuning

## Last updated: 2026-05-03

## Status
READY_FOR_REVIEW

T-A grid_search lib + tests landed (this PR). Track created 2026-05-02 to absorb M5.5 (parameter tuning) + M7.1 (ML training). Plans: `dev/plans/m5-experiments-roadmap-2026-05-02.md` (T-A grid + T-B Bayesian) + `dev/plans/m7-data-and-tuning-2026-05-02.md` (T-C supervised). Authority: `docs/design/weinstein-trading-system-v2.md` §7 sub-milestones M5.5 + M7.1 (added 2026-05-02).

## Interface stable
YES

For T-A. `Tuner.Grid_search` `.mli` is the canonical surface for grid-style tuning over the backtest runner. T-B (Bayesian) and T-C (ML) will live alongside without disturbing this one.

## Blocked on
- `experiments` track M5.2 metrics catalog (need 35-metric scoring infra before tuning has objectives)
- `experiments` track M5.2e per-trade context (needed as ML features for T-C)
- `data-foundations` track M7.0 Norgate ingest (needed for survivorship-bias-aware train/test split)
- `optimal-strategy` track (already MERGED 2026-04-29) — provides per-Friday counterfactual oracle for T-C labels

## Scope

### T-A — Grid search (~400 LOC)

`trading/trading/backtest/tuner/lib/grid_search.{ml,mli}` (new). Param spec, objective, scenarios → `dev/tuning/<name>/{grid.csv, best.sexp, sensitivity.md}`. 4-dim 81-cell sweep on smoke scenarios <2hr.

### T-B — Bayesian optimization (~600 LOC)

`trading/trading/backtest/tuner/lib/bayes_opt.{ml,mli}` (new). Pure OCaml Gaussian process + Expected Improvement acquisition. Converges to T-A best within ~30 backtests on same param space.

### T-C — Supervised ML (M7.1)

Three model tiers:
- **Linear regression** (~200 LOC, OCaml-native) — interpretable baseline
- **Decision tree** (~400 LOC, OCaml-native) — non-linear interactions
- **xgboost / lightgbm via FFI** (~300 LOC bindings) — production-grade

Walk-forward validation: train 1990–2017, validation 2018–2022, test 2023–2025. No peeking.

Labels: `optimal-strategy` per-Friday oracle (binary in-pick-set + continuous forward 4-week return).

Features: from M5.2e per-trade context (Stage one-hot, MA slope, vol ratio, RS, distance from breakout, sector strength, macro regime, days since stage transition).

### No Python

Per `.claude/rules/no-python.md`. OCaml-native or FFI to C libs only.

## In Progress
- None — T-A lib + tests in `feat/backtest-tuning-grid-search` ready for review.

## Completed

- [x] **T-A grid_search lib + tests** (~440 LOC; PR `feat/backtest-tuning-grid-search`). Surface: `trading/trading/backtest/tuner/lib/grid_search.{ml,mli}`. Cartesian product over a `(string * float list) list` param spec, configurable objective (`Sharpe | Calmar | TotalReturn | Concavity_coef | Composite of (metric_type * float) list`), pure evaluator callback so tests don't need to spin up a real backtest. Output writers for `grid.csv`, `best.sexp`, `sensitivity.md`. Verify: `dev/lib/run-in-env.sh dune runtest trading/backtest/tuner/` (24/24 pass). The 81-cell wall-time gate (<2hr on smoke scenarios) is deferred to a follow-up local verification — CI doesn't run smoke at scale.

## Next Steps

1. Wire CLI binary at `trading/trading/backtest/tuner/bin/grid_search.ml` (deferred from T-A to keep PR ≤500 LOC). Hooks `Tuner.Grid_search.run` to a `Backtest.Runner.run_backtest`-backed evaluator + reads param spec from sexp.
2. Run the 81-cell flagship sweep on `screening.weights.{rs,volume,breakout,sector}` once the binary lands; verify <2hr wall-time gate on smoke scenarios.
3. T-B Bayesian after T-A surface settles and the 81-cell sweep shape exposes the objective surface.
4. T-C only after `data-foundations` Norgate ingest (need long enough train/test split).

## Out of scope

- RL / PPO / A3C — different paradigm; defer indefinitely.
- Continuous online learning — strategy is weekly cadence, batch retraining suffices.
- Hyperparameter optimization for the ML models themselves (meta-tuning) — defer.
