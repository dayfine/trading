; resistance-v2 follow-up 3/3: UNIVERSE + GEOMETRY diversity confirmation
; cell — sp500-515 (different breadth/snapshot) at the FINE fold geometry
; (1y/26-fold, the deep-sp500 precedent) vs the broad run's 2y/13.
; Tests whether the v1-run winners {15,30} generalize off the top-3000
; basis. Include one crash-recovery-heavy read by inspecting folds
; 2003/2009 individually in the report (the mechanism's known loss regime).
;
; PREREQ: an sp500 warehouse with 37-col sketch schema + deep feed does NOT
; exist yet (schema gate rejects the old ones). Build first (~10-20 min):
;   dune exec trading/backtest/snapshot_warehouse/build_scenario_snapshots.exe --
;     -scenario test_data/backtest_scenarios/goldens-sp500-historical/sp500-2000-2026-catstop.sexp
;     -csv-data-dir /workspaces/trading-1/data -fixtures-root test_data/backtest_scenarios
;     -output-dir /tmp/snap_sp500_2000_2026_v3_sketch
; Then: walk_forward_runner --spec <this> --out-dir /tmp/sweeps/resist-supply-sp500
;       --fixtures-root test_data/backtest_scenarios
;       --snapshot-dir /tmp/snap_sp500_2000_2026_v3_sketch --parallel 1
; 2 variants + baseline x 26 folds = 78 fold-runs; sp500 folds are much
; cheaper than broad (~2-4 min) ~ 4-6h. Container solo.
; NOTE base is the catstop golden convention (not the top-3000 record
; convention) — this cell tests mechanism generalization, not convention
; parity; the two arming axes below are the only deltas vs that base.
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
       ((((proximity_decay 0.7) (saturation_bars 8.0) (recent_far_floor 0.4)
          (stale_mid_floor 0.25) (stale_old_floor 0.1) (min_history_bars 0)
          (insufficient_score 0.5) (heavy_resistance_bars 8)
          (moderate_resistance_bars 3))))))
     ((key (screening_config weights w_overhead_supply))
      (values ((15) (30))))))
   (expansion Cartesian))))
