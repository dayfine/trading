;; M5.4 E3 stop-buffer sweep — 1.20 (20% beyond suggested stop; out-of-band).
;;
;; Sweep cell: stop_buffer = 1.20 → 20% beyond the suggested level. Past
;; the book's 5–15% upper bound; included as the right-tail control to
;; characterise behaviour past the recommended range. Expect monotone
;; drop-off in win rate vs the 1.10–1.15 cells if the book's guidance
;; holds.
;;
;; Plan: dev/plans/m5-experiments-roadmap-2026-05-02.md §M5.4 E3.
;; Universe + period mirror the canonical sp500-2019-2023 golden so the
;; sweep is comparable to the pinned baseline (60.86% / 86 trades / 0.55
;; Sharpe / 34.15% MaxDD as of 2026-05-02).
;;
;; Expected ranges are deliberately wide — sweep cells exist to discover
;; behaviour, not to pin it. Re-tighten only if a follow-up experiment
;; promotes a specific cell to the canonical baseline.
((name "m5-4-e3-buffer-1.20")
 (description "M5.4 E3 sweep: initial_stop_buffer = 1.20 (20% beyond suggested stop; out-of-band)")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 491)
 (config_overrides (((initial_stop_buffer 1.20))))
 (expected
  ((total_return_pct   ((min -50.0)       (max 150.0)))
   (total_trades       ((min 30)          (max 250)))
   (win_rate           ((min  0.0)        (max 100.0)))
   (sharpe_ratio       ((min -2.0)        (max   3.0)))
   (max_drawdown_pct   ((min  0.0)        (max  60.0)))
   (avg_holding_days   ((min  0.0)        (max 365.0))))))
