# Status: tuning

## Last updated: 2026-05-25

## Status
IN_PROGRESS

**2026-05-22 — Bayesian Phase 3 stack COMPLETE; V1→V7 production
sweep stack run; methodology redesign IN REVIEW (PR #1237).** The full
PR-A→PR-E sequence landed 2026-05-17 (#1126/#1132/#1136/#1143/#1145).
Five production sweeps (V1 #1210 REJECT, V2 #1222 REJECT, V3 #1232
promotable under one gate variant, V4/V5/V6/V7 byte-identical scores
to V3) have run; the convergence finding is that **the 4-param Cell E
surface has plateaued** and further single-objective Bayesian sweeps
won't move metrics. PR #1237 explicitly defers all further 4-param
tuning work until cross-scenario validation lands as the new promote
gate (§9). Active surface is now: `promote_config.sh` (MERGED #1234)
+ cross-scenario validation panel (NOT YET DISPATCHED — proposed
track spawn per track-pacer 2026-05-22 §P7 / §Recommendations §1).

This week's stack (V3-V7 + methodology redesign, since 2026-05-17):

- **#1192** plan — Bayesian Phase 3 production-sweep dispatch.
- **#1196** plan — wire `spec.objective` into walk-forward `score_cell`
  (PR-1→PR-3 sequence).
- **#1210** V1 production sweep result — 5-axis promote-gate REJECT.
- **#1214** thread `spec.objective` through `score_cell` (#1196 PR-1).
- **#1216** implement Composite + single-metric-relative branches (PR-2).
- **#1217** drop CVaR + median→mean in sweep plan (PR-3 doc).
- **#1219** P4 per-stage hold-period decomposition (Probe P4 analysis).
- **#1220** wire AvgHoldingDays into Composite scorer (P5 infra).
- **#1222** V2 production sweep result — REJECT.
- **#1223** next-session priorities post-V2 (2026-05-21 PM).
- **#1224** `bo_checkpoint.sexp` for resume after crash (lost ~5h on
  2026-05-20 power-loss restart per `memory/project_bayesian_sweep_checkpoint_needed.md`).
- **#1225** V3 + V3-cadence Bayesian sweep specs (post-V2 REJECT).
- **#1226** V3 smoke spec + QC review writeups.
- **#1229** soft gate penalty via `spec.gate_penalty_value` + V4 spec.
- **#1232** V3 production result + axis-3 gate-fitness proposal.
- **#1234** `promote_config.sh` + tuning methodology design doc.
- **#1235** drop cosmetic `[name]` field from sexp output (-4.8 MB).
- **#1231** V5 spec — OPEN (wider bounds + soft gate).
- **#1236** V5 partial + V6 sweep specs — OPEN (gate-too-strict
  hypothesis).
- **#1237** tuning methodology redesign 2026-05-22 — OPEN (explicit
  deferral of further 4-param sweeps; proposes cross-scenario
  validation as new promote gate).

**Strategic pivot 2026-05-15 retained context.** Per
`dev/notes/next-session-priorities-2026-05-15.md`, multi-parameter
ML-discipline tuning over walk-forward CV with explicit MaxDD penalty
was the P0 vector. That work shipped: walk-forward harness
(`walk-forward-cv` track MERGED 2026-05-16) + Bayesian Phase 3 stack
(this track MERGED 2026-05-17). The V1→V7 sweep stack ran on the
resulting harness; the diminishing-returns finding now drives the
cross-scenario-validation pivot per #1237.

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

- **V5/V6 sweep specs + methodology redesign — IN REVIEW.** Three open
  PRs gate the next dispatch:
  - **#1231** V5 spec (wider bounds + soft gate).
  - **#1236** V5 partial result + V6 sweep specs (wider-bounds
    hypothesis rejected; gate-too-strict variant in flight).
  - **#1237** tuning methodology redesign 2026-05-22 — proposes
    cross-scenario validation as new promote gate; explicitly defers
    all further 4-param Bayesian sweeps until that lands (§9).
