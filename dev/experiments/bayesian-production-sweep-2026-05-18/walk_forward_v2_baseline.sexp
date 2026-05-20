;; Walk-forward spec for the V2 Bayesian sweep.
;; Single variant (cell-E baseline). BO loop injects candidate variants
;; per-iteration. Mirrors window/folds from walk_forward_v1_best.sexp.
((base_scenario "goldens-sp500-historical/sp500-2010-2026.sexp")
 (window_spec
  (Rolling
   ((start_date 2010-01-01)
    (end_date 2026-04-30)
    (train_days 0)
    (test_days 365)
    (step_days 182))))
 (variants
  (((label "cell-E") (overrides ()))))
 (baseline_label "cell-E")
 (gate ((metric Sharpe) (m 17) (n 30) (worst_delta 0.30))))
