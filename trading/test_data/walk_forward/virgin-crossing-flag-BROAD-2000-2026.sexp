; resistance-v2 lever (a) WF-CV: virgin_crossing_readmission flag surface on
; the home grid (same base/geometry/warehouse as the 2026-07-16/17 supply
; surfaces, directly comparable to ledger
; 2026-07-16-resistance-supply-weight-surface / -confirmation-grid).
; Motivation: 28y single-path (2026-07-18, post-#2002 hist-empty fix):
; vc-only $88.2M vs baseline $80.1M (+10% terminal, Sharpe equal, DD better)
; — standalone stale-but-supply-clear re-admissions added value; single-path
; is not decision-grade, hence this surface.
; NOTE: supply weight NOT armed here — this isolates the flag on the
; record-convention base (vc-only cell). The w30-pairing question is a
; separate surface pending the floor-axis lever (c).
; Run: walk_forward_runner --spec <this> --out-dir /tmp/sweeps/vc-flag-broad
;      --fixtures-root test_data/backtest_scenarios
;      --snapshot-dir /tmp/snap_top3000_dedup_v3_sketch --parallel 1
; Cost: 1 variant x 13 folds = 13 fold-runs (+13 baseline) ~ 6h. Container solo.
((base_scenario
  "test_data/backtest_scenarios/staging-record-convention/top3000-2000-2026-record-convention.sexp")
 (window_spec
  (Rolling
   ((start_date 2000-01-01) (end_date 2026-04-30) (train_days 0)
    (test_days 730) (step_days 730))))
 (baseline_label baseline)
 (gate ((metric Sharpe) (m 7) (n 13) (worst_delta 0.0)))
 (axes
  ((axes (((flag virgin_crossing_readmission) (values (true)))))
   (expansion Cartesian))))
