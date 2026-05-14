;; P5 cell 1 of 4 — baseline (axis-2 OFF), PI filter OFF.
;;
;; Twin of goldens-sp500-historical/sp500-2010-2026.sexp (long-only Cell E
;; baseline). Control arm for both the wiring-validation and the
;; survivorship-bias hypothesis.
;;
;; After PR #1094 propagates Daily_price.active_through through the
;; snapshot pipeline, this cell still behaves identically to the legacy
;; baseline because enable_pi_filter defaults to false.
((name "p5-pi-off-baseline-2010-2026")
 (description
   "P5 control — Cell E 16y long-only, axis-2 OFF, PI filter OFF (default).")
 (period ((start_date 2010-01-01) (end_date 2026-04-30)))
 (universe_path "universes/sp500-historical/sp500-2010-01-01.sexp")
 (universe_size 510)
 (config_overrides
  (((enable_short_side false))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (expected
  ((total_return_pct        ((min -50.0)       (max 1000.0)))
   (total_trades            ((min   1)         (max 2000)))
   (win_rate                ((min   0.0)       (max 100.0)))
   (sharpe_ratio            ((min  -2.0)       (max   3.0)))
   (max_drawdown_pct        ((min   0.0)       (max  80.0)))
   (avg_holding_days        ((min   0.0)       (max 300.0)))
   (sortino_ratio_annualized ((min -2.0)       (max   5.0)))
   (calmar_ratio            ((min  -2.0)       (max   3.0)))
   (ulcer_index             ((min   0.0)       (max  50.0)))
   (wall_seconds            ((min   0.0)       (max 3600.0))))))
