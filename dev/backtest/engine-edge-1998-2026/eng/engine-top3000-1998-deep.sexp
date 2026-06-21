;; Engine-edge + barbell engine leg — canonical LONG-ONLY Cell-E, 1998-2026.
;; The S&P-beating baseline (cf. project_deep_1998_2026_contiguous: realized
;; +1552% vs SPX +599%). Re-confirmed on CURRENT code over the correct full-cycle
;; window (1998-26, captures the dot-com run-up + bust + GFC), top-3000 PIT-1998.
;; Cost model = the established deep baseline (per-share $0.01). This run's equity
;; curve is BOTH the engine-edge baseline (Phase A) and the barbell engine leg
;; (Phase B). Snapshot mode (reuse /tmp/snap_top3000_1998_ls). See
;; dev/notes/overnight-plan-2026-06-21.md.
((name "engine-top3000-1998-deep")
 (description "Cell-E LONG-ONLY, top-3000 PIT-1998, 1998-2026 — engine-edge baseline + barbell engine leg.")
 (period ((start_date 1998-01-01) (end_date 2026-04-30)))
 (universe_path "workspaces/trading-1/trading/test_data/goldens-custom-universe/composition/top-3000-1998.sexp")
 (universe_size 3000)
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
   (per_share_commission 0.01)
   (bid_ask_spread_bps 0.0)
   (market_impact_bps_per_pct_adv 0.0)))
 (expected
  ((total_return_pct  ((min -100.0) (max 1000000.0)))
   (total_trades      ((min    0.0) (max 1000000.0)))
   (win_rate          ((min    0.0) (max     100.0)))
   (sharpe_ratio      ((min  -100.0) (max     100.0)))
   (max_drawdown_pct  ((min    0.0) (max     100.0)))
   (avg_holding_days  ((min    0.0) (max  100000.0)))
   (wall_seconds      ((min    1.0) (max  360000.0))))))
