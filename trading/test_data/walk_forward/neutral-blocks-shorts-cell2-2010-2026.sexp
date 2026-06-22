;; neutral_blocks_shorts WF-CV — CONFIRMATION GRID cell 2 (promotion-confirmation.md).
;; Cell 1 was sp500-as-of-2000 / 2000-2026 (all-regime). This cell is a DIFFERENT
;; universe (sp500-as-of-2010) and a DIFFERENT, bull-dominated period (2010-2026),
;; on the existing long-short golden base. If neutral_blocks_shorts=true >= baseline
;; here too, the mechanism is robust across the (period x universe) grid and eligible
;; for a default flip. Rolling 2010-2026 test 365 step 365 => ~16 folds. CSV on data/.
((base_scenario "test_data/backtest_scenarios/goldens-sp500-historical/sp500-2010-2026-longshort.sexp")
 (window_spec
  (Rolling ((start_date 2010-01-01) (end_date 2026-04-30) (train_days 0) (test_days 365) (step_days 365))))
 (baseline_label baseline)
 (gate ((metric Sharpe) (m 9) (n 16) (worst_delta 0.0)))
 (axes ((axes (((flag neutral_blocks_shorts) (values (true false))))) (expansion Cartesian))))
