;; M5.5 validation — installed_stop_min_pct = 0.08 overlaid on the 10y
;; decade-2014-2023 baseline. Twin scenario of goldens-broad/decade-2014-2023.sexp;
;; only diff is the appended overlay setting
;; `screening_config.candidate_params.installed_stop_min_pct = 0.08`.
;;
;; Goal: validate whether the M5.5 5y winner (Calmar 0.40 → 0.53 on
;; sp500-2019-2023 per dev/experiments/m5-5-installed-stop-min-pct-2026-05-13/report.md
;; + PR #1079) holds up on the 10y horizon before promoting as a Cell E
;; default.
;;
;; Baseline pin (current main, post-#1063 NAV fix + #1066 re-pin):
;;   total_return_pct  290–410 (measured 343%)
;;   sharpe_ratio       0.50–0.72 (measured 0.60)
;;   max_drawdown_pct  39.4–53.3 (measured 46.4)
;;   calmar_ratio       0.30–0.42 (measured 0.35)
;;   avg_holding_days  35.0–47.0 (measured 40.6)
;;   total_trades      470–636 (measured 552)
;;
;; Expected ranges below are intentionally wide (BASELINE_PENDING-style) —
;; this is a discovery cell, not a pin. The validation report compares
;; the actual measured metrics against the baseline pin above.
((name "m5-5-validation-decade-2014-2023-installed-stop-0.08")
 (description
   "10y validation of installed_stop_min_pct=0.08 vs decade-2014-2023 baseline")
 (period ((start_date 2014-01-02) (end_date 2023-12-29)))
 (universe_path "universes/broad.sexp")
 (universe_size 1000)
 (config_overrides
  (((universe_cap (1000)))
   ((enable_short_side false))
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
