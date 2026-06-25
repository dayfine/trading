;; Capacity lever 2 — laggard-rotation CADENCE (turnover), DEEP 2000-2026.
;; Optimal-lens (2026-06-25): the strategy churns ~280 trades (vs the optimal's
;; 47), and the rotation churn is what exhausts cash so cascade-identified winners
;; go unfunded (Insufficient_cash). Distinct from the concentration surface
;; (capacity-concentration-*, INCONCLUSIVE: size-cap concentration is knife-edge
;; fat-tail variance with no free Sharpe). Turnover is a DIFFERENT capacity lever:
;; slowing rotation preserves dry powder WITHOUT cranking single-name variance.
;; laggard_rotation_config.hysteresis_weeks = consecutive negative-RS Fridays
;; before a position is rotated out; the deep base uses 2 (aggressive). Raise it
;; {2,4,6,8} => slower rotation, less churn. Faithful Weinstein dial (confirmation
;; weeks; book suggests 4-6). baseline anchor = hysteresis_weeks=2 (the base value).
;; Rolling 2000-2026 test 365 step 365 => 26 folds.
((base_scenario "test_data/backtest_scenarios/goldens-sp500-historical/sp500-2000-2026-catstop.sexp")
 (window_spec
  (Rolling ((start_date 2000-01-01) (end_date 2026-04-30) (train_days 0) (test_days 365) (step_days 365))))
 (baseline_label baseline)
 (gate ((metric Sharpe) (m 14) (n 26) (worst_delta 0.0)))
 (axes
  ((axes
    (((key (laggard_rotation_config hysteresis_weeks)) (values (2 4 6 8)))))
   (expansion Cartesian))))
