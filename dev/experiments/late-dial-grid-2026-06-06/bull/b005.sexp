;; P0 barbell — bull-window ENGINE curve (cross-regime confirmation) AND
;; ground-truth re-measure to settle the sp500-2010-2026 golden discrepancy:
;; golden #1383 pinned 311.9% (bands 270-355); priorities-doc claims corrected
;; 237%. Same config + universe as goldens-sp500-historical/sp500-2010-2026.sexp.
((name "late-bull-b005")
 (description "Cell E production strategy on PIT S&P 500 (2010-01-01 snapshot) 2010-2026 — barbell ENGINE curve (bull) + golden ground-truth.")
 (period ((start_date 2010-01-01) (end_date 2026-04-30)))
 (universe_path "universes/sp500-historical/sp500-2010-01-01.sexp")
 (universe_size 510)
 (config_overrides
  (((enable_short_side false))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))
   ((enable_late_stage2_stop_tighten true))
   ((late_stage2_stop_buffer_pct 0.05))))
 (cost_model
  ((per_trade_commission 0.0)
   (per_share_commission 0.0)
   (bid_ask_spread_bps 5.0)
   (market_impact_bps_per_pct_adv 0.0)))
 (expected
  ((total_return_pct  ((min -90.0)  (max 100000.0)))
   (total_trades      ((min   0.0)  (max 100000.0)))
   (win_rate          ((min   0.0)  (max  100.0)))
   (sharpe_ratio      ((min  -2.0)  (max    5.0)))
   (max_drawdown_pct  ((min   0.0)  (max   95.0)))
   (avg_holding_days  ((min   0.0)  (max 5000.0)))
   (wall_seconds      ((min   1.0)  (max 360000.0))))))
