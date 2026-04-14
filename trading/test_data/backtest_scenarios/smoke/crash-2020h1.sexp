;; Smoke scenario: first half of 2020 (COVID crash). Runs quickly (~5-10 min).
;; Ranges are broad sanity checks, not regression gates.
((name "crash-2020h1")
 (description "Crash regime sanity check (H1 2020)")
 (period ((start_date 2020-01-02) (end_date 2020-06-30)))
 (universe_size 1654)
 (config_overrides ())
 (expected
  ((total_return_pct   ((min -40.0) (max 20.0)))
   (total_trades       ((min 0)     (max 50)))
   (win_rate           ((min 0.0)   (max 100.0)))
   (sharpe_ratio       ((min -5.0)  (max 3.0)))
   (max_drawdown_pct   ((min 0.0)   (max 60.0)))
   (avg_holding_days   ((min 0.0)   (max 100.0))))))
