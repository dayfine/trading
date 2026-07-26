; BUNDLE confirmation grid cell 1/2 — sp500-515 universe+geometry cell for the
; promotion candidate BUNDLE (w_overhead_supply + virgin_crossing_readmission
; + floors 0/0/0), per the 07-19 promotion memo option B (user green-lit
; 2026-07-19). Same base/geometry as the 07-17 w30 grid sp500 cell
; (resistance-supply-weight-SP500-2000-2026.sexp) so bundle vs plain-w30 is
; directly comparable; the only delta vs that cell's arming = floors zeroed
; + vc flag on. Weights {15,30}: breadth-adapted (optimum shifted lower on
; narrow universes in the 07-17 grid).
; Run: walk_forward_runner --spec <this> --out-dir /tmp/sweeps/bundle-sp500
;      --fixtures-root test_data/backtest_scenarios
;      --snapshot-dir /tmp/snap_sp500_2000_2026_v3_sketch --parallel 1
; 2 variants + baseline x 26 folds = 78 fold-runs, sp500-cheap ~4-6h.
((base_scenario
  "test_data/backtest_scenarios/goldens-sp500-historical/sp500-2000-2026-catstop.sexp")
 (window_spec
  (Rolling
   ((start_date 2000-01-01) (end_date 2026-04-30) (train_days 0)
    (test_days 365) (step_days 365))))
 (baseline_label baseline)
 (gate ((metric Sharpe) (m 14) (n 26) (worst_delta 0.0)))
 (axes
  ((axes
    (((key (overhead_supply))
      (values
       ((((proximity_decay 0.7) (saturation_bars 8.0) (recent_far_floor 0.0)
          (stale_mid_floor 0.0) (stale_old_floor 0.0) (min_history_bars 0)
          (insufficient_score 0.5) (heavy_resistance_bars 8)
          (moderate_resistance_bars 3))))))
     ((key (screening_config weights w_overhead_supply))
      (values ((15) (30))))
     ((flag virgin_crossing_readmission) (values (true)))))
   (expansion Cartesian))))
