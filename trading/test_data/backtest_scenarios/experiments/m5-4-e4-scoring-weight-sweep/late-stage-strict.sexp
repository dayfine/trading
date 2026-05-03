;; M5.4 E4 scoring-weight sweep — late-Stage2 penalty 2x harsher.
;;
;; Sweep cell: w_late_stage2_penalty = -30 (default -15, so 2x more
;; negative). Tests whether the cascade should penalise late-Stage2
;; entries more — Weinstein Ch. 7 warns that late-Stage2 pyramiding /
;; chasing yields the worst risk/reward in the long-side space; the
;; current default may be too gentle, allowing the cascade to grade C+
;; setups that should fall below the cut.
;;
;; This is the only "negative-direction" cell in the grid — every other
;; cell amplifies a positive signal weight. Doubling the penalty tests
;; the symmetric question: does down-weighting bad setups matter as much
;; as up-weighting good ones?
;;
;; Other weights left at default. Plan:
;; dev/plans/m5-experiments-roadmap-2026-05-02.md §M5.4 E4.
((name "m5-4-e4-late-stage-strict")
 (description "M5.4 E4 sweep: w_late_stage2_penalty = -30 (2x harsher)")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 491)
 (config_overrides
  (((screening_config ((weights ((w_late_stage2_penalty -30))))))))
 (expected
  ((total_return_pct   ((min -50.0)       (max 150.0)))
   (total_trades       ((min 30)          (max 250)))
   (win_rate           ((min  0.0)        (max 100.0)))
   (sharpe_ratio       ((min -2.0)        (max   3.0)))
   (max_drawdown_pct   ((min  0.0)        (max  60.0)))
   (avg_holding_days   ((min  0.0)        (max 365.0))))))
