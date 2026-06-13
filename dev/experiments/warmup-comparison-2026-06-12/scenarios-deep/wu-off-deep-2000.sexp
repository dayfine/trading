;; Confirmation-grid Cell B — DEEP macro-regime cell (dot-com + GFC).
;; sp500-historical PIT-2000 universe (515 sym, delisting-aware incl LEH/BSC),
;; window 2000-01-01..2010-12-31. CSV mode (GSPC.INDX covers 1927+). Canonical
;; Cell-E config; the WF surface flips enable_stage3_force_exit.
((name "wu-off-deep-2000")
 (description "Warmup-compare OFF: deep dot-com+GFC regime, sp500-historical-2000 510-sym, CSV mode.")
 (period ((start_date 2000-01-01) (end_date 2010-12-31)))
 (universe_path "universes/sp500-historical/sp500-2000-01-01.sexp")
 (universe_size 515)
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
  ((total_return_pct ((min -100.0) (max 100000.0)))
   (total_trades ((min 0) (max 1000000)))
   (win_rate ((min 0.0) (max 100.0)))
   (sharpe_ratio ((min -100.0) (max 100.0)))
   (max_drawdown_pct ((min 0.0) (max 100.0)))
   (avg_holding_days ((min 0.0) (max 100000.0))))))
