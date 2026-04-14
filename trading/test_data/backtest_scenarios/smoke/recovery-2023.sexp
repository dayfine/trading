;; Smoke scenario: calendar year 2023 recovery. Runs quickly (~5-10 min).
;; Ranges are broad sanity checks, not regression gates.
((name "recovery-2023")
 (description "Recovery regime sanity check (2023)")
 (period ((start_date 2023-01-02) (end_date 2023-12-31)))
 (universe_size 1654)
 (config_overrides ())
 (expected
  ((total_return_pct   ((min -20.0) (max 60.0)))
   (total_trades       ((min 0)     (max 60)))
   (win_rate           ((min 0.0)   (max 100.0)))
   (sharpe_ratio       ((min -2.0)  (max 5.0)))
   (max_drawdown_pct   ((min 0.0)   (max 40.0)))
   (avg_holding_days   ((min 0.0)   (max 100.0))))))
