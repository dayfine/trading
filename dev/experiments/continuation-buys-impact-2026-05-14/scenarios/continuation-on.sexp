;; Treatment: Cell E config on 5y sp500-2019-2023, continuation buys ON.
;; Single-knob overlay vs `baseline.sexp` — flips
;; `enable_continuation_buys = true`. All other config (continuation
;; detector defaults from Continuation.default_config: ma_slope_min=0.01,
;; pullback_band=[0.95,1.05], pullback_lookback_weeks=8,
;; consolidation_range_pct=0.10, consolidation_weeks=4) is left at the
;; ship default per task instructions.
;;
;; Authority: PR #1078 (default-off implementation), PR #1074 (design
;; plan), issue #889, docs/design/weinstein-book-reference.md §4.6.
((name "continuation-buys-on")
 (description
   "Cell E + enable_continuation_buys=true — 5y sp500-2019-2023 treatment arm")
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
   (max_drawdown_pct        ((min   0.0)       (max  80.0)))
   (avg_holding_days        ((min   0.0)       (max 200.0)))
   (sortino_ratio_annualized ((min -2.0)       (max   5.0)))
   (calmar_ratio            ((min  -2.0)       (max   3.0)))
   (ulcer_index             ((min   0.0)       (max  50.0)))
   (wall_seconds            ((min   0.0)       (max 3600.0))))))
