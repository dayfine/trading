;; 11-knob Bayesian production sweep — multi-parameter scaling (P4 in #1237).
;;
;; Hypothesis (per dev/plans/tuning-methodology-redesign-2026-05-22.md §5):
;; the 4-knob V3 surface plateaued; more dimensions might escape the
;; plateau. This sweep tests whether the additional 7 knobs (4 screener
;; stop/entry + 1 risk-per-trade + 2 screener weights) open new optima.
;;
;; Stopping rule (per #1237 §4):
;; if the first 15 BO iters all score within composite_delta 0.4±0.1
;; (i.e. same plateau range as V3-V7), kill the sweep. An 11-knob
;; plateau means the search-space-topology hypothesis is dead; need
;; strategy-mechanic changes (M8+).
;;
;; Knobs (same as trading/test_data/tuner/bayesian-multi-param-2026-05-16.sexp):
;;   Track A — entry / stop geometry (4)
;;   Track B — sizing / exposure (3)
;;   Track D — Cell E mechanics (2 int)
;;   Track E — screening cascade weights (2 int)
;;
;; Diffs vs the test-only fixture:
;; - objective:  Sharpe → Composite (matches V3 / #1196 PR-2 / promote_config gate)
;; - same seed (2026) + holdout_folds (27 28 29 30) as V3 for direct comparability
;;
;; Int-knob markers (per #1258 + #1261; see dev/notes/bayesian-11knob-int-knob-crash-2026-05-22.md):
;; the 4 int-typed knobs carry an explicit (int) marker on the binding,
;; which routes through int_keys and triggers Float.round_nearest in
;; Grid_search.cell_to_overrides before %.17g formatting. Without the
;; marker, BO emits continuous floats (e.g. 3.80…) and int_of_sexp crashes.
;;
;; Budget arithmetic (priorities-doc 2026-05-23 P0):
;; total_budget=60, initial_random=15 (~25% random per BO convention).
;; Per-iter ≈ 15 min (30 folds × ~30s wall ≈ 15 min at parallel=4).
;; Total wall ≈ 15h at parallel=4 — matches priorities doc 12-15h estimate.
((bounds
  (;; Track A — entry / stop geometry
   ("initial_stop_buffer" (0.5 2.0))
   ("screening_config.candidate_params.initial_stop_pct" (0.04 0.15))
   ("screening_config.candidate_params.installed_stop_min_pct" (0.0 0.12))
   ("screening_config.candidate_params.entry_buffer_pct" (0.0 0.02))
   ;; Track B — sizing / exposure
   ("portfolio_config.max_position_pct_long" (0.05 0.25))
   ("portfolio_config.max_long_exposure_pct" (0.50 0.95))
   ("portfolio_config.risk_per_trade_pct" (0.005 0.03))
   ;; Track D — Cell E mechanics (int knobs, rounded by cell_to_overrides)
   ("stage3_force_exit_config.hysteresis_weeks" (1.0 5.0) (int))
   ("laggard_rotation_config.hysteresis_weeks" (1.0 8.0) (int))
   ;; Track E — screening cascade weights (int)
   ("screening_config.weights.w_positive_rs" (5.0 40.0) (int))
   ("screening_config.weights.w_strong_volume" (5.0 40.0) (int))))
 (acquisition Expected_improvement)
 (initial_random 15)
 (total_budget 60)
 (seed (2026))
 (n_acquisition_candidates ())
 (objective
  (Composite
   ((SharpeRatio 0.40)
    (CalmarRatio 0.30)
    (MaxDrawdown -0.10))))
 (scenarios ())
 (holdout_folds (27 28 29 30)))
