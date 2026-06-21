;; Barbell promotion grid (2026-06-20) — FLOOR leg, window 2010-2026.
;; SPY-only Weinstein investor preset (30wk MA, long/flat). The drawdown-defense
;; floor leg; blended against each engine cell over the matching window.
((name "floor-2010-bull")
 (description "SPY-only Weinstein (30wk MA, long/flat) 2010-2026 — barbell grid FLOOR (cells B,C window).")
 (period ((start_date 2010-01-01) (end_date 2026-04-30)))
 (universe_path "universes/spy-only.sexp")
 (universe_size 1)
 (config_overrides ())
 (strategy (Spy_only_weinstein (symbol SPY) (ma_period_weeks 30)))
 (expected
  ((total_return_pct  ((min -90.0)  (max 5000.0)))
   (total_trades      ((min   0.0)  (max  200.0)))
   (win_rate          ((min   0.0)  (max  100.0)))
   (sharpe_ratio      ((min  -2.0)  (max    5.0)))
   (max_drawdown_pct  ((min   0.0)  (max   95.0)))
   (avg_holding_days  ((min   0.0)  (max 5000.0)))
   (wall_seconds      ((min   0.1)  (max 3600.0))))))
