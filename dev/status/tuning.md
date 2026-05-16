# Status: tuning

## Last updated: 2026-05-16

## Status
IN_PROGRESS

**2026-05-15 strategic pivot — track elevated to P0 alongside
data-foundations.** Per `dev/notes/next-session-priorities-2026-05-15.md`,
multi-parameter ML-discipline tuning over the full Cell E config
surface (~15-25 parameters) on walk-forward CV is now the primary
tuning vector. Two cross-window inversions in one week (PR #1086 M5.5
axis-2 + PR #1095 continuation combined) confirmed that single-axis
and small-grid sweeps under fixed windows are diagnostic-only at this
point; further manual tuning is rejected.

New Phase 2 work — **walk-forward CV harness scaled up**:
- Extend `dev/experiments/cell-e-walk-forward-2026-05-08/` (8 half-period
  folds) to ~30 rolling folds.
- Output `walk_forward_report.md` surfacing per-fold metrics + cross-
  fold stability + parameter sensitivity + explicit go/no-go gate
  ("wins on ≥M of N folds with no fold worse than baseline by Δ").
- This gate language is what M5.5 axis-2 and continuation-combined
  would have failed.

New Phase 3 work — **multi-parameter Bayesian opt scaled up**:
- Extend `bayesian_runner.exe` (PR #914) from current 4-D bounds to
  the full Cell E config surface.
- Scored on Phase 2 walk-forward CV with explicit MaxDD penalty.
- Acceptance: converges to a cell beating Cell E on walk-forward
  Sharpe by ≥0.05 with MaxDD no worse.

Phase 2 is independent of `data-foundations` Phase 1 (can run on
existing 510-sym 2010-2026 universe) and should land in parallel.
Phase 3 benefits from Phase 1 broader universe but is not strictly
blocked on it.

Owner: feat-backtest.

**Prior status preamble retained below.**

(T-A lib + CLI MERGED; T-B lib + CLI MERGED; 81-cell flagship grid RUN but key-path bug invalidated result; weights surface CONFIRMED load-bearing via correct field paths)

T-A grid_search lib + tests landed via PR #805 (merged 2026-05-03). T-A CLI binary landed via PR #893 (merged 2026-05-06). T-B Bayesian-opt lib + tests landed via PR #817 (merged 2026-05-04). T-B CLI binary `bayesian_runner.exe` MERGED via PR #914 (2026-05-07). Cell-level `--parallel N` on `grid_search.exe` MERGED via PR #1047 (2026-05-12). All `.mli` surfaces are stable. Track created 2026-05-02 to absorb M5.5 (parameter tuning) + M7.1 (ML training). Plans: `dev/plans/m5-experiments-roadmap-2026-05-02.md` (T-A grid + T-B Bayesian) + `dev/plans/m7-data-and-tuning-2026-05-02.md` (T-C supervised) + `dev/plans/grid-search-2026-05-03.md` (T-A clarifying) + `dev/plans/bayesian-opt-2026-05-03.md` (T-B clarifying with D1–D8 design decisions). Authority: `docs/design/weinstein-trading-system-v2.md` §7 sub-milestones M5.5 + M7.1 (added 2026-05-02).

Remaining work:
- **81-cell flagship sweep rerun** — first run published via PR #1051 (2026-05-12) showed bit-identical metrics across all 81 cells, leading to a (premature) "weights are inert" verdict. PR #1061 (2026-05-13) reopened that verdict: root cause was a **key-path bug** in the sweep overlays — they swept `weights.rs/volume/breakout/sector`, but the real `Screener.scoring_weights` fields are `w_positive_rs/w_strong_volume/w_stage2_breakout/w_sector_strong`. The runner's `_apply_overrides` deep-merge silently dropped the unrecognized keys, so every cell ran identical config. Weights ARE load-bearing (M5.4-E4 sweep with correct paths moved metrics 22 pp return / 0.12 Sharpe). Recommendation: rerun the 81-cell grid with corrected field paths, paired with `min_score_override` / `max_score_override` tightening. PR #1068 (2026-05-13) added `.mli` clarifications of the real knob names.
- **Sweep-path validation linter** — add a check in `runner.ml:_merge_records` to fail loudly on unrecognized keys, closing the silent-no-op hazard that produced PR #1051's misleading result.
- **T-B convergence cross-check** — once the corrected 81-cell flagship sweep result lands, validate `bayesian_runner.exe` converges to the same (or better) cell within ~30 evals over the same 4-D bounds (acceptance criterion in `m5-experiments-roadmap-2026-05-02.md` §M5.5 T-B).
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
- **Bayesian Phase 3 PR-A** (scoring function, PR #1126, branch `feat/bayesian-phase3-pr-a`) — structural_qc: APPROVED; behavioral_qc: APPROVED (2026-05-16, quality 5). CP1–CP4 all PASS; domain rows NA (pure tuner-side scoring policy). See `dev/reviews/tuning.md` §"Behavioral Checklist — Bayesian Phase 3 PR-A".
- T-A lib + CLI, T-B lib + CLI, and `min_score_override` / `max_score_override` knobs all MERGED. First 81-cell flagship sweep run published (PR #1051) but invalidated by key-path bug (PR #1061). Next queued: 81-cell rerun with corrected `w_positive_rs/w_strong_volume/w_stage2_breakout/w_sector_strong` field paths + sweep-path validation linter to prevent silent-no-op repeats.

### Bayesian Phase 3 — multi-parameter scaling (5-PR stack, plan PR #1124 MERGED)

Plan authority: `dev/plans/bayesian-multi-param-scaling-2026-05-16.md`.
Plan splits into 5 stacked PRs (~200-400 LOC each):

- **PR-A: scoring function + walk-forward aggregate consumer** —
  IN REVIEW (branch `feat/bayesian-phase3-pr-a`). Adds
  `Tuner_bin.Bayesian_runner_scoring` (pure scorer over a
  `Walk_forward_types.aggregate` + Cell E baseline aggregate) with
  loss = `-mean_sharpe + lambda_dd*max(0, maxdd_excess) + lambda_gate*gate_penalty`;
  hyperparameters as named constants (`_lambda_dd=0.10`,
  `_gate_penalty_value=10.0`, `_lambda_gate=1.0`,
  `_degenerate_fold_floor_return_pct=-50.0`). Returns
  `float Status.status_or` so missing-variant lookups surface as
  structured errors. 15 unit tests cover identity case, MaxDD hinge
  zero/linear, gate Pass/Fail diff = -10.0 exactly, synthetic Fail ≡
  regular Fail, lookup errors (3 paths), zero-fold guard, boundary
  cases, parameters-not-affecting-score contract, and constant
  pinning. No wiring into the BO evaluator/runner yet — that's PR-C.
- **PR-B: knob inventory + parameter space encoding** — pending.
- **PR-C: walk-forward in-process integration** — pending.
- **PR-D: int/Option encoding + GP length-scale tuning + early-stop** — pending.
- **PR-E: end-to-end runner + OOS holdout validator** — pending.

Operational follow-ups (unblock when capacity allows):

- **81-cell flagship rerun with corrected field paths** — sweep
  `screening.weights.{w_positive_rs, w_strong_volume, w_stage2_breakout, w_sector_strong}`
  paired with `min_score_override` / `max_score_override` tightening.
- **Sweep-path validation linter** in `runner.ml:_merge_records` —
  fail on unrecognized keys to prevent silent-no-op overlays.

## Completed

- [x] **PR #1047 — `grid_search.exe --parallel N` (cell-level parallelism)** (MERGED 2026-05-12). Reduces wall-time for large grids by running N cells concurrently. Used for the 81-cell flagship sweep.

- [x] **PR #914 — T-B Bayesian-opt CLI binary + tests** (MERGED 2026-05-07; ~775 LOC including tests; branch `feat/backtest-tuning-bayesian-opt-cli`). Closes the deferred T-B CLI follow-up from PR #817. Three new modules under `trading/trading/backtest/tuner/bin/`: `Bayesian_runner_spec` (sexp-driven param-bounds + acquisition + objective + budget parser, with `to_grid_objective` / `to_acquisition` / `to_bo_config` projections), `Bayesian_runner_evaluator` (adapts `Backtest.Runner.run_backtest` to the BO loop's per-suggestion callback, scalarises with `Tuner.Grid_search.evaluate_objective`, walks scenarios in spec order), `Bayesian_runner_runner` (drives the `Tuner.Bayesian_opt.suggest_next`/`observe` ask/tell loop for `total_budget` iters, emits `bo_log.csv` + `best.sexp` + `convergence.md` per the M5.5 T-B spec). CLI binary `bayesian_runner.exe` with flags `--spec <path> --out-dir <dir> [--fixtures-root <path>]`. 11 unit tests pin every non-trivial `.mli` claim: spec parsing (simple Expected_improvement spec + UCB acquisition with Composite objective + malformed-raises), `to_grid_objective`/`to_acquisition` round-trips, `to_bo_config` field propagation, `run_and_write` plumbing against a 1D-parabola stub evaluator (three-artefact emission + mkdir-p + convergence within tol 0.5 + byte-identical bo_log under fixed seed), evaluator unknown-scenario `Failure` guard. Smoke-scenario integration deferred (mirrors PR #893's deferral; full-universe single eval ~5–10 min, run locally before the convergence cross-check). Lib at `trading/trading/backtest/tuner/lib/` is unchanged. Verify: `dev/lib/run-in-env.sh dune runtest trading/backtest/tuner/ --force` (72/72 pass) + `dev/lib/run-in-env.sh dune exec trading/backtest/tuner/bin/bayesian_runner.exe -- --help`. Hyperparameter learning (Type-II MLE on length scales) remains deferred per `dev/plans/bayesian-opt-2026-05-03.md` §"Out of scope".

- [x] **#892 cascade score-floor knob exposed for grid sweep** (MERGED 2026-05-06; ~250 LOC; branch `feat/screener/888-threshold-param`). Added `min_score_override : int option` to `Screener.config` (default `None` preserves grade-based filter bit-equally; `Some n` replaces with strict `score >= n` numeric gate). Threaded via `_passes_score_floor` helper through `_score_and_build`, `_long_admission`/`_short_admission`, and the diagnostics-counting path (single source of truth). Registered in `Tuner.Grid_search.param_spec` docstring as a sweepable dimension at `screening_config.min_score_override`. Override deep-merge pinned by `test_override_screening_min_score_override` in `test_runner_hypothesis_overrides.ml`. 5 new unit tests in `test_screener.ml` pin the gate's `>=` semantics + bit-equal-default contract. 3-cell quick-look on sp500-2019-2023 (cells: default / 41 / 42) documented in `dev/notes/888-score-threshold-quick-look-2026-05-06.md` — finding consistent with #871's "cascade is at no-look-ahead ceiling" verdict; full sweep deferred until #872 / #887 capital-recycling lands. Verify: `dev/lib/run-in-env.sh dune runtest analysis/weinstein/screener/test/` + `dev/lib/run-in-env.sh dune exec trading/backtest/test/test_runner_hypothesis_overrides.exe`.

- [x] **#893 T-A grid_search CLI binary + tests** (MERGED 2026-05-06; branch `feat/backtest-tuning-grid-search-cli`). Completes the T-A CLI deferred follow-up from PR #805. Three new modules: `Grid_search_spec` (sexp-driven param spec + objective parser), `Grid_search_evaluator` (adapts `Backtest.Runner.run_backtest` to the pure evaluator callback), `Grid_search_runner` (orchestrates multi-cell runs + emits artefacts). CLI binary `grid_search.exe` with flags `--spec <path> --out-dir <dir> [--fixtures-root <path>]`. 7 unit tests: spec parsing (simple + Composite + malformed-raises), `to_grid_objective` round-trip, `run_and_write` plumbing against stub evaluator (argmax + three-artefact emission + mkdir-p semantics), cache-miss-Failure guard pinned per CP4. Smoke-scenario integration deferred (full-universe single cell ~5-10 min; to be run locally before the 81-cell flagship sweep). Verify: `dune runtest trading/backtest/tuner/bin/test/` (7/7 pass) + `dune exec backtest/tuner/bin/grid_search.exe -- --help`.
- [x] **T-B Bayesian-opt lib + tests** (~922 LOC including tests, ~439 lib; branch `feat/tuner-bayesian-opt`). Surface: `trading/trading/backtest/tuner/lib/bayesian_opt.{ml,mli}`. Pure functional GP-based optimiser using `owl` (`Owl.Linalg.D.chol` + `triangular_solve` for the Cholesky-factor linear system, `Owl.Mat` for matrix ops). Two-phase suggestion (initial random samples → GP-driven argmax of acquisition function over uniformly-sampled candidates). RBF kernel with default length scales `0.25` in normalised `[0,1]` parameter space; signal variance `1.0`; noise jitter `1e-6`. Two acquisition functions: `Expected_improvement` (default) and `Upper_confidence_bound β`. Determinism: same `Random.State.t` seed → byte-identical suggestion sequences. Convergence pinned by 1D parabola (`f(x) = -(x-3)²`) within 30 evals + 2D Branin within 50 evals. 27 tests including bounds enforcement, RBF/EI/UCB unit tests, GP-fit interpolation verification at observed points. Verify: `docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && dune runtest trading/backtest/tuner/'` (27/27 pass). Design decisions in `dev/plans/bayesian-opt-2026-05-03.md` §D1–D8. Follow-up: CLI binary (deferred from T-B to keep PR ≤500 LOC; mirrors T-A's split). Hyperparameter learning (Type-II MLE on length scales) deferred — fixed-hyperparameter GP is sufficient for the dimensions and budgets the M5.5 spec calls out.

- [x] **T-A grid_search lib + tests** (~440 LOC; PR #805 MERGED 2026-05-03). Surface: `trading/trading/backtest/tuner/lib/grid_search.{ml,mli}`. Cartesian product over a `(string * float list) list` param spec, configurable objective (`Sharpe | Calmar | TotalReturn | Concavity_coef | Composite of (metric_type * float) list`), pure evaluator callback so tests don't need to spin up a real backtest. Output writers for `grid.csv`, `best.sexp`, `sensitivity.md`. Verify: `dev/lib/run-in-env.sh dune runtest trading/backtest/tuner/` (24/24 pass). The 81-cell wall-time gate (<2hr on smoke scenarios) is deferred to a follow-up local verification — CI doesn't run smoke at scale.

## Next Steps

1. ~~Wire CLI binary at `trading/trading/backtest/tuner/bin/grid_search.ml`~~ — done (#893).
2. ~~Wire CLI binary at `trading/trading/backtest/tuner/bin/bayesian_runner.ml`~~ — done (#914).
3. ~~Run 81-cell flagship sweep~~ — first run published #1051; invalidated by PR #1061 (key-path bug in overlays).
4. **Bayesian Phase 3 PR-A** (scoring + aggregate consumer) — IN REVIEW
   (`feat/bayesian-phase3-pr-a`). 15 unit tests passing. PR-B (knob
   inventory) is the next deliverable in the 5-PR stack.
5. **Rerun the 81-cell flagship sweep with corrected field paths** — sweep `screening.weights.{w_positive_rs, w_strong_volume, w_stage2_breakout, w_sector_strong}` (the real `Screener.scoring_weights` field names; see PR #1068 `.mli` clarifications). Pair with `min_score_override` / `max_score_override` tightening to surface a cell-discriminating signal.
6. **Sweep-path validation linter** in `runner.ml:_merge_records` — fail on unrecognized keys to prevent silent-no-op overlays (closes the hazard surfaced by PR #1051 → #1061).
7. After corrected grid sweep results land, validate T-B converges to the same (or better) cell within ~30 evals using the same param surface — the convergence acceptance criterion in `m5-experiments-roadmap-2026-05-02.md` §M5.5 T-B.
8. T-C only after `data-foundations` Norgate ingest (need long enough train/test split).
9. Hyperparameter learning for T-B (Type-II MLE on length scales) — defer until 4-dim / 6-dim sweeps show that fixed length scales miss the optimum.

## Out of scope

- RL / PPO / A3C — different paradigm; defer indefinitely.
- Continuous online learning — strategy is weekly cadence, batch retraining suffices.
- Hyperparameter optimization for the ML models themselves (meta-tuning) — defer.
