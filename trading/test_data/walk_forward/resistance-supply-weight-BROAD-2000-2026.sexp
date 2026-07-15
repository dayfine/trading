; resistance-v2 PR-E: w_overhead_supply score-weight surface (2026-07-15).
;
; Arbitrates the 07-14 false-virgin finding (dev/notes/resist520-armed-run-
; 2026-07-14.md): were the false virgins luck or structure? Axis spans both
; directions: negative weight = PREFER overhead (the direction the crash-
; recovery monsters imply), 0 = neutralize the resistance signal entirely
; (Run-C analog), positive = penalize supply continuously (the book's rule,
; priced). Baseline (auto-included, weight None + overhead_supply unarmed)
; = today's binary path bit-identical.
;
; Every non-baseline cell arms overhead_supply with Resistance_supply
; defaults (single-value axis, cartesian) so supply is computed; the weight
; axis then prices it. min_history_bars stays 0 so this surface isolates ONE
; mechanism (supply pricing); the insufficient-history floor is a separate
; later axis.
;
; Geometry: broad top-3000 2-year folds (13) per the capacity/cash-reserve
; precedent (~10 min/fold-run at parallel 1; 5 trials x 13 folds ~ 11h).
; Run: walk_forward_runner --spec <this> --out-dir /tmp/sweeps/<name>
;      --snapshot-dir /tmp/snap_top3000_dedup_v3_sketch --parallel 1
; (warehouse MUST be the 37-column dedup-v3 sketch build; the schema-hash
; gate rejects older warehouses).
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
      (values ((-15) (0) (15) (30))))))
   (expansion Cartesian))))
