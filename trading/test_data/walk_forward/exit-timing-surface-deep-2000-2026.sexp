;; Exit-timing SURFACE sweep — DEEP 2000-2026 re-validation.
;;
;; Same 9-cell surface as exit-timing-surface-2026-05-30.sexp
;; (hysteresis_weeks {1,2,3} x stage3_exit_margin_pct {0.0,0.02,0.05}) + baseline,
;; but on the FULL 2000-2026 cycle (dot-com bust + GFC) using the point-in-time
;; 2000 SP500 universe incl. delistings (same deep dataset as the early-admission
;; deep test). Converts the exit-timing REJECT from single-regime (2010-2026,
;; post-GFC bull) to a genuinely multi-regime rejection — the standard codified in
;; .claude/rules/promotion-confirmation.md.
;;
;; Geometry: Rolling 2000-2026, test_days=365 step_days=182 => ~51 OOS folds.
;; Gate n=51 matches the generated count; decision is the cross-variant ranking
;; (Variant_ranking Pareto + Deflated_sharpe), harvested post-run.

((base_scenario "goldens-sp500-historical/sp500-2000-2026.sexp")
 (window_spec
  (Rolling
   ((start_date 2000-01-01)
    (end_date 2026-04-30)
    (train_days 0)
    (test_days 365)
    (step_days 182))))
 (baseline_label "baseline")
 (gate ((metric Sharpe) (m 26) (n 51) (worst_delta 0.20)))
 (axes
  ((axes
    (((key (stage3_force_exit_config hysteresis_weeks)) (values (1 2 3)))
     ((key (stage3_exit_margin_pct)) (values (0.0 0.02 0.05)))))
   (expansion Cartesian))))
