;; Axis 2 — pullback_band width sweep, wide.
;;
;; Widens pullback band from ±5% [0.95, 1.05] to ±8% [0.92, 1.08]. Admits
;; shallower or deeper retracements as "pulled back to the 30-week MA" for
;; §3.(b). Hypothesis: substantially more pullback bars match → more
;; continuation candidates, but quality drops (bars at 1.08 are higher above
;; the MA than the book's narrow textbook proximity intends).
;;
;; All other continuation_config fields remain at Continuation.default_config.
((name "axis2-pullback_band-pm8")
 (description
   "Continuation tuning axis-2: pullback_band=[0.92,1.08] (wide). 5y sp500-2019-2023.")
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
   ((enable_continuation_buys true))
   ((continuation_config ((pullback_band ((low 0.92) (high 1.08))))))))
 (expected
  ((total_return_pct        ((min -50.0)       (max 500.0)))
   (total_trades            ((min 100)         (max 600)))
   (win_rate                ((min   0.0)       (max 100.0)))
   (sharpe_ratio            ((min  -2.0)       (max   3.0)))
   (max_drawdown_pct        ((min   0.0)       (max  80.0)))
   (avg_holding_days        ((min   0.0)       (max 200.0)))
   (sortino_ratio_annualized ((min -2.0)       (max   5.0)))
   (calmar_ratio            ((min  -2.0)       (max   3.0)))
   (ulcer_index             ((min   0.0)       (max  50.0)))
   (wall_seconds            ((min   0.0)       (max 3600.0))))))
