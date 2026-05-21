;; V5 Bayesian production sweep — wider bounds + soft gate.
;;
;; V3 + V4 finding (2026-05-21, dev/logs/sweep-watch.log iters 1-48 V3,
;; iters 1-19 V4): BOTH sweeps' best composite_delta locked at 0.4943
;; across 19 (V3) and 9 (V4) GP iterations. Identical composite_delta
;; on the SAME bounds means: no cell in the V3/V4 tightened bound
;; surface passes the M-of-N walk-forward gate
;; (m=17/n=30, worst_delta=0.30 — see walk_forward_v2_baseline.sexp).
;; The gate-penalty value (10.0 vs 2.0) only affects the FLOOR — both
;; sweeps stuck on the same composite-loser cell.
;;
;; Diagnosis: V3's tightened bounds (post-V2 narrowing) excluded the
;; only region where Pass cells might exist. The V2 bounds at least
;; let BO explore wider; V3 → V4 narrowing made things worse.
;;
;; V5 changes (vs V3):
;; - max_position_pct_long: (0.04 0.15) → (0.02 0.20)
;;   Restores V2's full range. Concentrated (0.15-0.20) + diversified
;;   (0.02-0.04) regimes both re-eligible.
;; - max_long_exposure_pct: (0.45 0.85) → (0.30 0.95)
;;   Restores V2's full range. The 0.45 lower bound from V3 was set
;;   to "rule out V2's deep-underexposure region" — but V3's
;;   tightening apparently excluded the only Pass region too. Trust
;;   the BO to find the right level given more space.
;; - initial_stop_buffer: (1.00 1.05) → (0.95 1.10)
;;   Wider than V2's (0.97 1.10). Includes "tight stops" (<1.00) which
;;   reduce per-trade loss but may flush positions early.
;; - installed_stop_min_pct: (0.06 0.13) → (0.04 0.15)
;;   Restores V2's full range.
;;
;; V5 keeps from V4:
;; - gate_penalty_value: 2.0 (soft gate). Doesn't help find Pass cells
;;   on its own (V4 stuck on same composite_delta as V3) but PRESERVES
;;   signal scale so we can DETECT a Pass cell if one exists.
;; - Composite scorer (Sharpe 0.40 + Calmar 0.30 + MaxDrawdown -0.10).
;;
;; SAME: seed=2026, budget=60, initial_random=10, holdout (27 28 29 30),
;; walk_forward_v2_baseline.sexp.
;;
;; If V5 ALSO finds no Pass cell, the M-of-N gate criteria themselves
;; (worst_delta=0.30 too strict on 30 folds) are the cause — V6 would
;; need to relax the gate, not the bounds. The V5 result either
;; confirms or rejects the bounds-too-tight hypothesis cleanly.
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
