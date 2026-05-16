;; Phase-3 Bayesian-optimisation spec — 11-knob multi-parameter scaling
;; per dev/plans/bayesian-multi-param-scaling-2026-05-16.md (PR-B).
;;
;; Knob curation: §2.1 of the plan enumerates an 18-knob surface
;; (Tracks A/B/C/D/E); PR-B drops Track C (stage classifier, mostly
;; near-fixed per memory/project_m5-5-tuning-exhausted.md) and further
;; trims Tracks A/B/D/E to 11 high-confidence dimensions to stay under
;; the in-house GP's "≤10 dimensions" effective ceiling (per
;; Tuner.Bayesian_opt.mli + plan §5.2). The Option-typed knobs from
;; §2.5 (e.g. max_sector_exposure_pct, min_score_override) and binary
;; feature flags (§Track D) are deferred to PR-D.
;;
;; Final 11-knob breakdown:
;;   Track A — entry / stop geometry (4)
;;     initial_stop_buffer                  (top-level, §2.1 known sensitive)
;;     candidate_params.initial_stop_pct    (§2.1 known sensitive)
;;     candidate_params.installed_stop_min_pct (§2.1 axis-1 winner @ 0.08)
;;     candidate_params.entry_buffer_pct    (§2.1 plausible)
;;   Track B — sizing / exposure (3)
;;     max_position_pct_long                (§2.1 known sensitive — PR #855)
;;     max_long_exposure_pct                (§2.1 known sensitive)
;;     risk_per_trade_pct                   (§2.1 plausible)
;;   Track D — Cell E mechanics (2)
;;     stage3_force_exit_config.hysteresis_weeks  (§2.1 known sensitive — Cell E h=1)
;;     laggard_rotation_config.hysteresis_weeks   (§2.1 known sensitive — Cell E h=2)
;;   Track E — screening cascade (2)
;;     screening_config.weights.w_positive_rs   (int — rounded by cell_to_overrides)
;;     screening_config.weights.w_strong_volume (int — rounded by cell_to_overrides)
;;
;; Budget arithmetic (plan §5.1): each BO iteration = one
;; walk-forward run = 30 folds; per-fold ≈ 30s wall ⇒ ≈15 min per
;; iteration. total_budget=100 ⇒ ≈25 hours; aligns with the
;; priorities doc's "50-150 hour" cadence at 100-300 iterations.
;;
;; initial_random=25 ≈ 2.3× knob count (plan §5.3 suggests 10× ideal
;; but trims aggressively to leave compute headroom for GP-driven
;; phase). seed=2026 is the year — reproducible without colliding
;; with any other pinned seed in the harness.
;;
;; The scenarios list is empty here because Phase 3's evaluator runs
;; the walk-forward harness (PR-C) instead of per-scenario backtests;
;; the field is retained for backward compatibility with the parser
;; (PR-B does not modify Bayesian_runner_evaluator). The empty list
;; will become a single placeholder scenario in PR-C once the
;; walk-forward-in-process integration lands.
;;
;; holdout_folds: (27 28 29 30) — last 4 folds of the 30-fold
;; cell_e_30fold_2026_05_16 spec (~13% holdout per plan §6.2).
;; PR-B only PINS the parsed shape; PR-C will thread the list into
;; the walk-forward executor's fold filter; PR-E will re-run the
;; best cell on these folds as OOS validation.
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
   ;; Track D — Cell E mechanics (int knobs, rounded at evaluator
   ;; boundary; plan §2.5 — grid_search.mli:56-65 already encodes
   ;; integer-valued floats correctly)
   ("stage3_force_exit_config.hysteresis_weeks" (1.0 5.0))
   ("laggard_rotation_config.hysteresis_weeks" (1.0 8.0))
   ;; Track E — screening cascade weights (int)
   ("screening_config.weights.w_positive_rs" (5.0 40.0))
   ("screening_config.weights.w_strong_volume" (5.0 40.0))))
 (acquisition Expected_improvement)
 (initial_random 25)
 (total_budget 100)
 (seed (2026))
 (n_acquisition_candidates ())
 (objective Sharpe)
 (scenarios ())
 (holdout_folds (27 28 29 30)))
