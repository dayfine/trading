;; Capital recycling — combined Stage-3 + Laggard impact (5y, 2026-05-07)
;; Cell B — Stage3 ON (K=1), Laggard OFF.
;; Replicates the #906 5y K=1 winning cell (66.57% / Sharpe 0.62 measured).
((name "cell-B-stage3-k1-laggard-off")
 (description "5y SP500 — Stage3 ON h=1, Laggard OFF")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 500)
 (config_overrides
  (((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))))
 (expected
  ((total_return_pct   ((min -100.0)     (max 200.0)))
   (total_trades       ((min   0)        (max 500)))
   (win_rate           ((min   0.0)      (max 100.0)))
   (sharpe_ratio       ((min  -2.0)      (max   3.0)))
   (max_drawdown_pct   ((min   0.0)      (max  90.0)))
   (avg_holding_days   ((min   0.0)      (max 500.0)))
   (open_positions_value ((min 0.0)      (max 5000000.0))))))
