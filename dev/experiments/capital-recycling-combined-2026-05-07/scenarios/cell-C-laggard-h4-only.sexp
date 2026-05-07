;; Capital recycling — combined Stage-3 + Laggard impact (5y, 2026-05-07)
;; Cell C — Stage3 OFF, Laggard ON (hysteresis_weeks=4 default).
((name "cell-C-laggard-h4-stage3-off")
 (description "5y SP500 — Stage3 OFF, Laggard ON h=4")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 500)
 (config_overrides
  (((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 4))))))
 (expected
  ((total_return_pct   ((min -100.0)     (max 200.0)))
   (total_trades       ((min   0)        (max 500)))
   (win_rate           ((min   0.0)      (max 100.0)))
   (sharpe_ratio       ((min  -2.0)      (max   3.0)))
   (max_drawdown_pct   ((min   0.0)      (max  90.0)))
   (avg_holding_days   ((min   0.0)      (max 500.0)))
   (open_positions_value ((min 0.0)      (max 5000000.0))))))
