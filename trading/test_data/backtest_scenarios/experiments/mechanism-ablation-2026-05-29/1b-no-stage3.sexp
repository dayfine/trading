;; Mechanism-ablation 1b-no-stage3 — DISABLE stage3_force_exit runner.
;;
;; Tests whether the Stage-3 force-exit fires too eagerly on mid-cycle
;; consolidations. The 1b post-mortem reported 0 explicit stage3-tagged exits
;; among the 10 trades but the cascade still computes Stage-3 transitions
;; for held symbols at every screening tick; force-exiting on Stage-3 entry
;; with hysteresis_weeks=1 can flip on/off rapidly during routine SPY
;; consolidations.
;;
;; Knob touched: enable_stage3_force_exit false (was true)
;; All other 1b knobs unchanged.
((name "1b-no-stage3-spy-only")
 (description "1b - stage3_force_exit DISABLED: SPY-only, laggard still enabled, default stops")
 (period ((start_date 1998-12-22) (end_date 2025-12-31)))
 (universe_path "universes/spy-only.sexp")
 (universe_size 1)
 (config_overrides
  (((portfolio_config ((max_position_pct_long 1.0))))
   ((portfolio_config ((max_long_exposure_pct 1.0))))
   ((portfolio_config ((min_cash_pct 0.0))))
   ((enable_stage3_force_exit false))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (expected
  ((total_return_pct        ((min -90.0)      (max 5000.0)))
   (total_trades            ((min   0)        (max 1000)))
   (win_rate                ((min   0.0)      (max  100.0)))
   (sharpe_ratio            ((min  -2.0)      (max    3.0)))
   (max_drawdown_pct        ((min   0.0)      (max   95.0)))
   (avg_holding_days        ((min   0.0)      (max 5000.0))))))
