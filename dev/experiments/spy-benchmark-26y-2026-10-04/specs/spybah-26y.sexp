;; Benchmark for the 26y investor baseline window (user decision 2026-10-04:
;; rerun the SPY 30-week-MA reference on the current build as a benchmark).
((name "spybah-26y")
 (description "Buy-and-hold SPY, 2000-01-01 to 2026-06-26, same window as inv26sc-investor.")
 (period ((start_date 2000-01-01) (end_date 2026-06-26)))
 (universe_path "universes/spy-only.sexp")
 (universe_size 1)
 (config_overrides ())
 (strategy (Bah_benchmark (symbol SPY)))
 (expected
  ((total_return_pct       ((min -90.0)    (max 5000.0)))
   (total_trades           ((min   0.0)    (max  200.0)))
   (win_rate               ((min   0.0)    (max  100.0)))
   (sharpe_ratio           ((min  -2.0)    (max    5.0)))
   (max_drawdown_pct       ((min   0.0)    (max   95.0)))
   (avg_holding_days       ((min   0.0)    (max 10000.0)))
   (wall_seconds           ((min   0.5)    (max 3600.0))))))
