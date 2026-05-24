;; v7 Bayesian production sweep — first run on the 1998-2026 28-fold + top-3000
;; (delisted-aware) fixture from M4 T4.1 of
;; `dev/plans/tuning-research-driven-program-v2-2026-05-25.md`.
;;
;; Knob set is IDENTICAL to the v1 11-knob spec
;; (`dev/experiments/bayesian-production-sweep-2026-05-18/spec_prod_11knob_v1.sexp`)
;; so the only experimental delta vs v1-v6 is the *universe + window*:
;;   v1-v6: sp500-2010-2026 (16y, ~510 symbols at any point)
;;   v7:    top-3000-1998-2026 (28y, ~3000 symbols, delisted-enriched)
;;
;; Why this is "v7" not "v6.1":
;; - 28y vs 16y window — strategy edge over a longer macro span tests
;;   horizon-robustness directly (delta #2 of plan v2).
;; - 6× wider universe — addresses both survivor bias (delisted carried) AND
;;   selection-set scale (top-3000 vs SP500's ~500).
;; - Cell E baseline DROPPED (delta #4 of plan v2). The score path falls back
;;   to a baseline-free composite of (Sharpe, Calmar, MaxDD) — exactly what
;;   v1's Composite objective already computes when baseline_aggregate is the
;;   universal-zero record. The orchestrator launch sequence builds that
;;   zero-baseline aggregate on the fly (no Cell E sanity-run required).
;;
;; Knob set (identical to v1, see that file for per-track rationale):
;;   Track A — entry / stop geometry (4)
;;   Track B — sizing / exposure (3)
;;   Track D — Cell E mechanics (2 int)
;;   Track E — screening cascade weights (2 int)
;;
;; Budget arithmetic:
;;   total_budget=60, initial_random=15. Per-iter cost is higher than v1-v6
;;   because the per-fold backtest now spans ~3000 symbols × 28 folds:
;;   ~30 min per iter at parallel=4 ⇒ ~30h wall total. Disk-watcher (PR-C)
;;   provides the t>0 safety net; launch_sweep.sh (PR-A) the t=0 gate.
;;
;; Stopping rule mirrors v1: if first 15 BO iters all score within
;; composite_delta 0.4 ± 0.1, kill the sweep — the 11-knob plateau
;; conclusion from v1-v6 would have replicated on the wider universe + window
;; rather than being the search-space-topology problem.
;;
;; Holdout folds: 25-28 (last 4 of 28). Same proportion (~14%) as v1's 27-30
;; of 30.
;;
;; Int-knob markers retained (per `dev/notes/bayesian-11knob-int-knob-crash-2026-05-22.md`).
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
 (holdout_folds (25 26 27 28))
 (gate_penalty_value 2.0))
