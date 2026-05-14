;; PI filter ON: 16y long-only Cell E with enable_pi_filter=true.
;;
;; **EXPECTED BEHAVIOUR TODAY**: bit-equal to pi-off because the snapshot
;; pipeline currently strips Daily_price.active_through during the
;; write/reconstitute cycle. Every callback invocation returns true
;; (admit), so the cascade behaves identically to the default path.
;; This cell validates that wiring the seam does not regress the hot path.
;;
;; **EXPECTED BEHAVIOUR POST-P3**: once the snapshot pipeline propagates
;; active_through (see dev/notes/historical-universe-status-2026-05-13.md
;; §1 row P3, NOT STARTED), this cell becomes the survivorship-aware 16y
;; baseline. Headline metrics (MaxDD, force-liq count, total return) may
;; shift materially; the M5.5 axis-2 STOP verdict will be re-evaluated.
;;
;; Expected ranges below mirror pi-off because the gate is a no-op today.
;; Re-pin in a follow-up PR after P3 propagation lands.
((name "pi-filter-on-2010-2026")
 (description
   "P5 treatment — Cell E 16y long-only, enable_pi_filter=true (no-op until P3)")
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
   ((laggard_rotation_config ((hysteresis_weeks 2))))
   ((enable_pi_filter true))))
 (expected
  ((total_return_pct   ((min 290.0)         (max 393.0)))
   (total_trades       ((min 640)           (max  800)))
   (win_rate           ((min  33.2)         (max  44.9)))
   (sharpe_ratio       ((min   0.66)        (max   0.90)))
   (max_drawdown_pct   ((min  15.6)         (max  21.2)))
   (avg_holding_days   ((min  37.9)         (max  51.3)))
   (open_positions_value ((min 3400000.0)   (max 4400000.0)))
   (sortino_ratio_annualized ((min  1.06)   (max   1.43)))
   (calmar_ratio       ((min   0.44)        (max   0.59)))
   (ulcer_index        ((min   6.35)        (max   8.60)))
   (wall_seconds       ((min 600.0)         (max 2400.0))))))
