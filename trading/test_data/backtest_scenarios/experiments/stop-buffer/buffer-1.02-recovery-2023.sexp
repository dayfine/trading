;; Stop-buffer experiment: 2% buffer (initial_stop_buffer = 1.02) — control
;; This is the current default. Included as baseline for comparison.
((name "stop-buffer-1.02-recovery-2023")
 (description "Stop buffer 1.02 (2% below support) on 2023 recovery period — control")
 (period ((start_date 2023-01-02) (end_date 2023-12-31)))
 (universe_size 1654)
 (config_overrides (((initial_stop_buffer 1.02))))
 (expected
  ((total_return_pct   ((min -50.0) (max 200.0)))
   (total_trades       ((min 0)     (max 200)))
   (win_rate           ((min 0.0)   (max 100.0)))
   (sharpe_ratio       ((min -5.0)  (max 10.0)))
   (max_drawdown_pct   ((min 0.0)   (max 60.0)))
   (avg_holding_days   ((min 0.0)   (max 365.0))))))
