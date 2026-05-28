;; Diagnostic 1b — SPY-only with universe-appropriate portfolio params.
;;
;; Sister to 1a (Cell-E defaults; see ../spy-only-diagnostic-2026-05-28/
;; in the parallel agent's run). 1a is expected to be CRIPPLED by Cell-E's
;; portfolio sizing assumptions (max_position=0.14, max_long_exposure=0.70,
;; min_cash=0.30 — sized for 3000-symbol universes — force ~86% idle cash
;; on a 1-symbol universe). 1b lifts those constraints so the Weinstein
;; market-timing signal is tested without throttle.
;;
;; Universe: 1 symbol (SPY) — pure market-timing test.
;; Window: 1998-12-22 → 2025-12-31 (start aligned with first sector-ETF
;;   bar so the BAH-SPY benchmark applies equally to the 2b sector-ETF
;;   diagnostic). Documented deviation from the requesting brief's
;;   1998-01-01 start — SPY itself has data back to 1993, but the matched
;;   start makes 1b vs 2b directly comparable.
;;
;; Portfolio overrides (the "universe-appropriate" patch):
;;   max_position_pct_long = 1.0   (was 0.14)   — allow 100% in SPY
;;   max_long_exposure_pct = 1.0   (was 0.70)   — allow full investment
;;   min_cash_pct          = 0.0   (was 0.30)   — no forced cash buffer
;;
;; All other Cell-E params unchanged (stage3 force-exit h=1, laggard
;; rotation h=2). Expected ranges are intentionally wide — this is a
;; diagnostic-mode run, not a perf gate.
;;
;; Strategic question this run answers: does Weinstein's stage-classifier
;; provide any market-timing alpha when the noise from cross-section is
;; removed? If equity curve cycles in/out of SPY with no edge over
;; BAH-SPY, market-timing is value-neutral and we should stop tuning
;; portfolio knobs.
((name "spy-only-1998-2025-fullsize")
 (description "1b: SPY-only Weinstein 1998-2025, universe-appropriate portfolio (max_pos=1.0, max_exp=1.0, min_cash=0.0)")
 (period ((start_date 1998-12-22) (end_date 2025-12-31)))
 (universe_path "universes/spy-only.sexp")
 (universe_size 1)
 (config_overrides
  (((portfolio_config ((max_position_pct_long 1.0))))
   ((portfolio_config ((max_long_exposure_pct 1.0))))
   ((portfolio_config ((min_cash_pct 0.0))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (expected
  ((total_return_pct        ((min -90.0)      (max 5000.0)))
   (total_trades            ((min   0)        (max 1000)))
   (win_rate                ((min   0.0)      (max  100.0)))
   (sharpe_ratio            ((min  -2.0)      (max    3.0)))
   (max_drawdown_pct        ((min   0.0)      (max   95.0)))
   (avg_holding_days        ((min   0.0)      (max 5000.0))))))
