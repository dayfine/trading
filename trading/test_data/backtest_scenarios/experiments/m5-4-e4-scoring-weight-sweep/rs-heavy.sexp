;; M5.4 E4 scoring-weight sweep — RS-heavy (relative strength 2x).
;;
;; Sweep cell: w_positive_rs = 40 (default 20, so 2x) and
;; w_bullish_rs_crossover = 20 (default 10, so 2x). Tests whether the
;; cascade should weight relative-strength leadership more — Weinstein
;; Ch. 4 stresses RS as the primary leading indicator, and prior work
;; (`dev/notes/sp500-trade-quality-findings-2026-04-30.md`) flagged that
;; the RS hard gate is doing meaningful filtering on the short side; the
;; long-side RS weight may be similarly under-leveraged.
;;
;; Both RS levers (steady positive trend + bullish crossover) scale
;; together to preserve their relative ordering.
;;
;; Other weights left at default. Plan:
;; dev/plans/m5-experiments-roadmap-2026-05-02.md §M5.4 E4.
((name "m5-4-e4-rs-heavy")
 (description "M5.4 E4 sweep: w_positive_rs = 40, w_bullish_rs_crossover = 20 (both 2x default)")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 491)
 (config_overrides
  (((screening_config
     ((weights
       ((w_positive_rs 40)
        (w_bullish_rs_crossover 20))))))))
 (expected
  ((total_return_pct   ((min -50.0)       (max 150.0)))
   (total_trades       ((min 30)          (max 250)))
   (win_rate           ((min  0.0)        (max 100.0)))
   (sharpe_ratio       ((min -2.0)        (max   3.0)))
   (max_drawdown_pct   ((min  0.0)        (max  60.0)))
   (avg_holding_days   ((min  0.0)        (max 365.0))))))
