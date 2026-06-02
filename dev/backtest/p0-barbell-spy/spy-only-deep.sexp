;; P0 barbell-on-stocks — the FLOOR curve.
;; SPY-only Weinstein investor preset (30wk MA, long/flat), deep window
;; 2000-01-01 → 2026-04-30. This is the drawdown-defense floor leg of the
;; barbell blend against the production stock-selection engine
;; (p0-barbell-prod/production-deep.sexp). Wide research bands — direction-
;; finding, not a pinned golden. See next-session-priorities-2026-06-03.md P0.
((name "spy-only-deep")
 (description "SPY-only Weinstein investor (30wk MA, long/flat) 2000-2026 — barbell FLOOR curve.")
 (period ((start_date 2000-01-01) (end_date 2026-04-30)))
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
