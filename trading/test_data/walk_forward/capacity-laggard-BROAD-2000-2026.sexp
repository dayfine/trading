;; Capacity lever 2 (turnover) — BROAD top-3000, DEEP 2000-2026.
;; Companion to capacity-concentration-BROAD: on the broad basis, concentration is a
;; CLEAN lever (0.30 = the production default is the broad-optimal, +3pp CAGR vs the
;; deep-base 0.14), unlike the washed-out SP500-515 result. This tests whether the
;; turnover lever (laggard_rotation_config.hysteresis_weeks) ALSO lights up on broad,
;; and whether the cross-cutting finding (deep-base value 2 is below the production
;; default 4, and default beats base) holds with breadth. {2,4,8} = base / default /
;; slow. Run: walk_forward_runner --snapshot-dir /tmp/snap_top3000_1998_2026
;; --parallel 1. 2-year folds (~4min/fold at parallel=1, N=3000). baseline anchor = 2.
((base_scenario "test_data/backtest_scenarios/goldens-sp500-historical/top3000-2000-2026-catstop.sexp")
 (window_spec
  (Rolling ((start_date 2000-01-01) (end_date 2026-04-30) (train_days 0) (test_days 730) (step_days 730))))
 (baseline_label baseline)
 (gate ((metric Sharpe) (m 7) (n 13) (worst_delta 0.0)))
 (axes
  ((axes
    (((key (laggard_rotation_config hysteresis_weeks)) (values (2 4 8)))))
   (expansion Cartesian))))
