;; M5.4 E4 scoring-weight sweep — equal weights across the four major axes.
;;
;; Sweep cell: w_stage2_breakout = w_strong_volume = w_positive_rs =
;; w_clean_resistance = 20 (the median of the four). Tests whether the
;; default's weighting hierarchy (stage > rs ≈ volume > resistance) is a
;; signal or noise: if equal weights produce comparable returns, the
;; relative weighting is not the dominant decision lever and tuning effort
;; should focus elsewhere (grade thresholds, candidate caps, etc.).
;;
;; Other weights (w_adequate_volume, w_bullish_rs_crossover, w_sector_strong,
;; w_late_stage2_penalty) left at default — only the four primary signal
;; weights are equalised.
;;
;; Plan: dev/plans/m5-experiments-roadmap-2026-05-02.md §M5.4 E4.
((name "m5-4-e4-equal-weights")
 (description "M5.4 E4 sweep: equal weights for stage / volume / RS / resistance (all 20)")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 491)
 (config_overrides
  (((screening_config
     ((weights
       ((w_stage2_breakout 20)
        (w_strong_volume 20)
        (w_positive_rs 20)
        (w_clean_resistance 20))))))))
 (expected
  ((total_return_pct   ((min -50.0)       (max 150.0)))
   (total_trades       ((min 30)          (max 250)))
   (win_rate           ((min  0.0)        (max 100.0)))
   (sharpe_ratio       ((min -2.0)        (max   3.0)))
   (max_drawdown_pct   ((min  0.0)        (max  60.0)))
   (avg_holding_days   ((min  0.0)        (max 365.0))))))
