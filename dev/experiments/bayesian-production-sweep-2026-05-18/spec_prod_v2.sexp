;; V2 Bayesian production sweep — widened bounds after v1 result.
;;
;; V1 (spec_prod.sexp) result (dev/notes/bayesian-prod-v1-result-2026-05-20.md):
;; winner (iter 26) clustered 3 of 4 knobs at the LOWER bound — BO wants below
;; these bounds. Headline OK (+0.24 mean Sharpe) but rejected on plan §6
;; axes 2 + 3 (6 folds worse by >0.10 Sharpe, fold-029 OOS = -0.855).
;;
;; V2 changes:
;; - widen the 3 lower-bound-converged knobs DOWN to give BO room to search.
;; - keep `installed_stop_min_pct` bound unchanged (winner at upper-mid, not
;;   at edge).
;; - same seed for cross-version comparability.
;; - same budget=60 / initial_random=10.
;; - same holdout folds 27-30.
;;
;; Plan #1196 Composite scorer is the load-bearing follow-up for axis 2
;; (no-fold-left-behind) but is still draft; v2 ships against the shipped
;; single-term Sharpe scorer.
((bounds
  (;; Axis A — position sizing (2): WIDENED DOWN
   ("portfolio_config.max_position_pct_long" (0.02 0.20))
   ("portfolio_config.max_long_exposure_pct" (0.30 0.95))
   ;; Axis B — stop placement (2): one widened DOWN, one unchanged
   ("initial_stop_buffer" (0.97 1.10))
   ("screening_config.candidate_params.installed_stop_min_pct" (0.04 0.15))))
 (acquisition Expected_improvement)
 (initial_random 10)
 (total_budget 60)
 (seed (2026))
 (n_acquisition_candidates ())
 (objective Sharpe)
 (scenarios ())
 (holdout_folds (27 28 29 30)))
