;; Cell E generalization — 5y small-universe bull-crash window.
;; Baseline (cell-A) at bull-crash-2015-2020-cell-A.sexp.
;; Cell E config: Stage3 force-exit ON (k=1) + Laggard rotation ON (h=2).

((name "bull-crash-2015-2020-cell-E")
 (description "5y small-universe Cell E (Stage3 + Laggard h=2)")
 (period ((start_date 2015-01-02) (end_date 2020-12-31)))
 (universe_size 302)
 (config_overrides
  (((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (expected
  ((total_return_pct   ((min -50.0) (max 400.0)))
   (total_trades       ((min   5)   (max 800)))
   (win_rate           ((min   0.0) (max 100.0)))
   (sharpe_ratio       ((min  -2.0) (max   3.0)))
   (max_drawdown_pct   ((min   0.0) (max  90.0)))
   (avg_holding_days   ((min   0.0) (max 500.0)))
   (open_positions_value ((min 0.0) (max 5000000.0))))))
