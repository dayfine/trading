;; perf-tier: 4
;; perf-tier-rationale: experiment-only scenario for the margin Phase 3
;; validation sweep (issue #859, dev/plans/short-side-margin-2026-05-13.md
;; §Stage A). 2000-03-01 .. 2002-10-31 dot-com bear; requires production
;; data dir for pre-2009 bar coverage. Not part of any nightly tier.
;;
;; This scenario is the margin-ON twin of dotcom-2000-2002-margin-off.sexp.
;; Identical sizing config — only diff is the final
;; ((margin_config ((enabled true)))) override that activates the Phase 1
;; collateral lock + Phase 2 daily borrow fee accrual + maintenance-margin
;; force-cover code paths.
;;
;; See sibling -off.sexp for full context + expected-range rationale.
((name "margin-phase3-dotcom-2000-2002-on")
 (description
   "2000-03-01..2002-10-31 dot-com bear (broad-1000-30y), Cell E config, margin_config.enabled=true (Phase 1+2 wiring active)")
 (period ((start_date 2000-03-01) (end_date 2002-10-31)))
 (universe_path "universes/broad-1000-30y.sexp")
 (universe_size 1000)
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
