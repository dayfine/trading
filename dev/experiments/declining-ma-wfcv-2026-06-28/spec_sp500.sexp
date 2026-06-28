;; Declining-MA long-entry gate WF-CV surface — Cell-E broad top-3000 PIT-1998,
;; 2000-2026, 2-year non-overlapping folds (13 folds), fork-per-fold.
;; baseline = reject_declining_ma_long_entry=false (default); variant flips it on.
((base_scenario "/workspaces/trading-1/dev/experiments/declining-ma-wfcv-2026-06-28/base_sp500.sexp")
 (window_spec
  (Rolling
   ((start_date 2000-01-01)(end_date 2026-04-30)(train_days 0)(test_days 730)(step_days 730))))
 (variants
  (((label "baseline") (overrides ()))
   ((label "declining_ma_gate_on")
    (overrides (((reject_declining_ma_long_entry true)))))))
 (baseline_label "baseline")
 (gate ((metric Sharpe)(m 7)(n 13)(worst_delta 0.30))))
