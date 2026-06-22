;; Build-2 arming-speed (fast_v_arm_on_rate_alone) WF-CV — DEEP 2000-2026.
;; Base has catastrophic_stop_pct=0.10 ON; axis flips arm-on-rate {true false}.
;; Tests whether the dramatic 2020-V crash protection (build2-arming-speed-screen)
;; holds across folds AND whether arm-on-rate OVER-fires (taxes) in choppy bears
;; (2008, 2022) or non-crash years. Rolling 2000-2026 test 365 step 365 => 26 folds.
((base_scenario "test_data/backtest_scenarios/goldens-sp500-historical/sp500-2000-2026-catstop.sexp")
 (window_spec
  (Rolling ((start_date 2000-01-01) (end_date 2026-04-30) (train_days 0) (test_days 365) (step_days 365))))
 (baseline_label baseline)
 (gate ((metric Sharpe) (m 14) (n 26) (worst_delta 0.0)))
 (axes ((axes (((flag fast_v_arm_on_rate_alone) (values (true false))))) (expansion Cartesian))))
