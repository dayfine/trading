;; Mechanism-ablation 2b-no-laggard — DISABLE laggard_rotation on 11 ETFs.
;;
;; On the 11-ETF universe laggard_rotation has actual cross-sectional content
;; (it can rotate out of an underperforming ETF into a stronger one).
;; The 2b post-mortem reported 47% of exits were laggard-rotation; this
;; ablation tests whether that churn is net-negative.
((name "2b-no-laggard-sector-etf")
 (description "2b - laggard_rotation DISABLED: 11 SPDR ETFs, stage3 still enabled")
 (period ((start_date 1998-12-22) (end_date 2025-12-31)))
 (universe_path "universes/spdr-sectors-11.sexp")
 (universe_size 11)
 (config_overrides
  (((portfolio_config ((max_position_pct_long 0.10))))
   ((portfolio_config ((max_long_exposure_pct 1.0))))
   ((portfolio_config ((min_cash_pct 0.0))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation false))))
 (expected
  ((total_return_pct        ((min -90.0)      (max 5000.0)))
   (total_trades            ((min   0)        (max 5000)))
   (win_rate                ((min   0.0)      (max  100.0)))
   (sharpe_ratio            ((min  -2.0)      (max    3.0)))
   (max_drawdown_pct        ((min   0.0)      (max   95.0)))
   (avg_holding_days        ((min   0.0)      (max 5000.0))))))
