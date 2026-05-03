;; M5.4 E4 scoring-weight sweep — volume-heavy (volume confirmation 2x).
;;
;; Sweep cell: w_strong_volume = 40 (default 20, so 2x) and
;; w_adequate_volume = 20 (default 10, so 2x). Tests whether the cascade
;; should weight volume confirmation more — Weinstein Ch. 2 explicitly
;; calls out volume as essential at the breakout, so under-weighting it
;; is a known failure mode.
;;
;; Both volume tiers scale together to preserve the relative ordering
;; between Strong and Adequate volume signals.
;;
;; Other weights left at default. Plan:
;; dev/plans/m5-experiments-roadmap-2026-05-02.md §M5.4 E4.
((name "m5-4-e4-volume-heavy")
 (description "M5.4 E4 sweep: w_strong_volume = 40, w_adequate_volume = 20 (both 2x default)")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 491)
 (config_overrides
  (((screening_config
     ((weights
       ((w_strong_volume 40)
        (w_adequate_volume 20))))))))
 (expected
  ((total_return_pct   ((min -50.0)       (max 150.0)))
   (total_trades       ((min 30)          (max 250)))
   (win_rate           ((min  0.0)        (max 100.0)))
   (sharpe_ratio       ((min -2.0)        (max   3.0)))
   (max_drawdown_pct   ((min  0.0)        (max  60.0)))
   (avg_holding_days   ((min  0.0)        (max 365.0))))))
