;; Cell E generalization — 6y small-universe COVID-crash window.
;; Baseline (cell-A) at six-year-2018-2023-cell-A.sexp.
;; Cell E config: Stage3 force-exit ON (k=1) + Laggard rotation ON (h=2 aggressive).
;; Hypothesis: Cell E's 5y SP500 win (120% / 0.93 Sharpe vs 58% / 0.54 baseline)
;; generalizes to 6y small universe over the 2018-2023 window.

((name "six-year-2018-2023-cell-E")
 (description "6y small-universe Cell E (Stage3 + Laggard h=2)")
 (period ((start_date 2018-01-02) (end_date 2023-12-29)))
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
