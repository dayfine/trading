# Bayesian optimizer — scale from 4-D bounds to full Cell E knob set (Phase 3)

Date: 2026-05-16. Authority:
`dev/notes/next-session-priorities-2026-05-16.md` §"P3 Bayesian
optimizer" (carried forward unchanged from
`dev/notes/next-session-priorities-2026-05-15.md` §"Phase 3 —
multi-parameter Bayesian optimizer"). Predecessors: PR #914
(`bayesian_runner.exe` + `Tuner.Bayesian_opt` lib), PR #1100 + PR #1116
(walk-forward CV harness with structured `aggregate.sexp` output for
programmatic consumption).

This is a **plan-only PR**. No `.ml`/`.mli` changes. Plan splits into
~5 stacked PRs over a ~1-week track.

## 1. Current state assessment

### 1.1 What `bayesian_runner.exe` does today

The binary lives at
`trading/trading/backtest/tuner/bin/bayesian_runner.ml` (99 lines) and
wires three sibling modules:

- `Bayesian_runner_spec` (`bayesian_runner_spec.{ml,mli}`) — parses an
  on-disk sexp spec into a record with `bounds`, `acquisition`,
  `initial_random`, `total_budget`, `seed`,
  `n_acquisition_candidates`, `objective`, `scenarios`. The objective
  is one of `Sharpe`, `Calmar`, `TotalReturn`, `Concavity_coef`, or a
  `Composite` weighted-sum of metrics.
- `Bayesian_runner_evaluator`
  (`bayesian_runner_evaluator.ml:40-48`) — for each `suggest_next`
  parameters tuple, runs `Backtest.Runner.run_backtest` once per
  scenario path in the spec's `scenarios` list (merging
  `cell_to_overrides parameters` onto the scenario's
  `config_overrides`), then **averages the scalar objective across
  scenarios** (`_mean` at lines 36-38).
- `Bayesian_runner_runner` (`bayesian_runner_runner.ml`) — runs the BO
  ask/tell loop for `total_budget` iterations, writing `bo_log.csv`,
  `best.sexp`, and `convergence.md` under `out_dir`.

The underlying optimizer (`Tuner.Bayesian_opt`,
`tuner/lib/bayesian_opt.{ml,mli}`) is a small GP-based BO loop with
RBF kernel, two acquisition functions (`Expected_improvement`,
`Upper_confidence_bound β`), a two-phase ask (random for the first
`initial_random` calls, then GP-driven). The mli explicitly notes
"for the dimensions BO is meaningful at — ≤10 — random search
suffices" for the acquisition argmax inner loop. This dimensionality
ceiling is load-bearing for the Phase 3 design (see §5).

### 1.2 The current 4-D surface

The example sexp embedded in `bayesian_runner_spec.mli:65-74`:

```
(bounds
 (("screening.weights.rs" (0.1 0.5))
  ("screening.weights.volume" (0.1 0.5))))
(acquisition Expected_improvement)
(initial_random 5) (total_budget 30) (seed 17)
(n_acquisition_candidates ())
(objective Sharpe)
(scenarios "trading/test_data/backtest_scenarios/smoke/bull-2019.sexp")
```

In practice, PR #914 tested with 2-D and the docstring claims the lib
is meaningful "at ≤10". The Phase 3 target — 15-25 knobs in the
priorities doc — is **beyond** what `Tuner.Bayesian_opt`'s current GP
surface was designed for. This is §5's central design question.

### 1.3 Scoring today

`_mean` of per-scenario objectives. **No MaxDD penalty, no
walk-forward integration, no gate verdict** — a candidate that fails
every fold of a walk-forward CV would still score on its mean
in-sample value. Replacing this with a walk-forward-aware scorer is
the gating change of Phase 3.

### 1.4 Cell E config knob count

The canonical strategy config is
`trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli`.
Including nested records, the surface is roughly:

- `stage_config` (Stage): `ma_period`, `slope_threshold`,
  `slope_lookback`, `confirm_weeks`, `late_stage2_decel`,
  `stage_method` — 6 knobs (5 numeric + 1 enum)
- `macro_config` (Macro): `bullish_threshold`, `bearish_threshold` +
  nested `indicator_weights` (5 floats) + `indicator_thresholds`
  (8 floats) — 15 knobs
