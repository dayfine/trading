;; perf-tier: 4
;; perf-tier-rationale: experiment-only scenario for the margin Phase 3
;; validation sweep (issue #859, dev/plans/short-side-margin-2026-05-13.md
;; §Stage A). 2022-01-01 .. 2022-10-31 modern bear; runs against
;; sp500-2010-01-01 universe. Not part of any nightly tier.
;;
;; Margin-ON twin of bear-2022-margin-off.sexp. See sibling -off.sexp
;; for full context.
((name "margin-phase3-bear-2022-on")
 (description
   "2022-01-01..2022-10-31 modern bear (sp500-2010-01-01), Cell E config, margin_config.enabled=true (Phase 1+2 wiring active)")
 (period ((start_date 2022-01-01) (end_date 2022-10-31)))
 (universe_path "universes/sp500-historical/sp500-2010-01-01.sexp")
 (universe_size 510)
 (config_overrides
  (((enable_short_side true))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))
   ((margin_config ((enabled true))))))
 (expected
  ((total_return_pct   ((min -99.0)  (max 500.0)))
   (total_trades       ((min   0)    (max 5000)))
   (win_rate           ((min   0.0)  (max 100.0)))
   (sharpe_ratio       ((min  -5.0)  (max   5.0)))
   (max_drawdown_pct   ((min   0.0)  (max  99.0)))
   (avg_holding_days   ((min   0.0)  (max 5000.0))))))
