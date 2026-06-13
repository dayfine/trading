;; Crash-warmup cell — start 2009-07-01 so the 210-day warmup (≈2008-12-03..2009-07)
;; straddles the GFC bottom (the #1549 specimen as a standalone scenario). CSV mode.
;; ON arm = warmup indicators-only (start from cash).
((name "wu-on-crash2009")
 (description "Warmup-compare ON: crash-warmup 2009-07 start, top-1000-2008, CSV mode.")
 (period ((start_date 2009-07-01) (end_date 2016-12-31)))
 (universe_path "../goldens-custom-universe/composition/top-1000-2008.sexp")
 (universe_size 1000)
 (config_overrides
  (((enable_short_side false))
   ((suppress_warmup_trading true))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (cost_model
  ((per_trade_commission 0.0) (per_share_commission 0.0)
   (bid_ask_spread_bps 5.0) (market_impact_bps_per_pct_adv 0.0)))
 (expected
  ((total_return_pct ((min -100.0) (max 100000.0)))
   (total_trades ((min 0) (max 1000000)))
   (win_rate ((min 0.0) (max 100.0)))
   (sharpe_ratio ((min -100.0) (max 100.0)))
   (max_drawdown_pct ((min 0.0) (max 100.0)))
   (avg_holding_days ((min 0.0) (max 100000.0))))))
