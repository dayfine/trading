;; M5.4 E4 scoring-weight sweep — sector-heavy (Strong-sector bonus 2x).
;;
;; Sweep cell: w_sector_strong = 20 (default 10, so 2x). Tests whether
;; the cascade should weight sector leadership more — Weinstein Ch. 5
;; argues sector RS is roughly half the picking decision (the other half
;; being individual stock RS). If this sweep cell improves Sharpe, the
;; default treats sector context as noise relative to its actual signal.
;;
;; Note: this is a bonus weight, not a hard gate — the existing sector
;; pre-filter (Strong/Neutral/Weak sector → exclude buys from Weak sectors)
;; is unchanged and runs upstream of the score.
;;
;; Other weights left at default. Plan:
;; dev/plans/m5-experiments-roadmap-2026-05-02.md §M5.4 E4.
((name "m5-4-e4-sector-heavy")
 (description "M5.4 E4 sweep: w_sector_strong = 20 (2x default)")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 491)
 (config_overrides
  (((screening_config ((weights ((w_sector_strong 20))))))))
 (expected
  ((total_return_pct   ((min -50.0)       (max 150.0)))
   (total_trades       ((min 30)          (max 250)))
   (win_rate           ((min  0.0)        (max 100.0)))
   (sharpe_ratio       ((min -2.0)        (max   3.0)))
   (max_drawdown_pct   ((min  0.0)        (max  60.0)))
   (avg_holding_days   ((min  0.0)        (max 365.0))))))
