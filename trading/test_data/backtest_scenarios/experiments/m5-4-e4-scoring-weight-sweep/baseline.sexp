;; M5.4 E4 scoring-weight sweep — baseline (default weights).
;;
;; Sweep cell: zero overrides — uses Screener.default_scoring_weights
;; (w_stage2_breakout=30, w_strong_volume=20, w_adequate_volume=10,
;; w_positive_rs=20, w_bullish_rs_crossover=10, w_clean_resistance=15,
;; w_sector_strong=10, w_late_stage2_penalty=-15). Control cell within
;; the sweep — should reproduce the canonical sp500-2019-2023 golden
;; (60.86% / 86 trades / 0.55 Sharpe / 34.15% MaxDD as of 2026-05-02).
;;
;; Plan: dev/plans/m5-experiments-roadmap-2026-05-02.md §M5.4 E4.
;; Universe + period mirror the canonical sp500-2019-2023 golden so the
;; sweep is comparable to the pinned baseline.
;;
;; Expected ranges are deliberately wide — sweep cells exist to discover
;; behaviour, not to pin it. Re-tighten only if a follow-up experiment
;; promotes a specific cell to the canonical baseline.
((name "m5-4-e4-baseline")
 (description "M5.4 E4 sweep: default scoring weights (control)")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 491)
 (config_overrides ())
 (expected
  ((total_return_pct   ((min -50.0)       (max 150.0)))
   (total_trades       ((min 30)          (max 250)))
   (win_rate           ((min  0.0)        (max 100.0)))
   (sharpe_ratio       ((min -2.0)        (max   3.0)))
   (max_drawdown_pct   ((min  0.0)        (max  60.0)))
   (avg_holding_days   ((min  0.0)        (max 365.0))))))
