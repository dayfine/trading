# Tuning-methods track — methodology comparison (2026-05-24)

New track for systematically comparing hyperparameter-search
methodologies against the existing GP-EI Bayesian Optimization. Opened
2026-05-24 in response to the 11-knob plateau verdict
(`dev/notes/11knob-plateau-verdict-2026-05-24.md`).

## Why

V3 (4-knob BO), V8 (random-restart BO), and now v4 (11-knob BO) all
plateau at the same composite score band. Adding more knobs (V3 → v4)
did NOT escape. Broadening the universe also did NOT help (full-pool
2019 baseline — Sharpe degrades with broader pool).

Two unanswered methodology questions remain:

1. **Does the BO surrogate (GP + Expected Improvement) add value over
   uniform random sampling at this budget on this surface?** Today we
   tried to answer this with a random-search v5 baseline but disk-fill
   killed it after 4 iters.
2. **If the bind is the surrogate (not the surface), does a different
   surrogate find better optima?** TPE handles int knobs natively
   (4 of our 11 are int — int_keys plumbing landed via #1258 + #1261
   + #1268). Hyperband can ~3× sample efficiency via early-stop pruning.

## Track structure

| Step | Methodology | Expected outcome | Effort |
|---|---|---|---|
| **0** | **Random-search baseline at budget=60** (re-run of today's v5; spec already exists at `spec_prod_11knob_random_v1.sexp`) | Reveals whether BO adds value. If random best ≥ -9.6516 (BO best), surrogate isn't helping. | ~0 LOC (spec done); ~12h wall (1 sweep) |
| **1** | **TPE port** — Tree-structured Parzen Estimator. Native int / discrete support; often outperforms GP in mixed-type spaces | If TPE beats BO-EI: surrogate matters; GP isn't right tool for 11-D mixed | ~200 LOC + tests; ~12h sweep wall |
| **2** | **Hyperband / Successive Halving** — for each candidate config, evaluate on N folds (e.g. 5 of 26); if score < median, abort; else continue on remaining. Cuts ~70% of folds for bad configs | Decouples wall-time from depth-of-evaluation; if budget can support 3× iters, surface explored more thoroughly | ~150 LOC + tests; same ~12h wall but ~3× more configs evaluated |
| **3** | **CMA-ES** — gradient-free black-box, robust to multimodality | Comparison point for "smooth-but-flat" hypothesis | ~200-300 LOC; ~12h sweep |
| **4** | **(stretch)** XGBoost / RF surrogate trained on all historical V1-V7-V8-v4 samples | If a learned surrogate predicts good configs from accumulated data, suggests the surface is learnable with enough samples; unusual + high-risk experiment | ~300 LOC + data pipeline; few-hour wall |

Each method evaluated against the SAME walk-forward fixture
(`cell_e_30fold_2026_05_16.sexp`), SAME 11 knobs, SAME composite
objective, SAME holdout folds, SAME budget=60.

## Prerequisite — safe-sweep infra MUST land first

See `dev/plans/safe-sweep-infrastructure-2026-05-24.md`. The track
cannot begin until at least:

- [ ] `/tmp/sweeps/` is bind-mounted to host (so a 12h sweep can't
  refill Docker.raw and crash the daemon).
- [ ] Disk-watcher script in place (so any runaway is caught early).
- [ ] Operational rules for "don't dispatch QC while sweep is running"
  documented.

Steps 0–4 above will each take 12h+ of wall-time inside docker; we
cannot afford another disk-fill cascade like today's.

## Sequencing

**Session N+1 (next session):** land safe-sweep infra. Launch step 0
(random baseline). One sweep per session, monitor closely.

**Session N+2:** harvest step 0 result. Make verdict call:
- Random best < BO best by > 0.1 composite: surrogate matters; proceed to step 1 (TPE).
- Random ~= BO: surrogate isn't helping; consider Hyperband (step 2) instead — its sample-efficiency win is independent of surrogate value.
- Random > BO: BO is actively over-exploiting; step 1 TPE is the most promising follow-up.

**Sessions N+3 to N+6:** step 1 / 2 / 3, one per session as bandwidth allows.

**Decision gate at end of step 2 (Hyperband):** if no methodology has
beaten the v4 BO plateau by then, the conclusion is that **the surface
itself is genuinely flat** at this resolution. At that point the
strategic question becomes "what changes the surface?" — likely the
component-decomposition objective (priorities-doc P1) or entry-timing
mechanic. Don't proceed to step 3 (CMA-ES) or step 4 (XGBoost) without
a specific reason.

## Acceptance per step

For each methodology:

1. New runner binary (or flag on existing runner) implementing the
   methodology against the same `bayesian_runner.exe` evaluator surface.
2. Unit tests pinning the methodology's per-iter logic.
3. Sweep launched against the canonical fixture.
4. Result writeup: best score, score distribution, comparison vs BO-EI
   baseline (-9.6516 at iter 34).
5. Verdict line in this plan doc: which step is the next priority based
   on observation.

## References

- `dev/notes/11knob-plateau-verdict-2026-05-24.md` — what triggered this track
- `dev/plans/safe-sweep-infrastructure-2026-05-24.md` — prerequisite
- `dev/experiments/bayesian-production-sweep-2026-05-18/spec_prod_11knob_random_v1.sexp` — step 0 spec (ready)
- `trading/trading/backtest/tuner/bin/bayesian_runner.exe` — existing BO-EI runner; the methodology-comparison binaries should share its evaluator + scenario plumbing
- `memory/project_strategic_pivot_broader_first.md` — original 2026-05-15 pivot context
- `memory/feedback_strategy_mechanic_changes_too_explorative.md` — boundary: don't propose strategy-mechanic changes from this track
