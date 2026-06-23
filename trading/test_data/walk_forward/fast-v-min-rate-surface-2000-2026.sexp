;; fast_v_min_rate_pct SURFACE WF-CV — DEEP 2000-2026. Base = cat_stop 0.10 +
;; arm_on_rate=true. Axis sweeps the arming rate threshold {0.08, 0.12, 0.16}.
;; Hypothesis: raising the threshold suppresses the 2010/2011 whipsaw (moderate
;; dips no longer arm Fast_v) WHILE keeping the genuine 2020-V catch (steeper).
;; Rolling 2000-2026 test 365 step 365 => 26 folds.
((base_scenario "test_data/backtest_scenarios/goldens-sp500-historical/sp500-2000-2026-catstop-armon.sexp")
 (window_spec
  (Rolling ((start_date 2000-01-01) (end_date 2026-04-30) (train_days 0) (test_days 365) (step_days 365))))
 (baseline_label baseline)
 (gate ((metric Sharpe) (m 14) (n 26) (worst_delta 0.0)))
 (axes ((axes (((key (fast_v_min_rate_pct)) (values (0.08 0.12 0.16))))) (expansion Cartesian))))
