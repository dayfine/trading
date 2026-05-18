# Bayesian production sweep — design + run plan (2026-05-18)

Plan-only doc. Builds on the already-shipped Bayesian Phase 3 stack
(#1126/#1132/#1136/#1143/#1145), the walk-forward CV harness
(#1100/#1111/#1116), and the delisted-aware composition rebuild
(#1184–#1190). Captures the design choices for the first PRODUCTION
sweep — what params to vary, what window to optimise over, what
fitness metric, what budget, and what gates "winning" must clear
before a config gets blessed.

## 0. Why now

The Bayesian tuner has been runnable since #914 (T-B CLI MERGED
2026-05-07). It hasn't been pointed at a PRODUCTION question because:

- The walk-forward CV harness only landed last week (#1116).
- The universe was selection-bias-contaminated until #1190.
- The "what's worth tuning" question wasn't sharp.

All three are now addressed. This doc proposes the first sweep that
should produce a config worth promoting to `live/current.sexp` per the
private-tuned-configs plan (`dev/plans/private-tuned-configs-repo-2026-05-18.md`
§4).

## 1. Key empirical findings that shape the design

From the random-universe sweeps (#1180, #1191) + delisted-aware
rebuild (#1190):

1. **Strategy mechanics are universe-invariant.** Trade count, win
   rate, and average holding days cluster tightly across all 12 cells
   measured to date (5 OLD random + 5 NEW random + 2 top-500
   variants). The strategy's filter/sizing/stops fire identically
   regardless of universe.

2. **Returns are universe-driven, not strategy-driven.** The +175% →
   +78% drop on `top-500-2019` after delisted-aware rebuild + the
   ±115pp σ across random samples both point to "what's in the
   universe" dominating "what the strategy decides".

3. **N=5 sweeps are sample-size-limited.** σ ≈ 100pp at N=5 means
   stderr ≈ 45pp. Stable distribution characterization needs N≥30.

**Implication for the production sweep**: focus on **portfolio sizing
+ risk-management knobs**, not screener knobs. Screener tuning is
unlikely to move the needle because (1) and (2) say the strategy
already filters consistently; (3) says we need enough samples to
detect drift if it exists.

## 2. Parameter set (the "production knob inventory")

Target: **7 parameters** (was 8 in the v1 draft; `min_cash_pct` removed
per qc-behavioral — `portfolio_risk.mli` lines 159-162 flag it as
"never wired into the entry walk's check_cash_and_deduct; retained for
sexp compat only"). Drawn from `Weinstein_strategy_config` per the
inventory in `dev/notes/tunable-parameters-inventory-2026-05-18.md`.

Two "default" columns distinguish the canonical Weinstein-config
default (`Portfolio_risk.default_config` etc.) from the empirical
Cell-E baseline. The §6 promote-gate compares against the **Cell-E
baseline**, not the canonical config default.

### Axis A — Position sizing (2 params)

| Param sexp-path                                      | Bounds            | Canonical default | Cell-E baseline |
|------------------------------------------------------|-------------------|-------------------|-----------------|
| `portfolio_config.max_position_pct_long`             | `[0.05, 0.20]`    | 0.30              | 0.14            |
| `portfolio_config.max_long_exposure_pct`             | `[0.50, 0.95]`    | 0.90              | 0.70            |

(`portfolio_config.min_cash_pct` removed — DEPRECATED per
`tunable-parameters-inventory-2026-05-18.md` line 143; sweeping it
is no-op since the entry walk never reads it.)

### Axis B — Stop placement (2 params)

| Param sexp-path                                                   | Bounds         | Canonical | Cell-E |
|-------------------------------------------------------------------|----------------|-----------|--------|
| `initial_stop_buffer`                                             | `[1.00, 1.10]` | 1.02      | 1.02   |
| `screening_config.candidate_params.installed_stop_min_pct`        | `[0.04, 0.15]` | 0.08      | 0.08   |

### Axis C — Cascade / rotation knobs (3 params)

| Param sexp-path                                | Bounds          | Canonical | Cell-E |
|------------------------------------------------|-----------------|-----------|--------|
| `stage3_force_exit_config.hysteresis_weeks`    | `[0, 4]` int    | 0         | 1      |
| `laggard_rotation_config.hysteresis_weeks`     | `[0, 4]` int    | 0         | 2      |
| `stage3_reentry_cooldown_weeks`                | `[0, 6]` int    | 0         | 0      |

### Out of scope for this sweep (justified deferrals)

- **Screener weights / score thresholds** — per Phase 3 PR-A: the
  cascade is already at "no-look-ahead ceiling" per #871. Sweeping
  weights yields cells that look discriminating but were validated
  empty post-bug-fix (#1051 → #1061). Defer until we have meaningful
  evidence the screener has more room to improve.
- **MA period / stage classifier** — Weinstein-book canonical
  (30-week WMA). Changing these is a strategy-change, not a tune.
- **Continuation buys + PI filter** — both flagged DEAD-END in the
  current state (`memory/project_continuation_combined_rejected.md`).
- **Universe knobs** — universe choice is upstream (see §3).

## 3. Universe + window

### Train universe — `goldens-sp500-historical/sp500-2010-2026.sexp`

- 510-symbol survivorship-aware SP500 universe (PR-A/B/C
  #803/#808/#809).
- 16y window: 2010-01-01 → 2026-04-30.
- The CANONICAL benchmark cell — already pinned in goldens-sp500-historical/.
- Survivor bias known + bounded; same-bias used across all comparison
  cells, so relative ranking of param sets is robust.

### Train / OOS split — 5-fold walk-forward

Use the existing walk-forward CV harness (#1116):

| Fold | Train window           | OOS window               |
|------|------------------------|--------------------------|
| 1    | 2010-01-01..2017-12-31 | 2018-01-01..2019-12-31   |
| 2    | 2010-01-01..2019-12-31 | 2020-01-01..2021-12-31   |
| 3    | 2010-01-01..2021-12-31 | 2022-01-01..2023-12-31   |
| 4    | 2010-01-01..2023-12-31 | 2024-01-01..2025-12-31   |
| 5    | 2010-01-01..2025-12-31 | 2026-01-01..2026-04-30   |

Each BO candidate is scored by the MEDIAN-fold OOS metric (per Phase 3
PR-A's `_aggregate_folds` design). The Median is robust against the
2020 COVID outlier (fold 2) and the 2022 bear (fold 3).

**Why not delisted-aware top-500-2019?** Per §1, the strategy is
universe-invariant for mechanics. The selection-bias correction from
#1190 changed the universe's INTRINSIC RETURN (not the strategy's
performance on it). A sweep's job is to find params that work across
windows; the universe should be FIXED for that comparison. The
sp500-2010-2026 cell is also more representative of what a live deploy
would track than a single-year composition snapshot.

## 4. Objective function

**Primary**: `Composite` weighted-sum, per Phase 3 PR-A's `Composite of (metric_type * float) list`. The sexp form uses PascalCase metric-type constructors (per `trading/trading/simulation/lib/types/metric_types.mli`; canonical fixture at `test_bayesian_runner_bin.ml:104`):

```sexp
(Composite
  ((SharpeRatio 0.40)
   (CalmarRatio 0.30)
   (CVaR95 -0.20)        ; negative = penalise tail loss
   (MaxDrawdown -0.10))) ; negative = penalise DD
```

Negative weights are supported by `Composite`'s sexp parser
(`test_grid_search.ml:148` pins `(MaxDrawdown, -0.1)` as a
test fixture).

Rationale: pure Sharpe over-weights small high-frequency wins. Pure
Calmar over-rewards low-DD curve-fits. The composite weights Sharpe
40% (consistency), Calmar 30% (risk-adjusted return), with explicit
penalties for tail risk (-20% on CVaR-95) and headline DD (-10%).
Tuning on this proxy gives a config that's robust to known failure
modes from #1180/#1191.

**Secondary metrics to log** (not scored but inspected post-hoc):
TotalReturnPct, NumTrades, WinRate, SortinoRatioAnnualized,
UlcerIndex, PositionTurnover. (Note: `force_liquidations_count`
is NOT a `metric_type` variant; if needed for analysis, read it
from the per-fold `actual.sexp` rather than the BO log.)

## 5. Budget + early stopping

- `total_budget`: **120 evaluations**
- `initial_random`: **20** (uniform-random initial sampling)
- `n_acquisition_candidates`: **1000** per BO iteration
- `acquisition`: **Expected_improvement** (defaults from Phase 3
  PR-D's length-scale priors)
- Early-stop: per Phase 3 PR-D, if best-so-far has not improved by
  >2% over 30 consecutive evaluations, terminate.

**Why 120?** Each eval runs 5 expanding-window folds. The folds total
~68 fold-years (8y train + (10 + 12 + 14 + 16 + 16) train + (2 + 2 + 2 + 2 + 0.33) OOS).
At ~5-10 min per fold-year on sp500-2010-2026 (current Cell-E wall
~5-15 min per 16y full run), each eval is ~30-60 min. 120 evals ≈
**~64-120 hr serial, ~32-40 hr at parallel=4** — wider than the
v1-draft "25 hr" claim. Plan for **24-48 hr wall**; if the actual
fold-time clocks at the high end, dial budget to 80.

4-D continuous + 3-D integer = 7 effective dimensions. Per PR-D's
prior, BO converges within ~30-50 evals on 4-D problems; 7-D should
converge by ~70-90 evals per `dev/plans/bayesian-multi-param-scaling-2026-05-16.md`
§5. The 120-eval budget gives headroom + tail-end exploration.

## 6. Acceptance gate

Promotion criteria (config qualifies for `live/current.sexp` blessing).
The first criterion is the composite objective (what BO optimised);
the remaining four are **hard floors** orthogonal to the composite —
a config that wins on composite but trips ANY single floor is
rejected. This is intentional: the composite can mask single-fold
catastrophes by averaging; the floors enforce per-fold sanity.

- **Median-fold composite score ≥ baseline Cell-E + 0.05** (5% relative improvement) — composite-axis gate
- **No fold loses to Cell-E by more than -0.10 composite** (no single-fold catastrophe) — composite-axis floor
- **OOS Sharpe ≥ 0.50** on every fold (strategy still risk-adjusted-positive everywhere) — orthogonal hard floor
- **MaxDD ≤ baseline Cell-E + 5pp** on every fold (no risk-budget blowout) — orthogonal hard floor
- **N_trades within 2x of baseline** (consistency with mechanic-invariant claim) — orthogonal hard floor

If the winner clears all 5 gates, promote per the private-tuned-configs
plan §4.

If only 1-2 gates clear, do NOT promote; keep Cell-E baseline. Treat
the run as a Bayesian convergence diagnostic and consider whether the
objective function needs revision.

**Cell-E baseline reference values** (from
`dev/notes/overnight-2026-05-10-results.md` — 15y sp500-2010-2026 with
overnight-winner config 0.14/0.70/h1/h2):

| Metric           | Cell-E (15y baseline) |
|------------------|-----------------------|
| Composite (4-term) | TBD — must measure as the v1 baseline before sweep |
| Median-fold composite | TBD                  |
| Sharpe (overall) | ~0.78                  |
| MaxDD (overall)  | ~18.4%                 |

Pre-sweep step 0 in §7 Phase A includes establishing these baseline
numbers by running the 5-fold split on Cell-E config first.

## 7. Run plan

### Phase A — Prep + smoke (next session, ~2 hr)

0. **Establish Cell-E baseline numbers** (§6 reference table). Run
   Cell-E config through the 5-fold split; compute composite per
   fold + median; record per-fold Sharpe/MaxDD/N_trades. These are
   the values §6's promote-gate compares against.
1. Author `bayesian_runner.exe` spec sexp at
   `dev/experiments/bayesian-production-sweep-2026-05-18/spec.sexp`
   per the parameters in §2 + objective in §4 + budget in §5. Use
   the PascalCase metric-type constructors (per §4).
2. Smoke run with `total_budget=5 initial_random=5` to verify the
   spec parses + the runner emits the 3 artefacts (bo_log.csv +
   best.sexp + convergence.md). **Check the smoke run actually
   varies the param values across the 5 evals** — confirms BO is
   reading the spec correctly (no silent-no-op overlay per the
   #1051 → #1061 hazard).
3. Verify each fold runs end-to-end in ~5-15 min via the walk-forward
   CV harness (PR #1100/#1116 path).

### Phase B — Full run (~24-30 hr wall)

Dispatch from CLI:
```sh
docker exec -d trading-1-dev bash -c '
  cd /workspaces/trading-1/trading && eval $(opam env) > /dev/null
  dune exec --no-build trading/backtest/tuner/bin/bayesian_runner.exe -- \
    --spec dev/experiments/bayesian-production-sweep-2026-05-18/spec.sexp \
    --out-dir dev/experiments/bayesian-production-sweep-2026-05-18/output \
    > dev/logs/bayesian-prod-sweep.log 2>&1
'
```

Monitor `bo_log.csv` rows + `best.sexp` for convergence. Bot dispatch
to a long-running cron OR run in a tmux session for the operator.

### Phase C — OOS validation + promote decision (~1 hr)

1. Read `best.sexp` from Phase B output.
2. Apply the 5 gates from §6 to the median-fold metrics.
3. If all clear: create private repo per the private-tuned-configs
   plan §4 (`dayfine/trading-configs-private` if not extant) and
   commit the winner as `configs/2026-05-XX-bayesian-prod-v1/config.sexp`.
4. If gates fail: write a follow-up `dev/notes/bayesian-prod-v1-result-2026-05-XX.md`
   capturing why + revised hypothesis for v2.

## 8. Open dependencies

- **`-include-delisted` symbol_types.sexp** (P3, #1186) is needed only
  if the run uses a delisted-aware universe. Per §3 we use
  sp500-2010-2026 (survivor-aware, no delisted-aware refresh
  required), so this dependency is satisfied without P5/P7.
- **P5 (delisted sectors backfill)** — NOT a dependency for this
  sweep. Would matter only if we pointed at a delisted-aware
  universe.
- **P7 (N=30+ random universe samples)** — NOT a dependency. Useful
  later to characterise the random-universe distribution against
  which the sweep winner is benchmarked, but the sweep itself doesn't
  need it.

## 9. Risks

| Risk                                        | Mitigation |
|---------------------------------------------|------------|
| BO converges to local optimum                | Phase 3 PR-D's length-scale prior + 1000-candidate acquisition argmax. |
| Single fold dominates the composite          | Median aggregation; per-fold floors (§6 gate 2). |
| Multi-day wall time interrupted              | bo_log.csv is append-only; can resume from last row via a follow-up `--resume` flag (not yet implemented; ~1 LOC change to `bayesian_runner_runner`). |
| Winner overfits to 2010-2026 specific events | Walk-forward CV with 5 folds + OOS gate (§6). |
| 8-D continuous + 3-D integer mix             | Phase 3 PR-D's integer-rounding in `Bayesian_opt.suggest_next` (already shipped). |
| Quota / API limits                           | None — the sweep reads cached bars; no live HTTP. |

## 10. Out of scope (explicit)

- **Universe tuning** — fixed at sp500-2010-2026; future sweeps may
  vary universe choice but not this run.
- **Strategy-mode tuning** (short-side on/off, continuation on/off) —
  defer until composite-sizing optimum is found.
- **Walk-forward fold count** — fixed at 5; expanding-window
  alternative is a follow-up if the median-fold result is unstable.
- **ML training** (M7.1) — separate track; not a Bayesian sweep
  target.

## 11. Acceptance gates (for this plan itself)

This plan is APPROVED when:

1. The 8 parameters in §2 are confirmed reasonable by review (no
   off-the-shelf "this is broken on prior axis tests" objections).
2. The 5-fold split in §3 is acknowledged as the canonical
   walk-forward split for production-grade sweeps (no objection that
   2026-04-30 is too short for fold 5).
3. The composite objective in §4 weights are accepted (no objection
   to penalising CVaR/DD at the stated -20% / -10% magnitudes).
4. The 5 gates in §6 are accepted as the promote criterion.
5. The ~24-30 hr wall + 25 hr CPU budget at parallel=4 is acceptable.

If any gate fails, revise the plan and re-circulate. If all pass,
proceed to Phase A.

## 12. Companion docs

- `dev/plans/bayesian-opt-2026-05-03.md` — original T-B (Bayesian
  opt lib + CLI) design
- `dev/plans/bayesian-multi-param-scaling-2026-05-16.md` — Phase 3
  5-PR stack design
- `dev/notes/tunable-parameters-inventory-2026-05-18.md` — full knob
  inventory the param set in §2 draws from
- `dev/plans/private-tuned-configs-repo-2026-05-18.md` — promote
  protocol for the winning config
- `dev/notes/delisted-aware-p4-result-2026-05-18.md` — universe
  selection rationale that grounds §3
- `dev/notes/random-universe-sweep-v2-p6-2026-05-18.md` — N=5
  caveat that grounds §1.3 and the "secondary metrics to log" choice
