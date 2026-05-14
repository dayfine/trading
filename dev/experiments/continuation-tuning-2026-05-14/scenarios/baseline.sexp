;; Baseline arm for the continuation-buys tuning sweep.
;;
;; Cell E + enable_continuation_buys = true at the shipping detector defaults
;; (Continuation.default_config: ma_slope_min=0.01, pullback_band=[0.95,1.05],
;; pullback_lookback_weeks=8, consolidation_range_pct=0.10,
;; consolidation_weeks=4). This is the reference point against which each
;; one-at-a-time cell below is compared.
;;
;; Should reproduce PR #1082 "continuation-buys-on" run (265 trades, 52.15%
;; total return) up to dataset/build pinning.
;;
;; Authority:
;; - dev/notes/next-session-priorities-2026-05-14.md §P3
;; - PR #1078 (Interpretation B detector wiring, default-off)
;; - PR #1082 (sanity sweep — 2 continuation fires / 5y / 500 syms at defaults)
;; - dev/plans/continuation-buys-2026-05-13.md
;; - docs/design/weinstein-book-reference.md §4.6 Continuation Buys (Ch. 3)
((name "continuation-tuning-baseline")
 (description
   "Cell E + continuation-buys ON at ship defaults — 5y sp500-2019-2023 tuning sweep reference")
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
