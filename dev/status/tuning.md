# Status: tuning

## Last updated: 2026-05-06

## Status
IN_PROGRESS — T-A lib + CLI + tests READY_FOR_REVIEW; T-B CLI + walk-forward integration deferred

T-A grid_search lib + tests landed via PR #805 (merged 2026-05-03). T-B Bayesian-opt lib + tests landed via PR #817 (merged 2026-05-04). Both `.mli` surfaces are stable. Track created 2026-05-02 to absorb M5.5 (parameter tuning) + M7.1 (ML training). Plans: `dev/plans/m5-experiments-roadmap-2026-05-02.md` (T-A grid + T-B Bayesian) + `dev/plans/m7-data-and-tuning-2026-05-02.md` (T-C supervised) + `dev/plans/grid-search-2026-05-03.md` (T-A clarifying) + `dev/plans/bayesian-opt-2026-05-03.md` (T-B clarifying with D1–D8 design decisions). Authority: `docs/design/weinstein-trading-system-v2.md` §7 sub-milestones M5.5 + M7.1 (added 2026-05-02).

Remaining work:
- **T-A CLI binary** — `tuner_runner.exe` wiring `Grid_search.run` to the real backtest runner. Larger PR; deferred.
- **T-B CLI binary** — `bayesian_runner.exe` analogous to T-A. Deferred.
- **T-C** (supervised ML walk-forward) — blocked on Norgate ingest (vendor signup) + experiments M5.2 metrics catalog + experiments M5.2e per-trade context (already shipped #769). Owner authorized: feat-backtest per `dev/decisions.md` 2026-05-03 §"Agent scope: extend feat-backtest + create feat-data".

## Interface stable
YES

For T-A and T-B. `Tuner.Grid_search` `.mli` is the canonical surface for grid-style tuning over the backtest runner. `Tuner.Bayesian_opt` `.mli` is the canonical surface for GP-driven tuning — opaque `t`, `create`/`observe`/`suggest_next`/`best`/`all_observations` form a small functional state-machine API. T-C (ML) will live alongside without disturbing either.

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
- T-A CLI binary on branch `feat/backtest-tuning-grid-search-cli` (READY_FOR_REVIEW). T-B CLI binary still pending.

## Completed

- [x] **#888 cascade score-floor knob exposed for grid sweep** (~250 LOC; branch `feat/screener/888-threshold-param`). Added `min_score_override : int option` to `Screener.config` (default `None` preserves grade-based filter bit-equally; `Some n` replaces with strict `score >= n` numeric gate). Threaded via `_passes_score_floor` helper through `_score_and_build`, `_long_admission`/`_short_admission`, and the diagnostics-counting path (single source of truth). Registered in `Tuner.Grid_search.param_spec` docstring as a sweepable dimension at `screening_config.min_score_override`. Override deep-merge pinned by `test_override_screening_min_score_override` in `test_runner_hypothesis_overrides.ml`. 5 new unit tests in `test_screener.ml` pin the gate's `>=` semantics + bit-equal-default contract. 3-cell quick-look on sp500-2019-2023 (cells: default / 41 / 42) documented in `dev/notes/888-score-threshold-quick-look-2026-05-06.md` — finding consistent with #871's "cascade is at no-look-ahead ceiling" verdict; full sweep deferred until #872 / #887 capital-recycling lands. Verify: `dev/lib/run-in-env.sh dune runtest analysis/weinstein/screener/test/` + `dev/lib/run-in-env.sh dune exec trading/backtest/test/test_runner_hypothesis_overrides.exe`.

- [x] **T-A grid_search CLI binary + tests** (PR pending; branch `feat/backtest-tuning-grid-search-cli`). Surface: `trading/trading/backtest/tuner/bin/{grid_search.ml,grid_search_spec.{ml,mli},grid_search_evaluator.{ml,mli},grid_search_runner.{ml,mli},dune}` + `trading/trading/backtest/tuner/bin/test/{test_grid_search_bin.ml,dune}`. Wires `Tuner.Grid_search.run` to a `Backtest.Runner.run_backtest`-backed evaluator. Reads a spec sexp file with shape `((params (...)) (objective <variant>) (scenarios (<path>...)))` — see `Tuner_bin.Grid_search_spec.t.mli` for the on-disk shape. Output writers emit `grid.csv`, `best.sexp`, and `sensitivity.md` under `--out-dir`. CLI flags: `--spec <path> --out-dir <dir> [--fixtures-root <path>]`. Six unit tests pin spec parsing (simple + Composite + malformed-raises), `to_grid_objective` round-trip across all simple variants, and the `run_and_write` plumbing against a stub evaluator (verifies argmax + three-artefact emission + mkdir-p semantics). Verify: `dune runtest trading/backtest/tuner/bin/test/` (6/6 pass) + `dune exec backtest/tuner/bin/grid_search.exe -- --help`. Smoke-scenario sanity-check intentionally deferred — the lib's lightest perf-tier smoke is 5-10 min wall (full universe); a single-cell sanity run on it can be done locally before the 81-cell flagship sweep lands.
- [x] **T-B Bayesian-opt lib + tests** (~922 LOC including tests, ~439 lib; branch `feat/tuner-bayesian-opt`). Surface: `trading/trading/backtest/tuner/lib/bayesian_opt.{ml,mli}`. Pure functional GP-based optimiser using `owl` (`Owl.Linalg.D.chol` + `triangular_solve` for the Cholesky-factor linear system, `Owl.Mat` for matrix ops). Two-phase suggestion (initial random samples → GP-driven argmax of acquisition function over uniformly-sampled candidates). RBF kernel with default length scales `0.25` in normalised `[0,1]` parameter space; signal variance `1.0`; noise jitter `1e-6`. Two acquisition functions: `Expected_improvement` (default) and `Upper_confidence_bound β`. Determinism: same `Random.State.t` seed → byte-identical suggestion sequences. Convergence pinned by 1D parabola (`f(x) = -(x-3)²`) within 30 evals + 2D Branin within 50 evals. 27 tests including bounds enforcement, RBF/EI/UCB unit tests, GP-fit interpolation verification at observed points. Verify: `docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && dune runtest trading/backtest/tuner/'` (27/27 pass). Design decisions in `dev/plans/bayesian-opt-2026-05-03.md` §D1–D8. Follow-up: CLI binary (deferred from T-B to keep PR ≤500 LOC; mirrors T-A's split). Hyperparameter learning (Type-II MLE on length scales) deferred — fixed-hyperparameter GP is sufficient for the dimensions and budgets the M5.5 spec calls out.

- [x] **T-A grid_search lib + tests** (~440 LOC; PR #805 MERGED 2026-05-03). Surface: `trading/trading/backtest/tuner/lib/grid_search.{ml,mli}`. Cartesian product over a `(string * float list) list` param spec, configurable objective (`Sharpe | Calmar | TotalReturn | Concavity_coef | Composite of (metric_type * float) list`), pure evaluator callback so tests don't need to spin up a real backtest. Output writers for `grid.csv`, `best.sexp`, `sensitivity.md`. Verify: `dev/lib/run-in-env.sh dune runtest trading/backtest/tuner/` (24/24 pass). The 81-cell wall-time gate (<2hr on smoke scenarios) is deferred to a follow-up local verification — CI doesn't run smoke at scale.

## Next Steps

1. ~~Wire CLI binary at `trading/trading/backtest/tuner/bin/grid_search.ml`~~ — done; see Completed.
2. Wire CLI binary at `trading/trading/backtest/tuner/bin/bayesian_sweep.ml` (deferred from T-B). Hooks `Tuner.Bayesian_opt.suggest_next`/`observe` into a `Backtest.Runner.run_backtest`-backed loop + reads bounds from sexp.
3. Run the 81-cell flagship sweep on `screening.weights.{rs,volume,breakout,sector}` once the grid CLI binary lands; verify <2hr wall-time gate on smoke scenarios.
4. After grid sweep results land, validate T-B converges to the same (or better) cell within ~30 evals using the same param surface — the convergence acceptance criterion in `m5-experiments-roadmap-2026-05-02.md` §M5.5 T-B.
5. T-C only after `data-foundations` Norgate ingest (need long enough train/test split).
6. Hyperparameter learning for T-B (Type-II MLE on length scales) — defer until 4-dim / 6-dim sweeps show that fixed length scales miss the optimum.

## Out of scope

- RL / PPO / A3C — different paradigm; defer indefinitely.
- Continuous online learning — strategy is weekly cadence, batch retraining suffices.
- Hyperparameter optimization for the ML models themselves (meta-tuning) — defer.
