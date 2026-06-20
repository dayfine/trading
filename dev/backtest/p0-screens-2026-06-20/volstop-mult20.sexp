;; P0b vol-scaled-stop SCREEN (mult=1.0) — deep 1998-2026, long-only, otherwise
;; identical to cell-e-top3000-1998-deep.sexp. Read-only. Adds
;; ((stops_config ((vol_scaled_stop_atr_mult 2.0)))). Baseline = the long-only
;; deep run scenarios-2026-06-18-232354 (mult=0, vol-stop off).
((name "cell-e-1998-volstop-mult20")
 (description "Cell-E top-3000 PIT-1998 deep, vol-scaled stop ATR-mult 2.0, screen.")
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
   ((laggard_rotation_config ((hysteresis_weeks 2))))
   ((stops_config ((vol_scaled_stop_atr_mult 2.0))))))
 (cost_model ((per_trade_commission 0.0)(per_share_commission 0.01)(bid_ask_spread_bps 0.0)(market_impact_bps_per_pct_adv 0.0)))
 (expected ((total_return_pct ((min -100.0)(max 1000000.0)))(total_trades ((min 0)(max 1000000)))(win_rate ((min 0.0)(max 100.0)))(sharpe_ratio ((min -100.0)(max 100.0)))(max_drawdown_pct ((min 0.0)(max 100.0)))(avg_holding_days ((min 0.0)(max 100000.0))))))
