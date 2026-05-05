;; #856 grid sweep cell — max_position_pct_long = 0.07
;;
;; Sweep over {0.07, 0.10, 0.13, 0.16, 0.20} per dev/notes/next-session-priorities-2026-05-05.md.
;; Background: #855 baseline at 0.05 → 5.15% return / 102 trades / 0.40 Sharpe.
;; Acceptance gates: total_return_pct ≥ 50% AND total_trades ∈ [200, 400] AND
;; sharpe_ratio ≥ 0.6 (per #856).
;;
;; All other config matches goldens-sp500-historical/sp500-2010-2026.sexp;
;; only `max_position_pct_long` varies per cell. Note: per qc-behavioral on
;; #855 F1, `max_long_exposure_pct` and `min_cash_pct` are inert under default
;; sizing (per_position dominates, and min_cash_pct has no production caller),
;; so we drop them from the sweep but DO keep `enable_short_side false`.
;;
;; Wide expected ranges intentional — we want raw metrics in actual.sexp, not
;; pass/fail. Per-cell wall ~7-12 min (per #845 Daily_panels O(log N) reads).
((name "sweep-856-cell-007")
 (description
   "#856 grid cell: max_position_pct_long=0.07; 15y sp500 historical (510-sym); base=sp500-2010-2026 fixture")
 (period ((start_date 2010-01-01) (end_date 2026-04-30)))
 (universe_path "universes/sp500-historical/sp500-2010-01-01.sexp")
 (universe_size 510)
 (config_overrides
  (((enable_short_side false))
   ((portfolio_config ((max_position_pct_long 0.07))))))
 (expected
  ((total_return_pct   ((min -100.0)        (max 1000.0)))
   (total_trades       ((min    0)          (max 5000)))
   (win_rate           ((min    0.0)        (max  100.0)))
   (sharpe_ratio       ((min   -5.0)        (max    5.0)))
   (max_drawdown_pct   ((min    0.0)        (max  100.0)))
   (avg_holding_days   ((min    0.0)        (max 5000.0))))))
