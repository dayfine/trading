;; Stage-3 force-exit impact experiment (2026-05-06)
;; 5y baseline = sp500-2019-2023 + enable_stage3_force_exit = true, hysteresis_weeks = 3.
((name "sp500-5y-stage3-on-h3")
 (description "5y SP500 + Stage-3 force-exit ON, hysteresis_weeks=3")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 500)
 (config_overrides
  (((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 3))))))
 (expected
  ((total_return_pct   ((min -100.0)     (max 200.0)))
   (total_trades       ((min   0)        (max 500)))
   (win_rate           ((min   0.0)      (max 100.0)))
   (sharpe_ratio       ((min  -2.0)      (max   3.0)))
   (max_drawdown_pct   ((min   0.0)      (max  90.0)))
   (avg_holding_days   ((min   0.0)      (max 500.0)))
   (open_positions_value ((min 0.0)      (max 5000000.0))))))
