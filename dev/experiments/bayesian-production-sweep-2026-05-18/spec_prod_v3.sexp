;; V3 Bayesian production sweep — Composite scorer + tighter bounds.
;;
;; V2 (spec_prod_v2.sexp) result — REJECT
;; (dev/notes/bayesian-prod-v2-result-2026-05-21.md):
;; BO never improved past iter-1; -10×gate_fail penalty flattened the
;; search surface. Iter-1 random sample won at exposure=0.330 (too low)
;; + initial_stop_buffer=1.072 (too wide) — caused fold-017 MaxDD
;; regression + fold-029 OOS Sharpe = -0.996.
;;
;; V3 changes:
;; - Composite scorer (Sharpe 0.40 + Calmar 0.30 + MaxDrawdown -0.10),
;;   per #1196 PR-2: replaces the single-term Sharpe scorer that V1/V2
;;   used. Multi-axis objective gives the GP a smoother search surface.
;; - Tighten `max_long_exposure_pct` lower bound from 0.30 → 0.45:
;;   V2 winner exposure=0.33 hurt trending years. The new bound rules
;;   out the deep-underexposure region without forcing canonical 0.70.
;; - Tighten `initial_stop_buffer` upper bound from 1.10 → 1.05: V2
;;   winner 1.072 caused fold-017 MaxDD regression. Tighter ceiling
;;   keeps stops disciplined.
;; - Tighten `max_position_pct_long` from V2's (0.02 0.20) to (0.04 0.15):
;;   V2 winners on this axis clustered near 0.07-0.10; rule out the
;;   too-small / too-large tails that adds noise without payoff.
;; - Tighten `installed_stop_min_pct` from V2's (0.04 0.15) to (0.06 0.13):
;;   V2 best-cell at 0.114 (upper-mid); the wider V2 range admitted
;;   degenerate stops <0.06 that fired too often to be useful.
;; - Same seed (2026) for cross-version comparability.
;; - Same budget=60 / initial_random=10 / holdout 27-30.
;;
;; V3 baseline — NO AvgHoldingDays cadence term. The cadence-aware run
;; (V3-cadence, spec_prod_v3_cadence.sexp) is a separate follow-up
;; sweep gated on this baseline landing. See P1 in
;; `dev/notes/next-session-priorities-2026-05-21-pm.md`.
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
    (MaxDrawdown -0.10))))
 (scenarios ())
 (holdout_folds (27 28 29 30)))
