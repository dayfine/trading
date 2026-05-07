;; Capital recycling — combined Stage-3 + Laggard impact (5y, 2026-05-07)
;; Cell A — both mechanisms OFF (sanity check; should match pinned 5y baseline).
;;
;; Pinned 5y baseline (sp500-2019-2023, post-#851 + #847):
;;   total_return_pct  58.34   total_trades 81   win_rate 19.75
;;   sharpe_ratio       0.54   max_drawdown 33.60  avg_holding_days 84.10
;;
;; Expected ranges intentionally permissive — this is an experiment, not a
;; regression gate. Cell A is the only cell that should fall inside the
;; pinned baseline; the other cells are off-baseline configurations.
((name "cell-A-both-off")
 (description "5y SP500 — Stage3 OFF, Laggard OFF (sanity baseline)")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 500)
 (config_overrides ())
 (expected
  ((total_return_pct   ((min -100.0)     (max 200.0)))
   (total_trades       ((min   0)        (max 500)))
   (win_rate           ((min   0.0)      (max 100.0)))
   (sharpe_ratio       ((min  -2.0)      (max   3.0)))
   (max_drawdown_pct   ((min   0.0)      (max  90.0)))
   (avg_holding_days   ((min   0.0)      (max 500.0)))
   (open_positions_value ((min 0.0)      (max 5000000.0))))))
