;; Stop-buffer experiment: 2% buffer (control) on golden six-year period
((name "stop-buffer-1.02-six-year-2018-2023")
 (description "Stop buffer 1.02 (2% below support, control) on six-year golden period")
 (period ((start_date 2018-01-02) (end_date 2023-12-31)))
 (universe_size 1654)
 (config_overrides (((initial_stop_buffer 1.02))))
 (expected
  ((total_return_pct   ((min -100.0) (max 500.0)))
   (total_trades       ((min 0)     (max 1000)))
   (win_rate           ((min 0.0)   (max 100.0)))
   (sharpe_ratio       ((min -5.0)  (max 10.0)))
   (max_drawdown_pct   ((min 0.0)   (max 80.0)))
   (avg_holding_days   ((min 0.0)   (max 365.0))))))
