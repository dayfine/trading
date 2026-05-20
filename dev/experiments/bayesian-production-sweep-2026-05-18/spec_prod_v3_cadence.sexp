;; V3 cadence-aware sweep — adds AvgHoldingDays cadence term to the
;; V3-baseline Composite. See spec_prod_v3.sexp for the baseline +
;; rationale; this spec differs only in the (objective ...) clause.
;;
;; P5 cadence-scorer infra landed in #1220 (design B symmetric);
;; AvgHoldingDays is a quantity-of-holding-period term that tests
;; whether longer holding periods improve risk-adjusted return on
;; this strategy.
;;
;; PRE-REQUISITE: the cell-E baseline aggregate MUST be regenerated
;; against the post-#1220 build before launching this sweep. V1/V2
;; baseline aggregates predate #1220 and have
;; `(avg_holding_days NaN)` in `variant_stability` — passing them
;; through the AvgHoldingDays scoring term would NaN-poison every
;; cell. Run cell-E config through `walk_forward_runner.exe` against
;; the post-#1220 build, save aggregate.sexp at
;; `dev/experiments/bayesian-production-sweep-2026-05-18/v3-cell-e-baseline/`,
;; verify the new field is finite, THEN launch this sweep.
;;
;; Same bounds + budget + seed as V3 baseline so the two sweeps are
;; directly comparable on the same surface.
((bounds
  (;; Axis A — position sizing (2)
   ("portfolio_config.max_position_pct_long" (0.04 0.15))
   ("portfolio_config.max_long_exposure_pct" (0.45 0.85))
   ;; Axis B — stop placement (2)
   ("initial_stop_buffer" (1.00 1.05))
   ("screening_config.candidate_params.installed_stop_min_pct" (0.06 0.13))))
 (acquisition Expected_improvement)
 (initial_random 10)
 (total_budget 60)
 (seed (2026))
 (n_acquisition_candidates ())
 (objective
  (Composite
   ((SharpeRatio 0.40)
    (CalmarRatio 0.30)
    (MaxDrawdown -0.10)
    (AvgHoldingDays 0.10))))
 (scenarios ())
 (holdout_folds (27 28 29 30)))
