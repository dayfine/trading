;; Capacity/concentration surface — DEEP 2000-2026.
;; Optimal-lens (2026-06-25, dev/notes/optimal-lens-insights-2026-06-25.md): the
;; strategy's misses are Insufficient_cash — the cascade correctly IDENTIFIES the
;; breakout winners but they go UNFUNDED because capital is sprayed thin (the deep
;; base caps each long at max_position_pct_long=0.14 and deploys only
;; max_long_exposure_pct=0.70, so ~5 small slots churn while the monsters starve).
;; This is a capacity gap, not an entry-selection gap (entry-selection is
;; settled-dead, 3rd confirmation). Lever = the capital envelope; this is a
;; tail-PRESERVING funding lever (let identified winners be funded/larger), NOT a
;; winner-touching trim. Sweep the per-position concentration cap x the long
;; deployment ceiling. Cell (0.14, 0.70) reproduces the current deep base =
;; baseline anchor. Rolling 2000-2026 test 365 step 365 => 26 folds.
;; min_cash_pct EXCLUDED — deprecated, never wired into the entry walk.
((base_scenario "test_data/backtest_scenarios/goldens-sp500-historical/sp500-2000-2026-catstop.sexp")
 (window_spec
  (Rolling ((start_date 2000-01-01) (end_date 2026-04-30) (train_days 0) (test_days 365) (step_days 365))))
 (baseline_label baseline)
 (gate ((metric Sharpe) (m 14) (n 26) (worst_delta 0.0)))
 (axes
  ((axes
    (((key (portfolio_config max_position_pct_long)) (values (0.14 0.25 0.40)))
     ((key (portfolio_config max_long_exposure_pct)) (values (0.70 0.90)))))
   (expansion Cartesian))))
