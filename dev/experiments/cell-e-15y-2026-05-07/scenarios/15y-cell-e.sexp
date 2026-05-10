;; 15y Cell-E headline measurement (2026-05-07).
;;
;; Mirrors `dev/experiments/capital-recycling-combined-2026-05-07/scenarios/
;; cell-E-stage3-k1-laggard-h2.sexp` (5y window, return 120.0% / Sharpe 0.93)
;; but applied to the 15y SP500 historical window
;; (`goldens-sp500-historical/sp500-2010-2026.sexp` — 510-symbol Wiki-replayed
;; survivorship-aware universe). Combines:
;;
;;   - Stage-3 force-exit (K=1 hysteresis)
;;   - Laggard rotation    (h=2 hysteresis, aggressive)
;;   - 15y portfolio-sizing overrides from
;;     goldens-sp500-historical/sp500-2010-2026.sexp (#853 root-cause)
;;     — without these the 15y window's $1M cash + 510-symbol universe
;;     locks up day-1 and produces ~0 trades; per #855 only
;;     max_position_pct_long is the binding knob, but we keep the trio for
;;     parity with the live 15y baseline.
;;
;; Goal: test whether the 5y Cell-E alpha (120.0% return / 196 trades /
;; 33.7% WR / 23.1% MaxDD / Sharpe 0.93) generalises to 15y, or whether
;; capital-recycling alone hits a wall at longer horizons.
;;
;; Wide expected ranges: this is an exploratory headline run; not to be
;; pinned as a golden until we have cause to.
((name "15y-cell-e-stage3-k1-laggard-h2")
 (description
   "15y SP500 — Cell E (Stage3 ON h=1 + Laggard ON h=2, aggressive) on the 510-sym Wiki-replayed historical universe. Position sizing 0.14 / 0.70 / 0.30 — promoted 2026-05-11 as new Cell E default after overnight sweep (dev/notes/overnight-2026-05-10-results.md). 0.14/0.70 wins return + Sharpe in 5/7 rolling 5y windows vs prior 0.05/0.50 default; geom-mean 5y return 41%→50%, avg Sharpe 0.66→0.75, trades cut ~60%.")
 (period ((start_date 2010-01-01) (end_date 2026-04-30)))
 (universe_path "universes/sp500-historical/sp500-2010-01-01.sexp")
 (universe_size 510)
 (config_overrides
  (((enable_short_side false))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (expected
  ((total_return_pct   ((min -100.0)     (max 500.0)))
   (total_trades       ((min   0)        (max 5000)))
   (win_rate           ((min   0.0)      (max 100.0)))
   (sharpe_ratio       ((min  -2.0)      (max   3.0)))
   (max_drawdown_pct   ((min   0.0)      (max  90.0)))
   (avg_holding_days   ((min   0.0)      (max 500.0)))
   (open_positions_value ((min 0.0)      (max 10000000.0))))))
