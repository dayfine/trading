;; P2 — laggard h-sweep on 15y SP500: hysteresis_weeks = 1.
;; Stage3 K=1 fixed, Laggard ON, only hysteresis_weeks varies.
;; 510-sym SP500 historical universe, 15y window (2010-01..2026-04).
((name "laggard-h1-stage3-k1")
 (description
   "15y SP500 — Stage3 ON h=1 + Laggard ON h=1 (most aggressive). h-sweep variant.")
 (period ((start_date 2010-01-01) (end_date 2026-04-30)))
 (universe_path "universes/sp500-historical/sp500-2010-01-01.sexp")
 (universe_size 510)
 (config_overrides
  (((enable_short_side false))
   ((portfolio_config ((max_position_pct_long 0.05))))
   ((portfolio_config ((max_long_exposure_pct 0.50))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 1))))))
 (expected
  ((total_return_pct   ((min -100.0)     (max 500.0)))
   (total_trades       ((min   0)        (max 5000)))
   (win_rate           ((min   0.0)      (max 100.0)))
   (sharpe_ratio       ((min  -2.0)      (max   3.0)))
   (max_drawdown_pct   ((min   0.0)      (max  90.0)))
   (avg_holding_days   ((min   0.0)      (max 500.0)))
   (open_positions_value ((min 0.0)      (max 10000000.0))))))
