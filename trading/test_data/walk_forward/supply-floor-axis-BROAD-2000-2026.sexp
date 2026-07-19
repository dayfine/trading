; resistance-v2 lever (c) WIDENED: horizon-floor axis under the w30+vc pair.
; Motivation (dev/notes/virgin-crossing-pair-runs-2026-07-18.md): post-#2002
; the vc arm makes redeemed monsters ADMISSIBLE, but the recent_far_floor 0.4
; (fired by a max_high_130w the name's own rally keeps setting) prices them
; to 18/30 resistance points and they lose the cap-20/cash race (AXTI Jan-26,
; hist fully sighted and EMPTY). This surface asks: does softening the floors
; (trusting a full-and-empty histogram) repair the recovery-window forfeit
; while keeping w30's DD compression?
; Variants: w30+vc with floors full (0.4/0.25/0.1 = current w30+vc cell),
; half (0.2/0.125/0.05), zero (0/0/0). Baseline = record convention
; (no supply, no vc) for cross-surface comparability with the 07-16/17
; ledger entries and the vc-flag surface.
; Run: walk_forward_runner --spec <this> --out-dir /tmp/sweeps/floor-axis
;      --fixtures-root test_data/backtest_scenarios
;      --snapshot-dir /tmp/snap_top3000_dedup_v3_sketch --parallel 1
; Cost: 3 variants x 13 folds + 13 baseline = 52 fold-runs, overnight solo.
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
          (moderate_resistance_bars 3)))
        (((proximity_decay 0.7) (saturation_bars 8.0) (recent_far_floor 0.2)
          (stale_mid_floor 0.125) (stale_old_floor 0.05) (min_history_bars 0)
          (insufficient_score 0.5) (heavy_resistance_bars 8)
          (moderate_resistance_bars 3)))
        (((proximity_decay 0.7) (saturation_bars 8.0) (recent_far_floor 0.0)
          (stale_mid_floor 0.0) (stale_old_floor 0.0) (min_history_bars 0)
          (insufficient_score 0.5) (heavy_resistance_bars 8)
          (moderate_resistance_bars 3))))))
     ((key (screening_config weights w_overhead_supply)) (values ((30))))
     ((flag virgin_crossing_readmission) (values (true)))))
   (expansion Cartesian))))
