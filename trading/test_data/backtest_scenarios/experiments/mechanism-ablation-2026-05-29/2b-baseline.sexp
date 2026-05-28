;; Mechanism-ablation 2b-baseline — reproduces canonical 2b sector-ETF fullsize.
;;
;; Universe: 11 SPDR sector ETFs.
;; Window: 1998-12-22 → 2025-12-31.
;; Portfolio: max_position=0.10, max_long_exposure=1.0, min_cash=0.0.
;;
;; Expected (prior run): +7.43% total / 193 trades / 0.27% CAGR /
;;   7.31% MaxDD — see dev/notes/sector-etf-fullsize-2026-05-28.md.
((name "2b-baseline-sector-etf")
 (description "Mechanism-ablation 2b baseline: 11 SPDR ETFs, Cell-E mechanisms")
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
