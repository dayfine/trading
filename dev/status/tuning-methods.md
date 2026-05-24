# Status: tuning-methods

## Last updated: 2026-05-24

## Status
PLANNED

Methodology comparison track: random / TPE / Hyperband / CMA-ES /
learned-surrogate vs the existing GP-EI Bayesian Optimization. Opened
2026-05-24 after the 11-knob BO sweep plateau verdict.

Plan: `dev/plans/tuning-methods-track-2026-05-24.md`.

## Interface stable

N/A

(No code surface yet — track is design-only at this point.)

## Ownership

feat-backtest

## Open work

- [ ] **Step 0 — random-search baseline at budget=60.** Spec already
  exists at `dev/experiments/bayesian-production-sweep-2026-05-18/spec_prod_11knob_random_v1.sexp`.
  ~0 LOC change; ~12h sweep wall. Blocked on safe-sweep infrastructure
  (`dev/plans/safe-sweep-infrastructure-2026-05-24.md`).
- [ ] **Step 1 — TPE port.** ~200 LOC + tests.
- [ ] **Step 2 — Hyperband / Successive Halving.** ~150 LOC + tests.
- [ ] **Step 3 — CMA-ES** (deferred until step 2 verdict).
- [ ] **Step 4 — learned-surrogate (stretch).**

## Blocked on

- `dev/plans/safe-sweep-infrastructure-2026-05-24.md` — must land
  bind-mounted `/tmp/sweeps/` + disk-watcher BEFORE any sweep step
  here can launch safely. Today's session (2026-05-23/24) lost
  ~16h of sweep wall-time to disk-fill cascades.

## Next Steps

1. Land safe-sweep infrastructure (separate dispatch).
2. Launch step 0 (random-search baseline). One sweep per session,
   close monitoring.
3. Per-step verdict gating per the plan doc.

## Follow-ups

None yet — track just opened.

## Notes

- All steps reuse the same evaluator surface:
  `bayesian_runner.exe` → `walk_forward_executor` → `panel_runner` chain.
  Different methodologies plug in at the "next-iter-suggester" layer
  only.
- Same fixture for all comparisons:
  `trading/test_data/walk_forward/cell_e_30fold_2026_05_16.sexp` (30
  rolling folds, 26 in-sample + 4 holdout).
- Same 11 knobs, same composite objective, same seed (2026), same
  budget (60) — so cross-method comparison is apples-to-apples.
