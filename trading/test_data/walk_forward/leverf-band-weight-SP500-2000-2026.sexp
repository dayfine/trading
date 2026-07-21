; Lever (f) age-banded-histogram surface — sp500 cell, ON TOP OF the BUNDLE
; at the breadth-adapted weight w15 (sp500 optimum per the 07-17 grid and the
; 07-19 bundle cell). Requires the v4 (80-col) warehouse
; /tmp/snap_sp500_2000_2026_v4_sketch.
; Variant 1 (bands 1/1/1/0) is bit-identical-by-design to v3 bundle-w15
; semantics -> v4-warehouse certification against the 07-19 bundle-sp500 cell
; (mean Sharpe 0.737, 19/26 wins): any drift = rebuild defect.
; Variants 2-4: measured 130-520w-band supply at partial weight + full age
; decay — the age question, on the cheap universe first (the broad v4 surface
; is blocked on a Docker VM RAM bump: 8.4G warehouse vs 7.8G VM).
; Run: walk_forward_runner --spec <this> --out-dir /tmp/sweeps/leverf-sp500
;      --fixtures-root test_data/backtest_scenarios
;      --snapshot-dir /tmp/snap_sp500_2000_2026_v4_sketch --parallel 1
; 4 variants x 26 folds + 26 baseline = 130 fold-runs, ~6-7h.
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
          (moderate_resistance_bars 3) (band_weight_0_26w 1.0)
          (band_weight_26_78w 1.0) (band_weight_78_130w 1.0)
          (band_weight_130_520w 0.0)))
        (((proximity_decay 0.7) (saturation_bars 8.0) (recent_far_floor 0.0)
          (stale_mid_floor 0.0) (stale_old_floor 0.0) (min_history_bars 0)
          (insufficient_score 0.5) (heavy_resistance_bars 8)
          (moderate_resistance_bars 3) (band_weight_0_26w 1.0)
          (band_weight_26_78w 1.0) (band_weight_78_130w 1.0)
          (band_weight_130_520w 0.25)))
        (((proximity_decay 0.7) (saturation_bars 8.0) (recent_far_floor 0.0)
          (stale_mid_floor 0.0) (stale_old_floor 0.0) (min_history_bars 0)
          (insufficient_score 0.5) (heavy_resistance_bars 8)
          (moderate_resistance_bars 3) (band_weight_0_26w 1.0)
          (band_weight_26_78w 1.0) (band_weight_78_130w 1.0)
          (band_weight_130_520w 0.5)))
        (((proximity_decay 0.7) (saturation_bars 8.0) (recent_far_floor 0.0)
          (stale_mid_floor 0.0) (stale_old_floor 0.0) (min_history_bars 0)
          (insufficient_score 0.5) (heavy_resistance_bars 8)
          (moderate_resistance_bars 3) (band_weight_0_26w 1.0)
          (band_weight_26_78w 0.7) (band_weight_78_130w 0.5)
          (band_weight_130_520w 0.25))))))
     ((key (screening_config weights w_overhead_supply))
      (values ((15))))
     ((flag virgin_crossing_readmission) (values (true)))))
   (expansion Cartesian))))
