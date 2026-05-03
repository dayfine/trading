;; M5.4 E4 scoring-weight sweep — resistance-heavy (clean overhead 2x).
;;
;; Sweep cell: w_clean_resistance = 30 (default 15, so 2x). Tests whether
;; the cascade should weight clean overhead structure more — virgin
;; territory and clean-resistance breakouts are Weinstein's highest-quality
;; setups (Ch. 3) and the smallest weight in the default. If this sweep
;; cell improves Sharpe, the default underweights breakout cleanliness
;; relative to its predictive power.
;;
;; Other weights left at default. Plan:
;; dev/plans/m5-experiments-roadmap-2026-05-02.md §M5.4 E4.
((name "m5-4-e4-resistance-heavy")
 (description "M5.4 E4 sweep: w_clean_resistance = 30 (2x default)")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 491)
 (config_overrides
  (((screening_config ((weights ((w_clean_resistance 30))))))))
 (expected
  ((total_return_pct   ((min -50.0)       (max 150.0)))
   (total_trades       ((min 30)          (max 250)))
   (win_rate           ((min  0.0)        (max 100.0)))
   (sharpe_ratio       ((min -2.0)        (max   3.0)))
   (max_drawdown_pct   ((min  0.0)        (max  60.0)))
   (avg_holding_days   ((min  0.0)        (max 365.0))))))
