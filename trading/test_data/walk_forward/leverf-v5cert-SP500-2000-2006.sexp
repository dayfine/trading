; Sketch-v5 certification spec — REDUCED sp500 cell (6 folds, 2000-2006).
; This is the leverf-band-weight-SP500-2000-2026.sexp surface with end_date cut
; to 2006-04-30 so the cert fits one PR cycle (~1.5h vs ~6-7h). All 5 arms
; (baseline + 4 band-weight variants) are kept identical to the full spec.
;
; PURPOSE: prove the v5 side-table read path is bit-identical to the v4 dense
; columns. Run this ONCE against the v5 warehouse (/tmp/snap_sp500_2000_2026_v5,
; has SYMBOL.weekly side-tables -> v5 read path active) and ONCE against the v4
; warehouse (/tmp/snap_sp500_2000_2026_v4_sketch, no side-tables -> dense path),
; then diff the two walk_forward_report.md fold tables. Byte-equal = cert PASS.
; Run: walk_forward_runner --spec <this> --out-dir /tmp/sweeps/leverf-sp500-v5cert
;      --fixtures-root test_data/backtest_scenarios
;      --snapshot-dir <v5-or-v4-dir> --parallel 1
((base_scenario
  "test_data/backtest_scenarios/goldens-sp500-historical/sp500-2000-2026-catstop.sexp")
 (window_spec
  (Rolling
   ((start_date 2000-01-01) (end_date 2006-04-30) (train_days 0)
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
