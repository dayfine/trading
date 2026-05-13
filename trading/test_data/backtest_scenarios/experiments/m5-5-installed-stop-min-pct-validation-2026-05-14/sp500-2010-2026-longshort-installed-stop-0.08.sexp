;; M5.5 validation — installed_stop_min_pct = 0.08 overlaid on the 16y
;; long-short sp500-2010-2026-longshort baseline. Twin scenario of
;; goldens-sp500-historical/sp500-2010-2026-longshort.sexp; only diff is the
;; appended overlay setting
;; `screening_config.candidate_params.installed_stop_min_pct = 0.08`.
;;
;; Goal: validate whether the M5.5 5y winner (Calmar 0.40 → 0.53 on
;; sp500-2019-2023 per dev/experiments/m5-5-installed-stop-min-pct-2026-05-13/report.md
;; + PR #1079) holds up on the 16y long-short horizon before promoting as a
;; Cell E default. Long-short adds short-side primitives (G1–G9); the
;; floor on installed stops applies to long candidates only — confirm the
;; lever doesn't degrade the long-short cell's Calmar.
;;
;; Baseline pin (current main, post-#1063 NAV fix):
;;   total_return_pct  260–360 (measured 262–316%)
;;   sharpe_ratio       0.56–0.82 (measured 0.66–0.70)
;;   max_drawdown_pct  17.0–24.6 (measured 19.8–21.4)
;;   calmar_ratio       0.36–0.52 (measured 0.38–0.46)
;;   avg_holding_days  37.7–51.1 (measured 44.4–46.6)
;;   total_trades      640–800 (measured 708–832)
;;
;; Expected ranges below are intentionally wide (BASELINE_PENDING-style) —
;; this is a discovery cell, not a pin.
((name "m5-5-validation-sp500-2010-2026-longshort-installed-stop-0.08")
 (description
   "16y long-short validation of installed_stop_min_pct=0.08 vs sp500-2010-2026-longshort baseline")
 (period ((start_date 2010-01-01) (end_date 2026-04-30)))
 (universe_path "universes/sp500-historical/sp500-2010-01-01.sexp")
 (universe_size 510)
 (config_overrides
  (((enable_short_side true))
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
