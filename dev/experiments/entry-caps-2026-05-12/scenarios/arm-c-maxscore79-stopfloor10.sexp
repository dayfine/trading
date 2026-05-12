;; Entry-caps 3-arm sweep: arm C = max_score_override=79 + initial_stop_pct=0.10.
;; Per the quintile note: Q5 stop_initial_distance ≥18% wins both WR and $/trade,
;; suggesting wider stops let winners run. Move the default 0.08 → 0.10.
((name "entry-caps-15y-arm-c-maxscore79-stopfloor10")
 (description "Cell E 15y + max_score_override=79 + initial_stop_pct=0.10")
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
   ((screening_config ((max_score_override (79)))))
   ((screening_config ((candidate_params ((initial_stop_pct 0.10))))))))
 (expected
  ((total_return_pct   ((min -100.0) (max 1000.0)))
   (total_trades       ((min   0)    (max 10000)))
   (win_rate           ((min   0.0)  (max 100.0)))
   (sharpe_ratio       ((min  -2.0)  (max   3.0)))
   (max_drawdown_pct   ((min   0.0)  (max  90.0)))
   (avg_holding_days   ((min   0.0)  (max 500.0)))
   (open_positions_value ((min 0.0)  (max 5000000.0))))))
