;; V3 smoke spec — total_budget=2 (vs V3's 60) for end-to-end
;; verification before the full ~11-12h sweep. Identical to
;; spec_prod_v3.sexp on every other field.
;;
;; Smoke-then-resume workflow:
;; 1. Run this spec → produces bo_checkpoint.sexp + first 2 evals
;;    under output-v3-parallel4/.
;; 2. Verify bo_log.csv has 2 rows + the params differ across rows
;;    (no silent-no-op overlay per #1051 → #1061 hazard).
;; 3. Run spec_prod_v3.sexp against the SAME out_dir — checkpoint's
;;    spec-equality check excludes total_budget so the budget=60
;;    spec resumes from the 2 smoke iters and runs 58 more. Net:
;;    smoke evals become the first 2 evals of the production run.
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
