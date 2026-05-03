;; M5.4 E3 stop-buffer sweep — 1.12 (12% beyond suggested stop).
;;
;; Sweep cell: stop_buffer = 1.12 → 12% beyond the suggested level. Upper
;; portion of the book's 5–15% band. The prior recovery-2023 experiment
;; (2026-04-14) showed 1.12 had the highest win rate (54.8%) on a single
;; regime, but the 6-year golden reversed that ordering — see
;; dev/experiments/stop-buffer/report.md.
;;
;; Plan: dev/plans/m5-experiments-roadmap-2026-05-02.md §M5.4 E3.
;; Universe + period mirror the canonical sp500-2019-2023 golden so the
;; sweep is comparable to the pinned baseline (60.86% / 86 trades / 0.55
;; Sharpe / 34.15% MaxDD as of 2026-05-02).
;;
;; Expected ranges are deliberately wide — sweep cells exist to discover
;; behaviour, not to pin it. Re-tighten only if a follow-up experiment
;; promotes a specific cell to the canonical baseline.
((name "m5-4-e3-buffer-1.12")
 (description "M5.4 E3 sweep: initial_stop_buffer = 1.12 (12% beyond suggested stop)")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 491)
 (config_overrides (((initial_stop_buffer 1.12))))
 (expected
  ((total_return_pct   ((min -50.0)       (max 150.0)))
   (total_trades       ((min 30)          (max 250)))
   (win_rate           ((min  0.0)        (max 100.0)))
   (sharpe_ratio       ((min -2.0)        (max   3.0)))
   (max_drawdown_pct   ((min  0.0)        (max  60.0)))
   (avg_holding_days   ((min  0.0)        (max 365.0))))))
