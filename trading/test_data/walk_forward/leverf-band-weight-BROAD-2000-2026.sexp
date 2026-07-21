; Lever (f) age-banded-histogram surface — home broad grid, ON TOP OF the
; BUNDLE (w_overhead_supply=30 + virgin_crossing_readmission + floors 0/0/0),
; per the user directive 2026-07-20: lever (f) + its scenarios ride on the
; bundle BEFORE any promotion. Requires the v4 (80-col age-banded) warehouse
; /tmp/snap_top3000_dedup_v4_sketch.
; Variant 1 (bands 1/1/1/0) is bit-identical-by-design to the v3 bundle
; semantics -> doubles as the v4-warehouse certification against the 07-19
; floor-axis bundle row (mean Sharpe 0.827): any drift = rebuild defect.
; Variants 2-3 give MEASURED old supply (130-520w band) partial weight —
; the age question the 2011-cell regression raised (is old supply the
; missing discriminator on bull-era broad windows?). Variant 4 = full
; within-recent age decay (old bag-holders capitulate monotonically).
; Run: walk_forward_runner --spec <this> --out-dir /tmp/sweeps/leverf-broad
;      --fixtures-root test_data/backtest_scenarios
;      --snapshot-dir /tmp/snap_top3000_dedup_v4_sketch --parallel 1
; 4 variants x 13 folds + 13 baseline = 65 fold-runs, ~7-8h.
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
      (values ((30))))
     ((flag virgin_crossing_readmission) (values (true)))))
   (expansion Cartesian))))
