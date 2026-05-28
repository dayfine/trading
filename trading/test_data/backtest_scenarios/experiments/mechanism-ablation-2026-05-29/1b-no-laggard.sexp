;; Mechanism-ablation 1b-no-laggard — DISABLE laggard_rotation runner.
;;
;; The 1b post-mortem (dev/notes/spy-only-fullsize-2026-05-28.md) flagged that
;; 5 of 10 round-trips on the 1-symbol SPY universe were closed by
;; laggard_rotation. On a 1-symbol universe there is NO other candidate to
;; rotate INTO, so laggard exits are functionally "go-to-cash" signals. This
;; ablation tests whether disabling that mechanism allows SPY positions to
;; ride more of each multi-year uptrend.
;;
;; Knob touched: enable_laggard_rotation false (was true)
;; All other 1b knobs unchanged.
((name "1b-no-laggard-spy-only")
 (description "1b - laggard_rotation DISABLED: SPY-only, stage3 still enabled, default stops")
 (period ((start_date 1998-12-22) (end_date 2025-12-31)))
 (universe_path "universes/spy-only.sexp")
 (universe_size 1)
 (config_overrides
  (((portfolio_config ((max_position_pct_long 1.0))))
   ((portfolio_config ((max_long_exposure_pct 1.0))))
   ((portfolio_config ((min_cash_pct 0.0))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation false))))
 (expected
  ((total_return_pct        ((min -90.0)      (max 5000.0)))
   (total_trades            ((min   0)        (max 1000)))
   (win_rate                ((min   0.0)      (max  100.0)))
   (sharpe_ratio            ((min  -2.0)      (max    3.0)))
   (max_drawdown_pct        ((min   0.0)      (max   95.0)))
   (avg_holding_days        ((min   0.0)      (max 5000.0))))))
