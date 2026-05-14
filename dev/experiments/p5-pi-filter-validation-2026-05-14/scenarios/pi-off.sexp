;; PI filter OFF: bit-equal twin of goldens-sp500-historical/sp500-2010-2026.sexp
;; (long-only Cell E baseline). Control arm for the P5 wiring validation.
;; See ../hypothesis.md for the load-bearing caveat about today's snapshot
;; pipeline stripping active_through.
((name "pi-filter-off-2010-2026")
 (description
   "P5 control — Cell E 16y long-only, enable_pi_filter=false (default)")
 (period ((start_date 2010-01-01) (end_date 2026-04-30)))
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
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (expected
  ((total_return_pct   ((min 290.0)         (max 393.0)))
   (total_trades       ((min 640)           (max  800)))
   (win_rate           ((min  33.2)         (max  44.9)))
   (sharpe_ratio       ((min   0.66)        (max   0.90)))
   (max_drawdown_pct   ((min  15.6)         (max  21.2)))
   (avg_holding_days   ((min  37.9)         (max  51.3)))
   (open_positions_value ((min 3400000.0)   (max 4400000.0)))
   (sortino_ratio_annualized ((min  1.06)   (max   1.43)))
   (calmar_ratio       ((min   0.44)        (max   0.59)))
   (ulcer_index        ((min   6.35)        (max   8.60)))
   (wall_seconds       ((min 600.0)         (max 2400.0))))))
