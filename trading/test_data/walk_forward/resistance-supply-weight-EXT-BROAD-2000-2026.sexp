; resistance-v2 follow-up 1/3: EXTEND the weight axis past the v1 boundary
; winner (w=30 was the max tested and still rising — find the interior).
; Same base/geometry/warehouse as resistance-supply-weight-BROAD-2000-2026
; so aggregates are directly comparable to the 2026-07-16 run
; (ledger 2026-07-16-resistance-supply-weight-surface).
; Run: walk_forward_runner --spec <this> --out-dir /tmp/sweeps/resist-supply-ext
;      --fixtures-root test_data/backtest_scenarios
;      --snapshot-dir /tmp/snap_top3000_dedup_v3_sketch --parallel 1
; Cost: 3 variants x 13 folds = 39 fold-runs ~ 9h. Container solo.
((base_scenario
  "test_data/backtest_scenarios/staging-record-convention/top3000-2000-2026-record-convention.sexp")
 (window_spec
  (Rolling
   ((start_date 2000-01-01) (end_date 2026-04-30) (train_days 0)
    (test_days 730) (step_days 730))))
 (baseline_label baseline)
 (gate ((metric Sharpe) (m 7) (n 13) (worst_delta 0.0)))
 (axes
  ((axes
    (((key (overhead_supply))
      (values
       ((((proximity_decay 0.7) (saturation_bars 8.0) (recent_far_floor 0.4)
          (stale_mid_floor 0.25) (stale_old_floor 0.1) (min_history_bars 0)
          (insufficient_score 0.5) (heavy_resistance_bars 8)
          (moderate_resistance_bars 3))))))
     ((key (screening_config weights w_overhead_supply))
      (values ((45) (60))))))
   (expansion Cartesian))))
