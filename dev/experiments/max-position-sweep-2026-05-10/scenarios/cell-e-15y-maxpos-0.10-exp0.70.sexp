;; Cell E h=2 sweep B: 0.10 / 0.70 / 0.30 → ~7 max positions, 70% long, 0% idle.
;; B-series raises max_long_exposure_pct to absorb the cash that A-series
;; leaves idle. Tests concentration with full deployable-cash utilization.
((name "cell-e-15y-maxpos-0.10-exp0.70")
 (description "Cell E h=2 — 15y — 0.10 pos / 0.70 long exposure (~7 positions, 0% idle)")
 (period ((start_date 2010-01-01) (end_date 2024-12-31)))
 (universe_path "universes/sp500-historical/sp500-2010-01-01.sexp")
 (universe_size 510)
 (config_overrides
  (((enable_short_side false))
   ((portfolio_config ((max_position_pct_long 0.10))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (expected
  ((total_return_pct   ((min -100.0) (max 1000.0)))
   (total_trades       ((min   0)    (max 10000)))
   (win_rate           ((min   0.0)  (max 100.0)))
   (sharpe_ratio       ((min  -2.0)  (max   3.0)))
   (max_drawdown_pct   ((min   0.0)  (max  90.0)))
   (avg_holding_days   ((min   0.0)  (max 500.0)))
   (open_positions_value ((min 0.0)  (max 5000000.0))))))
