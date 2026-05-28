;; Diagnostic 2b — 11 SPDR sector ETFs with universe-appropriate portfolio params.
;;
;; Sister to 2a (Cell-E defaults; parallel agent's run). 2a is partially
;; throttled by Cell-E's 30% forced cash floor and 70% exposure cap. 2b
;; lifts those constraints so the Weinstein sector-rotation signal is
;; tested without throttle.
;;
;; Universe: 11 SPDR sector ETFs (full GICS taxonomy as of 2018).
;;   - 9 ETFs (XLK XLF XLI XLV XLE XLP XLY XLU XLB) have data from 1998-12-22.
;;   - XLRE first bar 2015-10-08 (Real Estate spin-out from XLF).
;;   - XLC first bar 2018-06-19 (Communication Services reshuffle).
;;   [Daily_price.active_through] (PR #1023) skips screening for symbols
;;   before their first bar, so this universe naturally degrades to 9 ETFs
;;   pre-2015 and 10 pre-2018.
;;
;; Window: 1998-12-22 → 2025-12-31, aligned with the 1b SPY-only diagnostic
;; so the shared BAH-SPY benchmark applies to both.
;;
;; Portfolio overrides (universe-appropriate for 11 candidates):
;;   max_position_pct_long = 0.10  (was 0.14)   — ~1/11; allows all held
;;   max_long_exposure_pct = 1.0   (was 0.70)   — allow full investment
;;   min_cash_pct          = 0.0   (was 0.30)   — no forced cash buffer
;;
;; All other Cell-E params unchanged.
;;
;; Strategic question this run answers: layered with 1b (timing-only),
;; does Weinstein extract incremental alpha from sector ROTATION? Diff
;; (2b − 1b) isolates pure sector-rotation alpha. If 2b ties 1b, sector
;; rotation is value-neutral — simplify the screener.
((name "spdr-sectors-1998-2025-fullsize")
 (description "2b: 11 SPDR sector ETFs Weinstein 1998-2025, universe-appropriate portfolio (max_pos=0.10, max_exp=1.0, min_cash=0.0)")
 (period ((start_date 1998-12-22) (end_date 2025-12-31)))
 (universe_path "universes/spdr-sectors-11.sexp")
 (universe_size 11)
 (config_overrides
  (((portfolio_config ((max_position_pct_long 0.10))))
   ((portfolio_config ((max_long_exposure_pct 1.0))))
   ((portfolio_config ((min_cash_pct 0.0))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (expected
  ((total_return_pct        ((min -90.0)      (max 5000.0)))
   (total_trades            ((min   0)        (max 5000)))
   (win_rate                ((min   0.0)      (max  100.0)))
   (sharpe_ratio            ((min  -2.0)      (max    3.0)))
   (max_drawdown_pct        ((min   0.0)      (max   95.0)))
   (avg_holding_days        ((min   0.0)      (max 5000.0))))))
