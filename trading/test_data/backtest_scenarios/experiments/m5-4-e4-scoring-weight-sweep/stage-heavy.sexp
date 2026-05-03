;; M5.4 E4 scoring-weight sweep — stage-heavy (Stage1→Stage2 breakout 2x).
;;
;; Sweep cell: w_stage2_breakout = 60 (default 30, so 2x). Tests whether
;; biasing the cascade toward clean stage transitions improves selection
;; quality — Weinstein's most fundamental signal is stage classification,
;; so amplifying its weight should improve picks if the stage classifier
;; is reliable on this universe + window.
;;
;; Note: w_stage2_breakout doubles also doubles the Early-Stage2 sub-bonus
;; (= w_stage2_breakout / 2), so this single override scales both clean
;; and early stage transitions proportionally.
;;
;; Other weights left at default. Plan:
;; dev/plans/m5-experiments-roadmap-2026-05-02.md §M5.4 E4.
((name "m5-4-e4-stage-heavy")
 (description "M5.4 E4 sweep: w_stage2_breakout = 60 (2x default)")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 491)
 (config_overrides
  (((screening_config ((weights ((w_stage2_breakout 60))))))))
 (expected
  ((total_return_pct   ((min -50.0)       (max 150.0)))
   (total_trades       ((min 30)          (max 250)))
   (win_rate           ((min  0.0)        (max 100.0)))
   (sharpe_ratio       ((min -2.0)        (max   3.0)))
   (max_drawdown_pct   ((min  0.0)        (max  60.0)))
   (avg_holding_days   ((min  0.0)        (max 365.0))))))
