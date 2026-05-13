;; M5.5 validation — installed_stop_min_pct = 0.08 overlaid on the 16y
;; long-only sp500-2010-2026 baseline. Twin scenario of
;; goldens-sp500-historical/sp500-2010-2026.sexp; only diff is the appended
;; overlay setting `screening_config.candidate_params.installed_stop_min_pct = 0.08`.
;;
;; Goal: validate whether the M5.5 5y winner (Calmar 0.40 → 0.53 on
;; sp500-2019-2023 per dev/experiments/m5-5-installed-stop-min-pct-2026-05-13/report.md
;; + PR #1079) holds up on the 16y long-only horizon before promoting as a
;; Cell E default.
;;
;; Baseline pin (current main, post-#1063 NAV fix):
;;   total_return_pct  290–393 (measured 307–342%)
;;   sharpe_ratio       0.66–0.90 (measured 0.71–0.78)
;;   max_drawdown_pct  15.6–21.2 (measured 18.4–19.9)
;;   calmar_ratio       0.44–0.59 (measured 0.45–0.52)
;;   avg_holding_days  37.9–51.3 (measured 44.7–46.8)
;;   total_trades      640–800 (measured 683–806)
;;
;; Expected ranges below are intentionally wide (BASELINE_PENDING-style) —
;; this is a discovery cell, not a pin.
((name "m5-5-validation-sp500-2010-2026-installed-stop-0.08")
 (description
   "16y long-only validation of installed_stop_min_pct=0.08 vs sp500-2010-2026 baseline")
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
   ((laggard_rotation_config ((hysteresis_weeks 2))))
   ((screening_config ((candidate_params ((installed_stop_min_pct 0.08))))))))
 (expected
  ((total_return_pct        ((min -50.0)       (max 1500.0)))
   (total_trades            ((min 100)         (max 1500)))
   (win_rate                ((min   0.0)       (max 100.0)))
   (sharpe_ratio            ((min  -2.0)       (max   3.0)))
   (max_drawdown_pct        ((min   0.0)       (max  80.0)))
   (avg_holding_days        ((min   0.0)       (max 200.0)))
   (sortino_ratio_annualized ((min -2.0)       (max   5.0)))
   (calmar_ratio            ((min  -2.0)       (max   3.0)))
   (ulcer_index             ((min   0.0)       (max  50.0)))
   (wall_seconds            ((min   0.0)       (max 3600.0))))))