- **Cross-scenario validation panel — NOT YET DISPATCHED.** PR #1237
  §2.5 + §3 row A + §5 P1 + §8 frame it as the load-bearing
  methodology gap. `promote_config.sh` infra landed via #1234; the
  `validation.sexp` aggregate writer + REFERENCE scenario panel
  (sp500-2010-2026, sp500-2019-2023, broad-2019, French 49-industry
  1926-2026, Shiller 1871-2025) is unshipped. Track-pacer 2026-05-22
  §Recommendations §1: spawn `cross-scenario-validation` row OR fold
  as multi-PR block under this track.
- **Optimal-strategy quality refresh** — gates the §2.6 Composite
  `efficiency = candidate_sharpe / optimal_sharpe` term per #1237.
  Concern from #856 diagnostic note (2026-05-06); track-pacer
  2026-05-22 §P7 KEEP_AS_INFO.

### Bayesian Phase 3 — multi-parameter scaling (5-PR stack, plan PR #1124 MERGED)

Plan authority: `dev/plans/bayesian-multi-param-scaling-2026-05-16.md`.
**Stack COMPLETE 2026-05-17** — all 5 PRs MERGED:

- **PR-A: scoring function + walk-forward aggregate consumer** —
  MERGED PR #1126 (2026-05-16). `Tuner_bin.Bayesian_runner_scoring`
  pure scorer over a `Walk_forward_types.aggregate` + Cell E baseline
  with loss = `-mean_sharpe + lambda_dd*max(0, maxdd_excess) +
  lambda_gate*gate_penalty`; hyperparameters as named constants;
  15 unit tests.
- **PR-B: knob inventory + parameter space encoding** — MERGED PR
  #1132 (2026-05-16).
- **PR-C: walk-forward in-process integration** — MERGED PR #1136
  (2026-05-17). Hoists per-fold execution out of
  `bin/walk_forward_runner.ml` into shared
  `Walk_forward.Walk_forward_executor.execute_spec`. Adds
  `Bayesian_runner_evaluator.build_walk_forward` alongside the legacy
  `build`; per BO iteration scores via PR-A's `score_cell`.
- **PR-D: int/Option encoding + GP length-scale tuning + early-stop**
  — MERGED PR #1143 (2026-05-17).
- **PR-E: end-to-end runner + OOS holdout validator** — MERGED PR
  #1145 (2026-05-17).

### V1→V7 production sweep stack (2026-05-19..22)

