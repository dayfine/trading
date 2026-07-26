; BUNDLE confirmation grid cell 2/2 — broad 2011-2026 period cell for the
; promotion candidate BUNDLE (w_overhead_supply + virgin_crossing_readmission
; + floors 0/0/0), per the 07-19 promotion memo option B (user green-lit
; 2026-07-19). Same base/geometry as the 07-17 w30 grid 2011 cell
; (resistance-supply-weight-BROAD-2011-2026.sexp); only delta vs that cell's
; arming = floors zeroed + vc flag on.
; Run: walk_forward_runner --spec <this> --out-dir /tmp/sweeps/bundle-2011
;      --fixtures-root test_data/backtest_scenarios
;      --snapshot-dir /tmp/snap_top3000_dedup_v3_sketch --parallel 1
; 2 variants + baseline x 7 folds = 21 broad fold-runs ~4-5h.
((base_scenario
  "test_data/backtest_scenarios/staging-record-convention/top3000-2000-2026-record-convention.sexp")
 (window_spec
  (Rolling
   ((start_date 2011-01-01) (end_date 2026-04-30) (train_days 0)
    (test_days 730) (step_days 730))))
 (baseline_label baseline)
 (gate ((metric Sharpe) (m 4) (n 7) (worst_delta 0.0)))
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
