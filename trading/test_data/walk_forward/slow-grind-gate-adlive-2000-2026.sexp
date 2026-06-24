;; enable_slow_grind_short_gate WF-CV — A-D-LIVE basis (Build 0).
;; data/ now has generated synthetic+unicorn breadth (build0-ad-breadth-2026-06-22),
;; so the decline-character A-D-lead leg is live. The A-D-inert deep screen had
;; slow_grind TAXING the edge; with A-D live it flipped to best-Calmar / best-DD on
;; higher-quality shorts (6 net +$432K vs ungated 25 net +$203K). This WF-CV asks:
;; does that best-Calmar result hold across rolling OOS folds? Deep long-short base.
;; Rolling 2000-2026 test 365 step 365 => 26 folds.
((base_scenario "test_data/backtest_scenarios/goldens-sp500-historical/sp500-2000-2026-longshort.sexp")
 (window_spec
  (Rolling ((start_date 2000-01-01) (end_date 2026-04-30) (train_days 0) (test_days 365) (step_days 365))))
 (baseline_label baseline)
 (gate ((metric Calmar) (m 14) (n 26) (worst_delta 0.0)))
 (axes ((axes (((flag enable_slow_grind_short_gate) (values (true false))))) (expansion Cartesian))))
