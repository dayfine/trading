;; V6 Bayesian production sweep — relaxed M-of-N gate (worst_delta 0.30 → 0.50).
;;
;; V3 + V4 + V5 finding (sweep-watch.log + v5-watch.log): all three
;; sweeps' best composite_delta locked at 0.4-0.5 with the BO unable
;; to improve past iter-1's random sample. Hypothesis chain:
;; - V3 → V4: did soft penalty help? NO (same composite_delta).
;; - V3 → V5: did wider bounds help? NO (same composite_delta).
;; - V6: does relaxing the M-of-N gate help? — this sweep tests it.
;;
;; V6 changes ONLY the walk-forward spec's worst_delta floor:
;; 0.30 → 0.50 (see walk_forward_v6_baseline.sexp). The BO spec
;; (bounds + objective + budget + seed) is byte-identical to V5.
;; Controlled ablation: only the gate criteria differ.
;;
;; If V6 surfaces a non-floor cell (composite_delta > 0.5 in BO
;; score), the gate-too-strict hypothesis is confirmed. If V6 also
;; stuck near 0.4, the binding constraint is deeper — possibly the
;; strategy mechanics themselves at this universe, or the worst-fold
;; threshold needs even more relaxation.
;;
;; SAME as V5: bounds (V2's wider range), Composite objective
;; (Sharpe 0.40 + Calmar 0.30 + MaxDrawdown -0.10), gate_penalty=2.0
;; soft, seed=2026, budget=60, initial_random=10, holdout (27 28 29 30).
((bounds
  (("portfolio_config.max_position_pct_long" (0.02 0.20))
   ("portfolio_config.max_long_exposure_pct" (0.30 0.95))
   ("initial_stop_buffer" (0.95 1.10))
   ("screening_config.candidate_params.installed_stop_min_pct" (0.04 0.15))))
 (acquisition Expected_improvement)
 (initial_random 10)
 (total_budget 60)
 (seed (2026))
 (n_acquisition_candidates ())
 (objective
  (Composite
   ((SharpeRatio 0.40)
    (CalmarRatio 0.30)
    (MaxDrawdown -0.10))))
 (scenarios ())
 (holdout_folds (27 28 29 30))
 (gate_penalty_value 2.0))
