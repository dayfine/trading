;; Smoke scenario: bullish second half of 2019. Runs quickly (~5-10 min).
;; Ranges are broad sanity checks, not regression gates.
((name "bull-2019h2")
 (description "Bull market sanity check (H2 2019)")
 (period ((start_date 2019-06-01) (end_date 2019-12-31)))
 (universe_size 1654)
 (config_overrides ())
 (expected
  ((total_return_pct   ((min -10.0) (max 40.0)))
   (total_trades       ((min 0)     (max 40)))
   (win_rate           ((min 0.0)   (max 100.0)))
   (sharpe_ratio       ((min -2.0)  (max 5.0)))
   (max_drawdown_pct   ((min 0.0)   (max 30.0)))
   (avg_holding_days   ((min 0.0)   (max 100.0))))))
