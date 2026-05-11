;; Entry-caps 3-arm sweep: arm B = max_score_override=79.
;; Per dev/notes/entry-signal-quintiles-2026-05-11.md, Q5 (score >= 80) has
;; 28.6% WR — worst of any quintile. Capping at 79 lets the cascade fall through
;; to the next-best candidates from the still-abundant pool.
((name "entry-caps-15y-arm-b-maxscore79")
 (description "Cell E 15y + max_score_override=79")
 (period ((start_date 2010-01-01) (end_date 2024-12-31)))
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
   ((screening_config ((max_score_override (79)))))))
 (expected
  ((total_return_pct   ((min -100.0) (max 1000.0)))
   (total_trades       ((min   0)    (max 10000)))
   (win_rate           ((min   0.0)  (max 100.0)))
   (sharpe_ratio       ((min  -2.0)  (max   3.0)))
   (max_drawdown_pct   ((min   0.0)  (max  90.0)))
   (avg_holding_days   ((min   0.0)  (max 500.0)))
   (open_positions_value ((min 0.0)  (max 5000000.0))))))