- `screening_config` (Screener): `weights` (scoring weights),
  `grade_thresholds`, `candidate_params` (8 floats inc. `entry_buffer_pct`,
  `initial_stop_pct`, `installed_stop_min_pct`, ...), `min_score_override`,
  `max_score_override`, `volume_ratio_exclude_range`,
  `max_buy_candidates` — ~20 knobs
- `portfolio_config` (Portfolio_risk): `risk_per_trade_pct`,
  `max_positions`, `max_long_exposure_pct`,
  `max_short_exposure_pct`, `max_short_notional_fraction`,
  `min_cash_pct`, `max_position_pct_long`,
  `max_position_pct_short`, `max_sector_concentration`,
  `max_sector_exposure_pct`, `max_unknown_sector_positions` — ~11
  knobs
- `stops_config` (Weinstein_stops): trailing-stop parameters — ~5
  knobs
- `initial_stop_buffer`, `lookback_bars`,
  `bar_history_max_lookback_days`,
  `stage3_force_exit_config.hysteresis_weeks`,
  `laggard_rotation_config.{hysteresis_weeks, rs_window_weeks}`,
  `continuation_config.{ma_slope_min, pullback_band.low,
  pullback_band.high, pullback_lookback_weeks,
  consolidation_range_pct, consolidation_weeks}` — ~12 knobs

**Total ~70 tunable knobs.** The priorities doc target of 15-25
implies a curated subset, not the full surface. Knob selection is
the single most important Phase 3 design decision (§2).

## 2. Target knob inventory

The priorities doc's "15-25 tunable parameters" must be **chosen for
known sensitivity**, not because they exist. Past
`memory/project_m5-5-tuning-exhausted.md` and
`memory/project_continuation_combined_rejected.md` already mapped the
sensitivity landscape: most M5.5 single-axis sweeps were rejected or
neutral, with axis-1 winner `installed_stop_min_pct=0.08` as the
durable signal.

Grouped by track. **Status legend:** *known sensitive* = produced a
verdict in a prior sweep; *plausible* = adjacent to a sensitive
knob but untested; *near-fixed* = changing it has not produced a
non-trivial effect in prior sweeps; *avoid* = explicitly rejected.
**Default values cited from the .mli docstrings.**

### Track A — stops & entry geometry (known-sensitive, ~5 knobs)

| Knob | Default | Proposed range | Step | Status |
|---|---|---|---|---|
| `initial_stop_buffer` | 1.0 (1.0x ATR) | 0.5 – 2.0 | 0.05 | known sensitive (M5.4 E3 stop-buffer sweep) |
| `screening_config.candidate_params.initial_stop_pct` | 0.08 | 0.04 – 0.15 | 0.005 | known sensitive |
| `screening_config.candidate_params.installed_stop_min_pct` | 0.0 | 0.0 – 0.12 | 0.01 | **axis-1 winner** at 0.08 — keep in surface but tight-bound |
| `screening_config.candidate_params.entry_buffer_pct` | 0.005 | 0.0 – 0.02 | 0.001 | plausible |
| `screening_config.candidate_params.base_low_proxy_pct` | 0.15 | 0.10 – 0.25 | 0.01 | plausible |

Interactions: `initial_stop_buffer × installed_stop_min_pct` is a
near-redundancy floor; expect strong negative correlation.

### Track B — position sizing & exposure (known sensitive, ~5 knobs)

