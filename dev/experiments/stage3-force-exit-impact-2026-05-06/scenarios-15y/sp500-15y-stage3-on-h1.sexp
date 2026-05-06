;; Stage-3 force-exit impact experiment (2026-05-06)
;; 15y baseline = sp500-2010-2026-historical with the four #855 overrides preserved,
;; PLUS enable_stage3_force_exit = true, hysteresis_weeks = 1.
;; Pinned baseline (default OFF):
;;   total_return_pct  5.15   total_trades 102   win_rate 21.57
;;   sharpe_ratio      0.40   max_drawdown 16.12  avg_holding_days 130.58
((name "sp500-15y-stage3-on-h1")
 (description "15y SP500 historical + Stage-3 force-exit ON, hysteresis_weeks=1")
 (period ((start_date 2010-01-01) (end_date 2026-04-30)))
 (universe_path "universes/sp500-historical/sp500-2010-01-01.sexp")
 (universe_size 510)
 (config_overrides
  (((enable_short_side false))
   ((portfolio_config ((max_position_pct_long 0.05))))
   ((portfolio_config ((max_long_exposure_pct 0.50))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))))
 (expected
  ((total_return_pct   ((min -100.0)      (max 500.0)))
   (total_trades       ((min   0)         (max 1000)))
   (win_rate           ((min   0.0)       (max 100.0)))
   (sharpe_ratio       ((min  -2.0)       (max   3.0)))
   (max_drawdown_pct   ((min   0.0)       (max  90.0)))
   (avg_holding_days   ((min   0.0)       (max 1000.0)))
   (open_positions_value ((min 0.0)       (max 5000000.0))))))
