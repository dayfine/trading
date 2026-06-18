;; Cell-E top-3000 PIT-2011, 15y contiguous — fresh post-#1506 run so MFE/MAE
;; (and the decision-grading capture ratio) are populated. Same config as the
;; 2026-06-08 run that the decision-grading lens was first smoke-tested on.
((name "cell-e-top3000-2011-15y-fresh")
 (description "Cell-E top-3000 PIT-2011, 15y contiguous, for decision-grading.")
 (period ((start_date 2011-01-01) (end_date 2026-04-30)))
 (universe_path "workspaces/trading-1/trading/test_data/goldens-custom-universe/composition/top-3000-2011.sexp")
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
 (cost_model ((per_trade_commission 0.0)(per_share_commission 0.01)(bid_ask_spread_bps 0.0)(market_impact_bps_per_pct_adv 0.0)))
 (expected ((total_return_pct ((min -100.0)(max 100000.0)))(total_trades ((min 0)(max 1000000)))(win_rate ((min 0.0)(max 100.0)))(sharpe_ratio ((min -100.0)(max 100.0)))(max_drawdown_pct ((min 0.0)(max 100.0)))(avg_holding_days ((min 0.0)(max 100000.0))))))
