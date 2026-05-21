;; V3 smoke spec — STANDALONE end-to-end verification of the V3
;; search surface before the full ~11-12h sweep. Differs from
;; spec_prod_v3.sexp on two fields:
;;   - total_budget: 2 (vs 60)
;;   - initial_random: 2 (vs 10)
;; Bounds, objective, acquisition, seed, and holdout_folds are
;; byte-identical to V3, so a 2-eval smoke confirms the BO walks the
;; correct (bounds × objective) surface without committing to the
;; full wall.
;;
;; Smoke workflow (STANDALONE — do NOT chain into the V3 production run):
;; 1. Run this spec against a FRESH out_dir, e.g.
;;    `output-v3-smoke/`.
;; 2. Verify bo_log.csv has 2 rows + the param values differ across
;;    rows (no silent-no-op overlay per the #1051 → #1061 hazard).
;; 3. Inspect best.sexp + convergence.md for shape correctness.
;; 4. Discard the smoke out_dir. The production run uses
;;    spec_prod_v3.sexp against a separate out_dir
;;    (`output-v3-parallel4/`) — it cannot RESUME from the smoke
;;    checkpoint because `initial_random` differs and the
;;    runner's `_spec_for_resume_check` only excludes `total_budget`
;;    (see `bayesian_runner_runner.ml`); resuming a smoke checkpoint
;;    with the V3 spec would raise `Failure "checkpoint spec
;;    mismatch"`.
((bounds
  (("portfolio_config.max_position_pct_long" (0.04 0.15))
   ("portfolio_config.max_long_exposure_pct" (0.45 0.85))
   ("initial_stop_buffer" (1.00 1.05))
   ("screening_config.candidate_params.installed_stop_min_pct" (0.06 0.13))))
 (acquisition Expected_improvement)
 (initial_random 2)
 (total_budget 2)
 (seed (2026))
 (n_acquisition_candidates ())
 (objective
  (Composite
   ((SharpeRatio 0.40)
    (CalmarRatio 0.30)
    (MaxDrawdown -0.10))))
 (scenarios ())
 (holdout_folds (27 28 29 30)))
