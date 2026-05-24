# Status: tuning-methods

## Last updated: 2026-05-24

## Status
PENDING

Methodology comparison track: random / TPE / Hyperband / CMA-ES /
learned-surrogate vs the existing GP-EI Bayesian Optimization. Opened
2026-05-24 after the 11-knob BO sweep plateau verdict.

**Update 2026-05-24 PM:** Step 0 (random-search baseline) COMPLETE at
iter 29 / 60 (terminated early; verdict locked). Result: random
matches BO at -9.6516. Surface is the bind, not the surrogate. **Steps
1-3 (TPE / Hyperband / CMA-ES) DEMOTED** — no longer P0 since
surrogate-change can't help a flat surface. Track posture: open but
not priority. Reopen if component-decomposition objective surfaces a
component where surrogate-change becomes relevant.

Plan: `dev/plans/tuning-methods-track-2026-05-24.md`. Verdict doc:
`dev/notes/v6-random-baseline-verdict-2026-05-24.md`.

## Interface stable

N/A

(No code surface yet — track is design-only at this point.)

## Ownership

feat-backtest

## Open work

- [x] **Step 0 — random-search baseline at budget=60.** DONE 2026-05-24
  (v6 sweep terminated early at iter 29; verdict matches v4 BO at
  -9.6516). See `dev/notes/v6-random-baseline-verdict-2026-05-24.md`.
- [ ] **Step 1 — TPE port.** ~200 LOC + tests. **DEMOTED** — surface is
  the bind, not the surrogate; TPE unlikely to help.
- [ ] **Step 2 — Hyperband / Successive Halving.** ~150 LOC + tests.
  **DEMOTED** — same reasoning.
- [ ] **Step 3 — CMA-ES** (deferred until step 2 verdict). **DEMOTED**.
- [ ] **Step 4 — learned-surrogate (stretch).** **DEMOTED**.

All non-step-0 work demoted by the v6 verdict. Reopen contingent on
the component-decomposition objective surfacing a knob-axis where
a different surrogate could resolve signal that GP-EI missed.

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
