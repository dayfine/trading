;; P3 follow-up — anchor: Cell E ship config + continuation-buys ON at ship
;; defaults (consolidation_weeks=4, consolidation_range_pct=0.10).
;; Reproduces PR #1091's baseline cell for delta computation.
((name "continuation-combined-baseline-anchor-5y")
 (description
   "Cell E + continuation-buys ON at ship defaults — 5y sp500-2019-2023 combined-sweep anchor")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 500)
 (config_overrides
  (((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))
   ((enable_continuation_buys true))))
 (expected
  ((total_return_pct        ((min -50.0)       (max 500.0)))
   (total_trades            ((min 100)         (max 600)))
   (win_rate                ((min   0.0)       (max 100.0)))
   (sharpe_ratio            ((min  -2.0)       (max   3.0)))
   (max_drawdown_pct        ((min   0.0)       (max 100.0)))
   (avg_holding_days        ((min   1.0)       (max 365.0)))
   (calmar_ratio            ((min  -2.0)       (max   3.0)))
   (sortino_ratio           ((min  -2.0)       (max   3.0)))
   (profit_factor           ((min   0.0)       (max   5.0)))
   (ulcer_index             ((min   0.0)       (max 100.0))))))
