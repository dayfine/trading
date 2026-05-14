;; P5 cell 4 of 4 — axis-2 ON (min_correction_pct=0.10), PI filter ON.
;;
;; The critical cell: does turning on the survivorship-aware PI filter
;; rescue the catastrophic 60.1% MaxDD / 26 force-liquidation 16y outcome
;; that PR #1086 measured on survivorship-biased data? If pi-on-axis2's
;; MaxDD collapses materially (e.g. < 30%) and force-liq count drops
;; (≥ 50% reduction), survivorship was a load-bearing factor in the M5.5
;; axis-2 STOP and the verdict needs revisiting. If pi-on-axis2 ≈
;; pi-off-axis2, survivorship is NOT what drove the failure.
((name "p5-pi-on-axis2-2010-2026")
 (description
   "P5 — Cell E 16y long-only + axis-2 (min_correction_pct=0.10), PI filter ON.")
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
   ((stops_config ((min_correction_pct 0.10))))
   ((enable_pi_filter true))))
 (expected
  ((total_return_pct        ((min -50.0)       (max 1500.0)))
   (total_trades            ((min   1)         (max 2000)))
   (win_rate                ((min   0.0)       (max 100.0)))
   (sharpe_ratio            ((min  -2.0)       (max   3.0)))
   (max_drawdown_pct        ((min   0.0)       (max  80.0)))
   (avg_holding_days        ((min   0.0)       (max 300.0)))
   (sortino_ratio_annualized ((min -2.0)       (max   5.0)))
   (calmar_ratio            ((min  -2.0)       (max   3.0)))
   (ulcer_index             ((min   0.0)       (max  50.0)))
   (wall_seconds            ((min   0.0)       (max 3600.0))))))
