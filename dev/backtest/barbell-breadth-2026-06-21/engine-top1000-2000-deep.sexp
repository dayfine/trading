;; Barbell BREADTH-confirmation cell (2026-06-21).
;; P0 gate #1 from next-session-priorities-2026-06-21.md: the 2026-06-20 barbell
;; grid promoted 70/30 but its universe-diversity leg was thin (3/4 cells shared
;; SP500 PIT-2000; the 4th was a snapshot variant, not a breadth jump). This cell
;; re-runs the ENGINE leg on a genuinely broader universe — top-1000 PIT-2000
;; (~2x the SP500-515 breadth) — over the SAME window as grid cell A (2000-2026),
;; so it blends against the existing floor-2000-deep equity curve. Confirms the
;; 70/30 weight transfers to breadth.
;;
;; Config = identical Cell-E to grid cell A (engineA-sp500_2000-deep): long-only,
;; 0.14/0.70/0.30 sizing + stage3-force-exit h=1 + laggard-rotation h=2, and the
;; SAME 5bps-spread cost model (NOT the per-share-commission model the top-3000
;; deep goldens use) so the blend comparison is apples-to-apples with cells A-D.
;; N=1000 deep needs snapshot mode (CSV-mode OOMs >=1000) — run with --snapshot-dir.
((name "engine-top1000-2000-deep")
 (description "Cell-E engine, top-1000 PIT-2000, 2000-2026 — barbell breadth-confirmation cell.")
 (period ((start_date 2000-01-01) (end_date 2026-04-30)))
 (universe_path "workspaces/trading-1/trading/test_data/goldens-custom-universe/composition/top-1000-2000.sexp")
 (universe_size 1000)
 (config_overrides
  (((enable_short_side false))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (cost_model
  ((per_trade_commission 0.0)
   (per_share_commission 0.0)
   (bid_ask_spread_bps 5.0)
   (market_impact_bps_per_pct_adv 0.0)))
 (expected
  ((total_return_pct  ((min -90.0)  (max 1000000.0)))
   (total_trades      ((min   0.0)  (max 1000000.0)))
   (win_rate          ((min   0.0)  (max  100.0)))
   (sharpe_ratio      ((min  -2.0)  (max    5.0)))
   (max_drawdown_pct  ((min   0.0)  (max   95.0)))
   (avg_holding_days  ((min   0.0)  (max 5000.0)))
   (wall_seconds      ((min   1.0)  (max 360000.0))))))
