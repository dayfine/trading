;; Barbell promotion grid (2026-06-20) — ENGINE leg, Cell A.
;; Full-history cell (the "ACCEPT" cell): Cell-E production Weinstein on PIT
;; S&P 500 as-of 2000-01-01, window 2000-2026 (spans dotcom bust + GFC =
;; bear-dominated macro regime per promotion-confirmation.md). Config identical
;; to the recovered p0-barbell-prod/production-deep.sexp.
((name "engineA-sp500_2000-deep")
 (description "Cell-E engine, SP500 PIT-2000, 2000-2026 — barbell grid cell A (full history, bear-macro).")
 (period ((start_date 2000-01-01) (end_date 2026-04-30)))
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
  ((total_return_pct  ((min -90.0)  (max 100000.0)))
   (total_trades      ((min   0.0)  (max 100000.0)))
   (win_rate          ((min   0.0)  (max  100.0)))
   (sharpe_ratio      ((min  -2.0)  (max    5.0)))
   (max_drawdown_pct  ((min   0.0)  (max   95.0)))
   (avg_holding_days  ((min   0.0)  (max 5000.0)))
   (wall_seconds      ((min   1.0)  (max 360000.0))))))