| Knob | Default | Proposed range | Step | Status |
|---|---|---|---|---|
| `portfolio_config.max_position_pct_long` | 0.30 (0.14 in 15y override) | 0.05 – 0.25 | 0.01 | known sensitive (PR #855, #1051) |
| `portfolio_config.max_long_exposure_pct` | 0.90 (0.70 in 15y override) | 0.50 – 0.95 | 0.05 | known sensitive but partly inert (caps dominated by per-position) |
| `portfolio_config.min_cash_pct` | 0.10 (0.30 in 15y override) | 0.10 – 0.40 | 0.05 | deprecated per .mli — **exclude** |
| `portfolio_config.risk_per_trade_pct` | 0.01 | 0.005 – 0.03 | 0.0025 | plausible |
| `portfolio_config.max_positions` | 20 | 10 – 40 (int) | 1 | plausible — int knob, see §2.5 |
| `portfolio_config.max_sector_concentration` | 5 | 3 – 10 (int) | 1 | plausible — sector cap landed PR #1098 |
| `portfolio_config.max_sector_exposure_pct` | None | 0.10 – 0.35 (or None) | 0.025 | plausible — option semantics, see §2.5 |

Interactions: `max_position_pct_long × max_long_exposure_pct ×
max_positions` form a binding-cap triangle. Past observation
(`memory/project_2026-05-10_session.md`,
`feedback_position_count_capital_scaling.md`) confirms only one is
typically binding at a time.

### Track C — stage classifier (mostly near-fixed)

| Knob | Default | Proposed range | Step | Status |
|---|---|---|---|---|
| `stage_config.ma_period` | 30 (book) | **DO NOT TUNE** | — | book-canonical; qc-behavioral S2 authority |
| `stage_config.slope_threshold` | 0.005 | 0.002 – 0.015 | 0.001 | plausible |
| `stage_config.slope_lookback` | 4 | 3 – 8 (int) | 1 | plausible |
| `stage_config.confirm_weeks` | 6 | 4 – 10 (int) | 1 | plausible |
| `stage_config.late_stage2_decel` | 0.5 | 0.3 – 0.7 | 0.05 | plausible — only fires the "late" flag |

Total: 4 tunable. `ma_period` is excluded by book authority.

### Track D — Cell E feature flags (binary, ~4 knobs)

| Knob | Default | Proposed range | Status |
|---|---|---|---|
| `enable_stage3_force_exit` | false (Cell E: true) | {false, true} | binary; encode as 0/1 |
| `enable_laggard_rotation` | false (Cell E: true) | {false, true} | binary; encode as 0/1 |
| `enable_continuation_buys` | false | {false, true} | binary; rejected on 16y but **let the optimizer try with walk-forward gate** |
| `stage3_force_exit_config.hysteresis_weeks` | 2 | 1 – 5 (int) | known sensitive (Cell E h=1) |
| `laggard_rotation_config.hysteresis_weeks` | 4 | 1 – 8 (int) | known sensitive (Cell E h=2) |
| `laggard_rotation_config.rs_window_weeks` | 13 | 8 – 26 (int) | plausible |

Binaries via 0/1 float encoding is supported by the existing
`Tuner.Bayesian_opt` (rounds at evaluator boundary; the
`cell_to_overrides` machinery encodes integer-valued floats correctly
per `grid_search.mli:56-65`).

### Track E — screening cascade weights (~4 knobs)

| Knob | Default | Proposed range | Step |
|---|---|---|---|
| `screening_config.weights.rs` | per `default_scoring_weights` | 0.05 – 0.50 | 0.025 |
| `screening_config.weights.volume` | per `default_scoring_weights` | 0.05 – 0.50 | 0.025 |
| `screening_config.weights.breakout` | per default | 0.05 – 0.50 | 0.025 |
| `screening_config.min_score_override` | None | 30 – 55 (or None) | 1 |
| `screening_config.max_buy_candidates` | 20 | 10 – 40 | 2 |

The original 4-D surface in PR #914 was already tuning two of these.
Keep the surface restricted — the weights sum to a constant in
practice, so the BO will trip over a redundancy (see Risks §9).

### 2.1 Curated 18-knob surface (recommended starting point)

The intersection of "known-sensitive ∨ adjacent to a sensitive
knob" produces this 18-knob list. **PR-B specifies this list as the
default `bounds` block in the Phase-3 spec.**

```
;; Track A — entry / stop geometry (5)
("initial_stop_buffer" (0.5 2.0))
("screening_config.candidate_params.initial_stop_pct" (0.04 0.15))
("screening_config.candidate_params.installed_stop_min_pct" (0.0 0.12))
("screening_config.candidate_params.entry_buffer_pct" (0.0 0.02))
("screening_config.candidate_params.base_low_proxy_pct" (0.10 0.25))

;; Track B — sizing / exposure (4)
("portfolio_config.max_position_pct_long" (0.05 0.25))
("portfolio_config.max_long_exposure_pct" (0.50 0.95))
("portfolio_config.risk_per_trade_pct" (0.005 0.03))
("portfolio_config.max_sector_concentration" (3 10))

;; Track C — stage classifier (3)
("stage_config.slope_threshold" (0.002 0.015))
("stage_config.slope_lookback" (3 8))
("stage_config.confirm_weeks" (4 10))

;; Track D — Cell E mechanics (3)
("stage3_force_exit_config.hysteresis_weeks" (1 5))
("laggard_rotation_config.hysteresis_weeks" (1 8))
("laggard_rotation_config.rs_window_weeks" (8 26))

;; Track E — screening cascade (3)
("screening_config.weights.rs" (0.05 0.50))
("screening_config.weights.volume" (0.05 0.50))
("screening_config.max_buy_candidates" (10 40))
```

This is **18 knobs** — toward the upper end of the priorities-doc
range. Track-D feature-flag tuning (binaries) is excluded from PR-B
v1 and reserved for PR-D follow-up; binaries make the GP land-scape
discontinuous and would amplify the dimensionality concern in §5.

### 2.5 Int / Option encoding

Integer knobs (`max_positions`, `confirm_weeks`,
`hysteresis_weeks`, ...) are bounded as floats; the evaluator rounds
at `cell_to_overrides` time. Per `grid_search.mli:56-65`, the
sexp-emit pipeline already converts an integer-valued float
correctly (e.g. `40.0` → `Atom "40."` → `Some 40`).

Option knobs (`min_score_override : int option`,
`max_sector_exposure_pct : float option`) need a sentinel encoding.
**Recommend deferring Option knobs to PR-D** (post-validation of the
non-Option surface). PR-B excludes them.

## 3. Scoring function

### 3.1 Loss formulation

```
loss(cell) = -mean_sharpe(cell)
           + λ_dd * max(0, mean_maxdd(cell) - cell_e_baseline_maxdd)
           + λ_gate * gate_penalty(cell)
```

Where:

- `mean_sharpe(cell)` — mean Sharpe across walk-forward CV folds,
  **excluding folds whose return is below a degenerate-portfolio
  floor** (-50% on the fold). Degenerate-portfolio folds (mass
  liquidation cascades) get `gate_penalty` instead, not a free pass.
- `mean_maxdd(cell)` — mean MaxDD% across folds.
- `cell_e_baseline_maxdd` — pinned baseline MaxDD on the same
  walk-forward spec. **PR-A reads this from the Cell E
  `aggregate.sexp` reference run** rather than hardcoding it.
- `λ_dd` — penalty coefficient on excess MaxDD. Recommend
  `λ_dd = 0.10` initially: every 1pp of excess MaxDD costs 0.10
  units of Sharpe-equivalent loss. **Tuneable hyperparameter.**
- `gate_penalty(cell)` — `0.0` if `gate.verdict = Pass`, `+10.0` if
  `Fail`. The synthetic Fail variant ("fold-pair count mismatch"
  per `walk_forward_report.mli:30-35`) collapses to `+10.0` too.
- `λ_gate` — `1.0`. The +10.0 magnitude is chosen to dominate any
  marginal Sharpe improvement; cells that fail the M-of-N gate are
  pushed to the tail of the search distribution.

The optimizer maximizes (per `Bayesian_opt`'s convention "higher is
better"); we negate `loss` → score. Equivalently: `score = -loss`.

### 3.2 Why this shape

- **Mean Sharpe over folds** is the canonical walk-forward outcome.
- **MaxDD penalty as a one-sided hinge** (only positive excess
  penalised) prevents the optimizer from being rewarded for
  artificially deep drawdowns that boost return; mirrors the
  priorities-doc constraint "MaxDD no worse".
- **Gate as a hard penalty, not an infinity** lets the GP still
  receive a finite gradient signal near the boundary. Infinity would
  destabilise the GP posterior (`fit_gp` is closure-over-Cholesky and
  doesn't tolerate non-finite y values).
- **No variance penalty in v1.** A variance-of-Sharpe-across-folds
  penalty is tempting (stability is a goal) but adds a third
  hyperparameter; PR-D or later if needed.

### 3.3 Authority

This loss shape extends the qc-behavioral A1 constraint that
"strategy-agnostic" changes don't impose policy beyond the
strategy's configured knobs. The MaxDD penalty is operator policy
imposed *outside* the strategy, encoded in the scorer alone — no
core-module change. The strategy itself does not see the penalty.

## 4. Walk-forward integration

### 4.1 Read path

The walk-forward runner writes `aggregate.sexp` at
`walk_forward_runner.ml:140-155`. The schema is
`Walk_forward_report.aggregate` (per
`walk_forward_types.mli:63-72`):

```
{ fold_count : int;
  baseline_label : string;
  metric_label : string;
  stability : variant_stability list;
  sensitivity : variant_sensitivity list;
  verdicts : (string * Fold_gate.verdict) list }
```

For Phase 3, **each BO `suggest_next` triggers one walk-forward run**,
not one per-scenario backtest. The evaluator's current
`_run_one`+`_mean` pattern (per-scenario then mean) is replaced.

### 4.2 Evaluator rewrite

```
type t = parameters:(string * float) list -> float * walk_forward_record

(* PR-A delivers:
 *   - Spawn `walk_forward_runner.exe` as a subprocess (cmdline:
 *     --spec <walk-forward-spec.sexp> --out-dir <tmp> --variant-overrides
 *     <cell.sexp>); read `<tmp>/aggregate.sexp`; compute the loss.
 *   OR
 *   - Call `Walk_forward_report.compute` in-process after running each
 *     fold via `Backtest.Runner.run_backtest` per the existing
 *     walk-forward harness's internals.
 *
 * Recommendation: in-process. Subprocess invocation adds 5-10s wall
 * time per BO iteration (process spawn + sexp serialise+deserialise)
 * and is unnecessary — the walk-forward runner's per-fold
 * `Backtest.Runner.run_backtest` calls are the same primitive the
 * tuner already invokes. PR-A pulls the per-fold logic into a
 * library entry point that both `walk_forward_runner` and the
 * Bayesian evaluator can share. *)
```

The **shared entry point** lives at `Walk_forward_report` or a new
`Walk_forward_executor` module — name picked at PR-A implementation
time. Owner: `feat-backtest`.

### 4.3 Metrics extracted from `aggregate`

For the score function:

- `stability[<candidate_variant>].sharpe_ratio.mean` — `mean_sharpe`
- `stability[<candidate_variant>].max_drawdown_pct.mean` — `mean_maxdd`
- `verdicts[<candidate_variant>]` — gate Pass/Fail for the
  `gate_penalty` term
- `stability[<candidate_variant>].sharpe_ratio.stdev` — recorded but
  not penalised in v1; logged for diagnostics

### 4.4 Variant labelling

The candidate's `cell` (a parameter tuple) is the variant under test.
Convention: the BO loop uses `variant_label = "bo-iter-<N>"` (N from
the BO iteration counter); the baseline is always `cell-E` (the spec's
baseline_label). The walk-forward spec's `variants` list is built
dynamically per BO iteration: `[cell-E (no-op overrides), bo-iter-N
(BO's `cell_to_overrides`)]`. Each BO iteration's walk-forward run is
a **two-variant** comparison, not a multi-variant sweep — keeps the
fold count predictable.

## 5. Convergence + early-stopping

### 5.1 Budget arithmetic

Wall-clock estimate per BO iteration:

- 1 BO iteration = 1 walk-forward run = 30 folds.
- Per-fold time = `Backtest.Runner.run_backtest` on 510-sym 2010-2026
  universe per 1-year window. Empirically (per
  `dev/notes/...walk-forward...`): ~20-40s per fold on tier-2
  hardware.
- Per iteration ≈ 30 × 30s = 15 min, plus the in-process aggregate
  computation (negligible).
- 100 iterations ≈ 25 hours wall-clock.
- 300 iterations ≈ 75 hours wall-clock.

The priorities-doc range "50-150 hours" maps to **~100-300 BO
iterations**.

### 5.2 GP dimensionality concern

`Tuner.Bayesian_opt`'s mli says BO is "meaningful at ≤10
dimensions". At 18 dimensions, the GP posterior risks under-fitting
(the kernel's effective bandwidth in 18-D requires far more
observations to localise). Three responses:

1. **Curate down to ≤12** — drop Track-C entirely (stage classifier
   is mostly near-fixed). Lands at 14 knobs minus the stage
   classifier triple = **11 knobs**. Recommended for PR-B v1.
2. **Increase `length_scales` defaults proportionally to
   dimensionality** — set ℓᵢ to a value that scales as `sqrt(d) * 0.25`
   to keep the kernel's effective basis stable. Requires extending
   `Tuner.Bayesian_opt.create_config` to accept a length-scale
   default override. Reserved for PR-C.
3. **Random-search baseline** — at 18-D, the docstring's note that
   "random search suffices" is the natural fallback. PR-D adds a
   `--strategy random-search` switch; the scorer + walk-forward
   plumbing is shared.

**PR-B starts with the 11-knob Track A+B+D+E surface, omitting
Track C.** This satisfies the priorities doc's "15-25 tunable
parameters" lower bound when combined with three more knobs in PR-D
(the Option / binary knobs).

### 5.3 Acquisition + initial-random

- Acquisition: `Upper_confidence_bound β=2.0` for the first half of
  the budget (more exploration), `Expected_improvement` for the
  second half. Requires a small extension to
  `Bayesian_runner_spec.acquisition_spec` to encode the schedule.
  **OR** stay with `Expected_improvement` throughout; defer the
  schedule to PR-C. v1: stay with `Expected_improvement`.
- `initial_random`: 20-30. With 11 knobs, the GP needs ~10× knob
  count to fit reliably; 20-30 random samples consume ~5-7 hours
  before GP-driven suggestions begin.

### 5.4 Early-stopping

After `initial_random` is exhausted, monitor `running_best` per the
`convergence.md` writer (`bayesian_runner_runner.ml:104-118`). Stop
early when:

```
running_best[i] - running_best[i - K] < epsilon
  for K consecutive non-improving iterations
  where K = 20, epsilon = 0.02 Sharpe-equivalent
```

Rationale: 20 non-improving iterations represents ~5 hours of
compute spent on a flat region of the posterior; early-stop here
unless the user explicitly disables (`--no-early-stop`). PR-D.

## 6. Validation acceptance criterion

Per priorities doc: "converges to a cell that beats Cell E on
walk-forward Sharpe by ≥0.05 with MaxDD no worse."

Concretely:

1. **In-sample acceptance** — at the end of the BO run, the best
   cell's mean walk-forward Sharpe (in the spec's window) exceeds
   Cell E's mean walk-forward Sharpe (same window) by ≥0.05, AND
   the best cell's mean walk-forward MaxDD does not exceed Cell E's
   by more than 1pp. **Gate verdict on the best cell must also be
   Pass.**

2. **OOS validation** — Re-run the best cell on a **held-out
   window** not used during BO tuning. The walk-forward CV uses
   `cell_e_30fold_2026_05_16.sexp` (2010-01-01 → 2026-04-30); the
   OOS window is either:
   - **Pre-2010 tail**: if Phase 1.4 Russell-3000 IWV scrape lands a
     2006-2010 universe, run the best cell on that.
   - **Forward window**: if not, hold out the last 4 folds (2024 +
     2025) of the 30-fold spec during BO, validate on those folds
     afterwards. This is an ~13% data-fraction holdout.
   PR-E specifies the holdout mechanism. **The BO spec sexp must
   explicitly mark the held-out folds.** Recommend a
   `(holdout_folds (k1 k2 k3 k4))` block in the Phase-3 spec.

3. **No-overfit hurdle** — the OOS Sharpe must be within 0.10 of
   the in-sample mean Sharpe. If the gap is >0.10, the optimizer
   over-fit and the result is REJECTED for production pinning.

## 7. PR-size estimate

5 stacked PRs, each ~200-400 LOC of non-test code:

### PR-A — scoring function + walk-forward aggregate consumer (~200 LOC)

Files:

| Path | Purpose |
|---|---|
| `trading/trading/backtest/tuner/bin/bayesian_runner_scoring.{ml,mli}` (new) | The `score_cell` function: input = parameters, walk_forward_spec, baseline_aggregate; output = float. |
| `trading/trading/backtest/tuner/bin/test/test_bayesian_runner_scoring.ml` (new) | Unit tests on the scoring formula with synthetic aggregates (MaxDD-hinge zero on improvement, hinge linear on excess, gate penalty at fail boundary). |
| `dev/plans/bayesian-multi-param-scoring-2026-05-16.md` (new, this PR's child) | Reuses §3 of this plan. |

Acceptance: ~12 unit tests on the scoring function; no walk-forward
or BO wiring yet. The function takes a pre-computed aggregate as
input — testable in isolation.

### PR-B — knob inventory + parameter space encoding (~300 LOC)

Files:

| Path | Purpose |
|---|---|
| `trading/test_data/walk_forward/cell_e_30fold_2026_05_16.sexp` (edit) | Add `holdout_folds` field (~5 LOC, new optional sexp tag). |
| `trading/test_data/tuner/bayesian-multi-param-2026-05-16.sexp` (new) | Phase-3 BO spec — the 11-knob surface curated in §2.1 (minus Track C). |
| `trading/trading/backtest/tuner/bin/bayesian_runner_spec.{ml,mli}` (edit) | Add `holdout_folds : int list option` field. |
| `trading/trading/backtest/tuner/bin/test/test_bayesian_runner_spec.ml` (edit) | Coverage of the new field. |

Acceptance: spec sexp parses without error; round-trip
`sexp_of_t |> t_of_sexp` test pins the new field.

### PR-C — walk-forward in-process integration (~400 LOC)

Files:

| Path | Purpose |
|---|---|
| `trading/trading/backtest/walk_forward/lib/walk_forward_executor.{ml,mli}` (new) | Pull per-fold execution out of `walk_forward_runner.ml` into a library entry point. Returns `aggregate`. |
| `trading/trading/backtest/walk_forward/bin/walk_forward_runner.ml` (edit) | Become a thin wrapper around `Walk_forward_executor`. |
| `trading/trading/backtest/tuner/bin/bayesian_runner_evaluator.{ml,mli}` (edit) | Rewrite to call `Walk_forward_executor` per BO iteration; consume aggregate; compute score via PR-A's `score_cell`. |
| `trading/trading/backtest/tuner/bin/test/test_bayesian_runner_evaluator.ml` (edit) | Pin the new walk-forward-based evaluation against a stub `Walk_forward_executor`. |

Acceptance: the existing walk-forward binary's output is unchanged
(byte-identical for the same spec). The new evaluator's output is
unit-tested against a stubbed executor returning a known aggregate.

### PR-D — int/Option encoding + GP length-scale tuning + early-stop (~250 LOC)

Files:

| Path | Purpose |
|---|---|
| `trading/trading/backtest/tuner/lib/bayesian_opt.{ml,mli}` (edit) | Add `length_scales` override to `create_config`; add `early_stop_config : { window : int; epsilon : float } option` field to `config`. |
| `trading/trading/backtest/tuner/bin/bayesian_runner_runner.ml` (edit) | Wire early-stop check into the iteration loop. |
| `trading/trading/backtest/tuner/bin/bayesian_runner_spec.{ml,mli}` (edit) | Encode Option-typed knobs via sentinel (e.g. `"max_sector_exposure_pct" (sentinel 0.10 0.35)`). |
| Tests | Unit + property tests for early-stop trigger; encoding round-trip. |

Acceptance: early-stop fires deterministically on a synthetic flat
sequence; sentinel encoding round-trips; existing BO tests unchanged
(default config = no early-stop).

### PR-E — end-to-end runner + result reporter + OOS holdout (~300 LOC)

Files:

| Path | Purpose |
|---|---|
| `trading/trading/backtest/tuner/bin/bayesian_runner.ml` (edit) | Use new evaluator + scoring; emit OOS validation report on completion. |
| `trading/trading/backtest/tuner/bin/bayesian_runner_oos_validator.{ml,mli}` (new) | Re-run the best cell on the holdout folds; emit `oos_report.md`. |
| `trading/trading/backtest/tuner/bin/test/test_bayesian_runner_oos_validator.ml` (new) | Stubbed-executor unit tests. |
| `dev/experiments/bayesian-multi-param-2026-05-16/hypothesis.md` (new) | The experiment's pre-registered hypothesis per the §"Experiment workflow" rule. |

Acceptance: the binary runs end-to-end on a smoke spec (2-3 BO
iterations, 2-fold walk-forward) under `dune runtest`. Production
sweep is a follow-up ops-session.

## 8. Open questions for the user

1. **Cell E baseline pinning.** The pinned 15y baseline in
   `goldens-sp500-historical/sp500-2010-2026.sexp` shows
   341.69%/806 trades/0.78 Sharpe/18.36% MaxDD (full Cell E,
   measured 2026-05-13 post-#1052/#1063). The Phase 2 walk-forward
   spec (`cell_e_30fold_2026_05_16.sexp`) uses this same scenario
   as `base_scenario`. **PR-A's `baseline_aggregate` will be the
   `aggregate.sexp` of running Cell E (empty overrides) through
   the 30-fold spec.** Confirm this is the intended baseline, or
   pin to a different historical Cell E measurement.

2. **GP library choice.** Per `.claude/rules/no-python.md`, porting
   a Python GP reference is forbidden. `Tuner.Bayesian_opt`'s
   current GP is minimal but functional (RBF + EI/UCB + Cholesky
   via `owl`). At 11-D the existing implementation is plausibly
   adequate; at 18-D it may not be. **Two paths:**

   - **Path A — extend the in-house GP** (PR-D's `length_scales`
     override + acquisition schedule). ~150 LOC.
   - **Path B — add a random-search-only mode**, treat the GP as
     optional. ~50 LOC.

   Recommend Path A for v1, Path B as a tested fallback. **Confirm.**

3. **Compute budget cadence.** A full BO run consumes 25-75 hours.
   At 11 knobs that's the "once-per-quarter" cadence; at 18 knobs
   it's "once-per-half-year". Confirm intended re-tuning frequency
   so PR-E sizes the smoke-spec correctly (smoke spec should mirror
   production but run in ≤15 min).

4. **Variant labelling for tracing.** When the BO converges to a
   cell, the cell's identity needs to round-trip into a re-runnable
   `cell-F.sexp` baseline. The current `best.sexp` writer in
   `bayesian_runner_runner.ml:87-92` produces a sexp of overrides
   but doesn't include the spec's baseline_label or BO seed.
   **Propose:** extend `best.sexp` to include `(spec_hash <sha256>)`
   and `(seed <int>)` for reproducibility. Confirm naming.

## 9. Risks

| Risk | Mitigation |
|---|---|
| **Overfitting to in-sample folds** | Walk-forward CV is the primary mitigation. Add the no-overfit hurdle (§6.3); reject best cells with >0.10 in-sample-vs-OOS gap. |
| **18-D search space too large for in-house GP** | PR-B starts at 11-D (omit Track C); PR-D adds length-scale tuning + early-stop; PR-D random-search fallback. |
| **Compute too expensive** | Early-stop after K=20 non-improving iterations. Smoke spec in `dune runtest` is ≤2 iterations. Production sweeps gated by ops-session, not CI. |
| **Gate verdict penalty destabilises GP** | Use finite penalty (+10.0 not +∞); test in PR-A that the GP fits a 50/50 mix of pass/fail observations. |
| **MaxDD baseline drifts as Cell E re-pins** | Read `baseline_aggregate` from `aggregate.sexp` at run-start, not from a hardcoded constant. PR-A reads dynamically. |
| **Knob redundancies (e.g. `weights.rs` + `weights.volume` sum constraint)** | The GP will trip over redundancies — flat posterior along the redundant axis is a known failure mode. **Mitigation:** the priorities doc says BO is one of three tracks (not the only one); a single failed BO run informs knob curation for the next. |
| **Stale baseline in pinned scenario sexp** | Bake the baseline run into PR-E's CI smoke (smaller window, ≤2 folds) so the baseline-from-aggregate read is exercised on every CI run. |
| **Worktree contamination (jj concurrent agents)** | Standard `.claude/rules/worktree-isolation.md` boilerplate for every PR. Plan-only PR has no contamination risk. |

## 10. Out of scope

- **Running the actual optimizer** — production BO sweep is an
  ops-session deliverable, not a PR.
- **Re-pinning goldens after the BO finds a new cell** — separate
  PR, separate session. Requires human sign-off per the
  "broader-first" pivot in
  `dev/notes/next-session-priorities-2026-05-15.md` §"What the user
  said".
- **Synthetic-data evaluation** — deferred per the priorities doc.
- **Multi-objective Pareto front (Sharpe + MaxDD as separate
  objectives, not a weighted sum)** — would require multi-output GP
  or NSGA-II; deferred indefinitely. v1's scalar loss is sufficient.
- **Short-side enable/disable as a BO knob** — depends on
  short-side-margin Phase 1 landing first. Defer.
- **Pre-2010 universe extension** — gated on Phase 1.4 IWV-scrape
  landing. The Phase-3 BO uses the 2010-2026 window only until
  then.

## 11. Acceptance gates (for the plan itself)

- [x] §1 cites file:line for current `bayesian_runner.exe` surface
- [x] §2 enumerates ~15-25 knobs (lands at 11 in PR-B v1, expandable)
- [x] §3 defines the loss formula explicitly
- [x] §4 references the production `aggregate.sexp` schema
- [x] §5 estimates wall-clock budget + flags the GP dimensionality
  concern
- [x] §6 defines in-sample + OOS validation
- [x] §7 splits into 5 PRs of ≤500 LOC each
- [x] §8 surfaces three open questions for the user
- [x] §9 enumerates failure modes
- [x] §10 declares out-of-scope items
- [x] No Python (per `.claude/rules/no-python.md`)
- [x] No core-module changes (qc-structural A1 / A3 PASS)
