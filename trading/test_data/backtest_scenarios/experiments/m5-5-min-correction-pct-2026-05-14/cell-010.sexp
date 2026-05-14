;; M5.5 axis-2 sweep cell — stops_config.min_correction_pct = 0.10.
;;
;; Twin of goldens-sp500/sp500-2019-2023-long-only.sexp (Cell E config); only
;; differs by appended overlay setting min_correction_pct. Per
;; dev/notes/p3-tuning-sweep-design-2026-05-13.md (PR #1064), axis #2.
;;
;; Hypothesis: higher min_correction_pct (wider support-floor + stop buffer)
;; suppresses noise stop-outs and lengthens holds relative to the 0.08 default.
((name "m5-5-axis-2-min-correction-pct-010")
 (description "min_correction_pct = 0.10 sweep cell on sp500-2019-2023 long-only")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 503)
 (config_overrides
  (((enable_short_side false))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))
   ((stops_config ((min_correction_pct 0.10))))))
 (expected
  ((total_return_pct        ((min -50.0)       (max 500.0)))
   (total_trades            ((min   1)         (max 1000)))
   (win_rate                ((min   0.0)       (max 100.0)))
   (sharpe_ratio            ((min  -2.0)       (max   3.0)))
   (max_drawdown_pct        ((min   0.0)       (max  80.0)))
   (avg_holding_days        ((min   0.0)       (max 300.0)))
   (sortino_ratio_annualized ((min -2.0)       (max   5.0)))
   (calmar_ratio            ((min  -2.0)       (max   3.0)))
   (ulcer_index             ((min   0.0)       (max  50.0)))
   (wall_seconds            ((min   0.0)       (max 3600.0))))))
