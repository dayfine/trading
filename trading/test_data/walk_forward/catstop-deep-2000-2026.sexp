;; catastrophic_stop_pct WF-CV — DEEP 2000-2026 (364 basis).
;; catstop has never had its own fold-distribution evidence: the 06-22
;; arming-speed WF-CV had catstop=0.10 ON in BOTH arms. The 2026-07-09 P1a deep
;; screen (p1a-deep-short-screens-364-2026-07-09.md, corrected) shows its value
;; is DISTRIBUTED across the deep bears (2001-02 +5.9%, 2008 +3.1% incr) —
;; this spec tests whether that survives per-fold. Base has catstop=0.10; the
;; key-path axis overrides it {0.0, 0.10} — the 0.10 cell must be ~identical
;; to baseline (built-in parity check of the nested key-path override), the
;; 0.0 cell is the real comparator. Rolling 26 annual folds, same gate shape
;; as arming-speed-deep-2000-2026.
((base_scenario "test_data/backtest_scenarios/goldens-sp500-historical/sp500-2000-2026-catstop.sexp")
 (window_spec
  (Rolling ((start_date 2000-01-01) (end_date 2026-04-30) (train_days 0) (test_days 365) (step_days 365))))
 (baseline_label baseline)
 (gate ((metric Sharpe) (m 14) (n 26) (worst_delta 0.0)))
 (axes ((axes (((key (stops_config catastrophic_stop_pct)) (values (0.0 0.10))))) (expansion Cartesian))))
