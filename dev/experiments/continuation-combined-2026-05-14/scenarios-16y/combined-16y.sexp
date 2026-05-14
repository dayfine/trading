;; P3 follow-up — combined-axis continuation tuning (16y validation).
;; Same overrides as the 5y combined cell but on the sp500-2010-01-01
;; 510-symbol universe + 2010-2026 horizon.
((name "continuation-combined-16y")
 (description
   "Combined continuation tuning: consolidation_weeks=2 + consolidation_range_pct=0.15. 16y validation on sp500-2010-2026.")
 (period ((start_date 2010-01-01) (end_date 2026-04-30)))
 (universe_path "universes/sp500-historical/sp500-2010-01-01.sexp")
 (universe_size 510)
 (config_overrides
  (((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))
   ((enable_continuation_buys true))
   ((continuation_config ((consolidation_weeks 2) (consolidation_range_pct 0.15))))))
 (expected
  ((total_return_pct        ((min -50.0)       (max 1000.0)))
   (total_trades            ((min 100)         (max 2000)))
   (win_rate                ((min   0.0)       (max 100.0)))
   (sharpe_ratio            ((min  -2.0)       (max   3.0)))
   (max_drawdown_pct        ((min   0.0)       (max 100.0)))
   (avg_holding_days        ((min   1.0)       (max 365.0)))
   (calmar_ratio            ((min  -2.0)       (max   3.0)))
   (sortino_ratio           ((min  -2.0)       (max   3.0)))
   (profit_factor           ((min   0.0)       (max   5.0)))
   (ulcer_index             ((min   0.0)       (max 100.0))))))
