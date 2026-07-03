;; Participation-effect measurement (P0, next-session-priorities-2026-07-03):
;; sp500 fold-001 BASELINE twin for the existing pullback/either repro audits.
;; Mirrors base_sp500.sexp overrides + repro fold-001 window exactly.
((name "part-sp500-f001-baseline")
 (description "Participation measurement: sp500 fold-001 (2001-12-31..2003-12-30) baseline (no scale-in).")
 (period ((start_date 2001-12-31) (end_date 2003-12-30)))
 (universe_path "universes/sp500-historical/sp500-2000-01-01.sexp")
 (universe_size 515)
 (config_overrides
  (((enable_short_side false))
   ((portfolio_config ((max_position_pct_long 0.30))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (cost_model ((per_trade_commission 0.0)(per_share_commission 0.01)(bid_ask_spread_bps 0.0)(market_impact_bps_per_pct_adv 0.0)))
 (expected ((total_return_pct ((min -100.0)(max 100000.0)))(total_trades ((min 0)(max 1000000)))(win_rate ((min 0.0)(max 100.0)))(sharpe_ratio ((min -100.0)(max 100.0)))(max_drawdown_pct ((min 0.0)(max 100.0)))(avg_holding_days ((min 0.0)(max 100000.0))))))
