;; #856 grid sweep cell — max_position_pct_long = 0.10
;; See cell-007.sexp for sweep context.
((name "sweep-856-cell-010")
 (description
   "#856 grid cell: max_position_pct_long=0.10; 15y sp500 historical (510-sym); base=sp500-2010-2026 fixture")
 (period ((start_date 2010-01-01) (end_date 2026-04-30)))
 (universe_path "universes/sp500-historical/sp500-2010-01-01.sexp")
 (universe_size 510)
 (config_overrides
  (((enable_short_side false))
   ((portfolio_config ((max_position_pct_long 0.10))))))
 (expected
  ((total_return_pct   ((min -100.0)        (max 1000.0)))
   (total_trades       ((min    0)          (max 5000)))
   (win_rate           ((min    0.0)        (max  100.0)))
   (sharpe_ratio       ((min   -5.0)        (max    5.0)))
   (max_drawdown_pct   ((min    0.0)        (max  100.0)))
   (avg_holding_days   ((min    0.0)        (max 5000.0))))))