Plan / next-session pointers:
`dev/notes/next-session-priorities-2026-05-21.md`,
`dev/notes/next-session-priorities-2026-05-21-pm.md`,
`dev/plans/tuning-methodology-redesign-2026-05-22.md` (PR #1237).

- **V1** (#1210 result, 2026-05-19) — 5-axis promote-gate REJECT.
- **V2** (#1222 result, 2026-05-20) — REJECT. Lost ~5h to power-loss
  restart on 2026-05-20; checkpointing landed via #1224 to prevent
  recurrence.
- **V3** (#1232 result, 2026-05-21) — promotable under one gate
  variant; axis-3 gate-fitness proposal for human review.
- **V4** (spec #1229 soft gate penalty) — byte-identical score to V3.
- **V5** (spec #1231 OPEN; partial #1236) — wider-bounds hypothesis
  rejected; gate-too-strict variant under V6 in flight.
- **V6** (specs #1236 OPEN) — gate-too-strict hypothesis under test.
- **V7** — byte-identical score to V3 per #1237 §1.

**Diminishing-returns verdict (per #1237 §1 + track-pacer 2026-05-22 §P6):**
the 4-param Cell E surface has plateaued; further sweeps on this
surface will not produce new alpha. PR #1237 §9 explicitly defers
further 4-param work until cross-scenario validation lands. Composite
scorer shipped (#1216), soft-gate shipped (#1229), checkpointing
shipped (#1224), promote-gate scaffolding shipped (#1234) — the
methodology evolution was productive; the parameter-discovery was
not.

### Operational follow-ups

- **Sweep-overlay path validator** — MERGED #1069 (2026-05-13); closes
  the silent-no-op hazard from PR #1051 → #1061.
- **81-cell flagship rerun with corrected field paths** — SUPERSEDED
  by walk-forward CV + Bayesian Phase 3 stack. The corrected
  scoring_weights field paths (`w_positive_rs/w_strong_volume/
  w_stage2_breakout/w_sector_strong`) per #1068 `.mli` clarifications
  are now BO knobs in PR-B's parameter encoding (#1132); no further
  manual grid sweep needed.

## Completed

- [x] **M1 T1.1 — `Window_spec.Tiered` variant** (branch `feat/walk-forward-window-spec-tiered`; pure data-shape PR per `dev/plans/tuning-research-driven-program-v2-2026-05-25.md` Milestone M1). Adds a third constructor to `Walk_forward.Window_spec.t` alongside the existing `Rolling`/`Explicit`: `Tiered of tiered_spec`, where `tiered_spec` carries a shared `start_date`/`end_date`/`train_days` plus an ordered `tiers : tier list` (cheap → expensive). Each `tier` names a `fold_count` + `horizon_days` for one fidelity stage. `generate` returns the concatenation of per-tier folds (global `index`, within-tier zero-padded name `<tier-name>-NNN`); each tier independently tiles its folds non-overlappingly from `start_date + train_days` with `step_days = horizon_days`. Overflow (`fold_count * horizon_days + train_days > end_date - start_date + 1`) raises `Failure` rather than silently truncating. Sexp parser extended to recognise the `Tiered`-tagged variant alongside `Rolling`/`Explicit`; legacy flat-record shape still parses as `Rolling`. 13 new tests in `test_window_spec.ml` covering parse, multi-tier concat with global indices, within-tier name padding, per-tier anchoring, train-then-test back-to-back, `train_days = 0` no-train-period case, overflow/empty-tiers/dup-name/zero-fold_count/zero-horizon_days/negative-train_days failure paths, and sexp round-trip. Existing 17 Rolling/Explicit tests pass unchanged (regression). T1.1 is a data-shape-only PR — no runner integration, no CLI flag, no promotion strategy (those are T1.2/T1.3). Verify: `docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && dune runtest trading/backtest/walk_forward/test/ --force'` (30/30 pass).

- [x] **M4 T4.1 — Walk-forward fixture for 1998-2026 28-fold** (branch `feat/m4-fixture-1998-2026`). New checked-in fixture `trading/test_data/walk_forward/cell_e_full_history_28fold_2026_05_25.sexp` (Rolling window, start 1998-01-01 / end 2026-04-30 / test 365d / step 365d annual non-overlapping → 28 folds; single `cell-E` variant per plan v2 delta #4 — Cell E baseline dropped for 1998-2026 sweep, M4 gate is qNEHVI Pareto front + DSR + outer-holdout, not per-fold M-of-N; `holdout_folds (25 26 27 28)` reserves last 4 for BO outer-holdout per M3). New scaffolding base scenario `trading/test_data/backtest_scenarios/goldens-sp500-historical/sp500-1998-2026.sexp` (research-tier, points at `top-3000-1998` as T4.1 placeholder universe — T4.2 plumbs per-fold rotation through top-3000-YYYY snapshots). Five new tests in `trading/trading/backtest/walk_forward/test/test_spec.ml` pin: fixture parses, window spans 1998-01-01..2026-04-30 with the right rolling params, generate produces 27-29 folds (target 28, ±1 for leap-year drift), single cell-E variant, gate is non-firing (m=0, n=28). Per plan `dev/plans/tuning-research-driven-program-v2-2026-05-25.md` §M4 T4.1. Verify: `docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && dune runtest trading/backtest/walk_forward/test'` (12/12 pass).

- [x] **PR #1047 — `grid_search.exe --parallel N` (cell-level parallelism)** (MERGED 2026-05-12). Reduces wall-time for large grids by running N cells concurrently. Used for the 81-cell flagship sweep.

- [x] **PR #914 — T-B Bayesian-opt CLI binary + tests** (MERGED 2026-05-07; ~775 LOC including tests; branch `feat/backtest-tuning-bayesian-opt-cli`). Closes the deferred T-B CLI follow-up from PR #817. Three new modules under `trading/trading/backtest/tuner/bin/`: `Bayesian_runner_spec` (sexp-driven param-bounds + acquisition + objective + budget parser, with `to_grid_objective` / `to_acquisition` / `to_bo_config` projections), `Bayesian_runner_evaluator` (adapts `Backtest.Runner.run_backtest` to the BO loop's per-suggestion callback, scalarises with `Tuner.Grid_search.evaluate_objective`, walks scenarios in spec order), `Bayesian_runner_runner` (drives the `Tuner.Bayesian_opt.suggest_next`/`observe` ask/tell loop for `total_budget` iters, emits `bo_log.csv` + `best.sexp` + `convergence.md` per the M5.5 T-B spec). CLI binary `bayesian_runner.exe` with flags `--spec <path> --out-dir <dir> [--fixtures-root <path>]`. 11 unit tests pin every non-trivial `.mli` claim: spec parsing (simple Expected_improvement spec + UCB acquisition with Composite objective + malformed-raises), `to_grid_objective`/`to_acquisition` round-trips, `to_bo_config` field propagation, `run_and_write` plumbing against a 1D-parabola stub evaluator (three-artefact emission + mkdir-p + convergence within tol 0.5 + byte-identical bo_log under fixed seed), evaluator unknown-scenario `Failure` guard. Smoke-scenario integration deferred (mirrors PR #893's deferral; full-universe single eval ~5–10 min, run locally before the convergence cross-check). Lib at `trading/trading/backtest/tuner/lib/` is unchanged. Verify: `dev/lib/run-in-env.sh dune runtest trading/backtest/tuner/ --force` (72/72 pass) + `dev/lib/run-in-env.sh dune exec trading/backtest/tuner/bin/bayesian_runner.exe -- --help`. Hyperparameter learning (Type-II MLE on length scales) remains deferred per `dev/plans/bayesian-opt-2026-05-03.md` §"Out of scope".

- [x] **#892 cascade score-floor knob exposed for grid sweep** (MERGED 2026-05-06; ~250 LOC; branch `feat/screener/888-threshold-param`). Added `min_score_override : int option` to `Screener.config` (default `None` preserves grade-based filter bit-equally; `Some n` replaces with strict `score >= n` numeric gate). Threaded via `_passes_score_floor` helper through `_score_and_build`, `_long_admission`/`_short_admission`, and the diagnostics-counting path (single source of truth). Registered in `Tuner.Grid_search.param_spec` docstring as a sweepable dimension at `screening_config.min_score_override`. Override deep-merge pinned by `test_override_screening_min_score_override` in `test_runner_hypothesis_overrides.ml`. 5 new unit tests in `test_screener.ml` pin the gate's `>=` semantics + bit-equal-default contract. 3-cell quick-look on sp500-2019-2023 (cells: default / 41 / 42) documented in `dev/notes/888-score-threshold-quick-look-2026-05-06.md` — finding consistent with #871's "cascade is at no-look-ahead ceiling" verdict; full sweep deferred until #872 / #887 capital-recycling lands. Verify: `dev/lib/run-in-env.sh dune runtest analysis/weinstein/screener/test/` + `dev/lib/run-in-env.sh dune exec trading/backtest/test/test_runner_hypothesis_overrides.exe`.

- [x] **#893 T-A grid_search CLI binary + tests** (MERGED 2026-05-06; branch `feat/backtest-tuning-grid-search-cli`). Completes the T-A CLI deferred follow-up from PR #805. Three new modules: `Grid_search_spec` (sexp-driven param spec + objective parser), `Grid_search_evaluator` (adapts `Backtest.Runner.run_backtest` to the pure evaluator callback), `Grid_search_runner` (orchestrates multi-cell runs + emits artefacts). CLI binary `grid_search.exe` with flags `--spec <path> --out-dir <dir> [--fixtures-root <path>]`. 7 unit tests: spec parsing (simple + Composite + malformed-raises), `to_grid_objective` round-trip, `run_and_write` plumbing against stub evaluator (argmax + three-artefact emission + mkdir-p semantics), cache-miss-Failure guard pinned per CP4. Smoke-scenario integration deferred (full-universe single cell ~5-10 min; to be run locally before the 81-cell flagship sweep). Verify: `dune runtest trading/backtest/tuner/bin/test/` (7/7 pass) + `dune exec backtest/tuner/bin/grid_search.exe -- --help`.
- [x] **T-B Bayesian-opt lib + tests** (~922 LOC including tests, ~439 lib; branch `feat/tuner-bayesian-opt`). Surface: `trading/trading/backtest/tuner/lib/bayesian_opt.{ml,mli}`. Pure functional GP-based optimiser using `owl` (`Owl.Linalg.D.chol` + `triangular_solve` for the Cholesky-factor linear system, `Owl.Mat` for matrix ops). Two-phase suggestion (initial random samples → GP-driven argmax of acquisition function over uniformly-sampled candidates). RBF kernel with default length scales `0.25` in normalised `[0,1]` parameter space; signal variance `1.0`; noise jitter `1e-6`. Two acquisition functions: `Expected_improvement` (default) and `Upper_confidence_bound β`. Determinism: same `Random.State.t` seed → byte-identical suggestion sequences. Convergence pinned by 1D parabola (`f(x) = -(x-3)²`) within 30 evals + 2D Branin within 50 evals. 27 tests including bounds enforcement, RBF/EI/UCB unit tests, GP-fit interpolation verification at observed points. Verify: `docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && dune runtest trading/backtest/tuner/'` (27/27 pass). Design decisions in `dev/plans/bayesian-opt-2026-05-03.md` §D1–D8. Follow-up: CLI binary (deferred from T-B to keep PR ≤500 LOC; mirrors T-A's split). Hyperparameter learning (Type-II MLE on length scales) deferred — fixed-hyperparameter GP is sufficient for the dimensions and budgets the M5.5 spec calls out.

- [x] **T-A grid_search lib + tests** (~440 LOC; PR #805 MERGED 2026-05-03). Surface: `trading/trading/backtest/tuner/lib/grid_search.{ml,mli}`. Cartesian product over a `(string * float list) list` param spec, configurable objective (`Sharpe | Calmar | TotalReturn | Concavity_coef | Composite of (metric_type * float) list`), pure evaluator callback so tests don't need to spin up a real backtest. Output writers for `grid.csv`, `best.sexp`, `sensitivity.md`. Verify: `dev/lib/run-in-env.sh dune runtest trading/backtest/tuner/` (24/24 pass). The 81-cell wall-time gate (<2hr on smoke scenarios) is deferred to a follow-up local verification — CI doesn't run smoke at scale.

## Next Steps

1. ~~Wire CLI binary at `trading/trading/backtest/tuner/bin/grid_search.ml`~~ — done (#893).
2. ~~Wire CLI binary at `trading/trading/backtest/tuner/bin/bayesian_runner.ml`~~ — done (#914).
3. ~~Run 81-cell flagship sweep~~ — SUPERSEDED. Replaced by walk-forward
   CV + Bayesian Phase 3 (#1126→#1145) + V1→V7 production sweep stack.
4. ~~Bayesian Phase 3 PR-A→PR-E stack~~ — **DONE** 2026-05-17
   (#1126/#1132/#1136/#1143/#1145).
5. ~~Sweep-path validation linter~~ — DONE via #1069 (2026-05-13).
6. **Decide on cross-scenario validation as a track** (NEW, top of
   queue per track-pacer 2026-05-22 §Recommendations §1). Either spawn
   `dev/status/cross-scenario-validation.md` per
   `dev/plans/tuning-methodology-redesign-2026-05-22.md` §3 row A, or
   formally add the work as a multi-PR block under this track. PR
   #1237 explicitly defers further 4-param tuning work until this
   lands (§9).
7. **Resolve open V5/V6 PRs** (#1231, #1236, #1237). #1237 is the
   load-bearing decision — its acceptance gates whether V5/V6 sweep
   work continues or stops outright.
8. **Optimal-strategy quality refresh** — gates the §2.6 Composite
   efficiency term per #1237. Concern surfaced 2026-05-06 (#856
   diagnostic) but never addressed. Low-cost (~2-3h); prerequisite
   for the next sweep dimension if BO continues to be used.
9. T-C (supervised ML) — RETIRED per `dev/status/_index.md` 2026-05-16
   reconcile (Norgate vendor pivot). If revisited, reroute through
   the EODHD + IWV + fja05680 data stack.
10. Hyperparameter learning for the GP (Type-II MLE on length scales)
    — partially landed via PR-D #1143; defer further refinement until
    cross-scenario validation establishes whether 4-param surface
    discrimination matters at all.

## Out of scope

- RL / PPO / A3C — different paradigm; defer indefinitely.
- Continuous online learning — strategy is weekly cadence, batch retraining suffices.
- Hyperparameter optimization for the ML models themselves (meta-tuning) — defer.
