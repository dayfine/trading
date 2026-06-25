;; Capacity/concentration surface — FILL-IN cells, DEEP 2000-2026.
;; v2 swept max_position_pct_long {0.14, 0.25, 0.40} and found an interior optimum
;; at 0.25 (Sharpe 0.56->0.86, Calmar 1.03->2.08, MaxDD flat; 0.40 over-concentrates).
;; The max_long_exposure_pct axis was bit-identical (per-position cap is the sole
;; binding constraint), so it is dropped here. This run fills {0.20, 0.30, 0.35} to
;; pin the peak precisely and locate the canonical default (0.30) on the curve.
;; baseline anchor = the deep-base 0.14 (the value baked into every deep golden).
;; Rolling 2000-2026 test 365 step 365 => 26 folds.
((base_scenario "test_data/backtest_scenarios/goldens-sp500-historical/sp500-2000-2026-catstop.sexp")
 (window_spec
  (Rolling ((start_date 2000-01-01) (end_date 2026-04-30) (train_days 0) (test_days 365) (step_days 365))))
 (baseline_label baseline)
 (gate ((metric Sharpe) (m 14) (n 26) (worst_delta 0.0)))
 (axes
  ((axes
    (((key (portfolio_config max_position_pct_long)) (values (0.20 0.30 0.35)))))
   (expansion Cartesian))))
