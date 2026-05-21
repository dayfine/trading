;; V4 Bayesian production sweep — soft gate penalty (10.0 → 2.0).
;;
;; V3 (spec_prod_v3.sexp, in-flight at the time of writing) is on the
;; same trajectory as V2: first 7 random iters all scored in
;; [-9.87, -9.51] — spread 0.36 in a 4-D space. Diagnosis: the
;; bayesian_runner_scoring._gate_penalty_value (10.0) dominates the
;; Composite metric signal (typical magnitude 0.1-0.5), so every
;; gate-failing cell scores near -10 regardless of differentiating
;; metric quality. The GP has no gradient to climb.
;;
;; V4 changes:
;; - `gate_penalty_value 2.0` — softens the gate-fail penalty 5x.
;;   With Composite weights {Sharpe 0.4, Calmar 0.3, MaxDD -0.1} the
;;   metric signal across the bound surface is ~0.2-1.0. A 2.0 penalty
;;   keeps the gate informative as a TIEBREAKER (Pass cells outscore
;;   Fail cells by 2 units, more than any composite-only delta) but
;;   does not flatten the search surface.
;; - SAME bounds as V3 (already-tightened post-V2): the search-surface
;;   axes don't change; only the scorer hyperparameter does. This is a
;;   controlled ablation — V3 vs V4 isolates the gate-penalty effect.
;; - SAME budget=60, initial_random=10, seed=2026 → directly comparable.
;; - SAME holdout (27 28 29 30) + walk_forward_v2_baseline.sexp.
;;
;; If V4 succeeds where V3 fails, the gate-penalty hypothesis from
;; V2 → V3 → V4 is confirmed empirically; main can adopt 2.0 as the
;; default for future Composite-objective sweeps.
;;
;; If V4 also fails (BO never improves past random phase), the
;; flat-surface failure mode has a different root cause and V5 needs
;; a different intervention (proportional penalty? bound tightening?
;; objective redesign?).
((bounds
  (("portfolio_config.max_position_pct_long" (0.04 0.15))
   ("portfolio_config.max_long_exposure_pct" (0.45 0.85))
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
    (MaxDrawdown -0.10))))
 (scenarios ())
 (holdout_folds (27 28 29 30))
 (gate_penalty_value 2.0))
