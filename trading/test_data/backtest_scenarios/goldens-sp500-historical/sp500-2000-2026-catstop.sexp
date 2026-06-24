;; Deep long-only base with catastrophic_stop_pct=0.10 ON, for the Build-2
;; arming-speed (fast_v_arm_on_rate_alone) WF-CV. sp500-as-of-2000 PIT, 2000-2026.
;; The stop is on in BOTH cells; the axis flips arm-on-rate. WF base only (folds
;; drive the period). Reads gitignored data/ (deep 1998-2026).
((name "sp500-2000-2026-catstop-deep")
 (description "Deep long-only + catastrophic_stop_pct=0.10 base for the arming-speed WF-CV.")
 (period ((start_date 2000-01-01) (end_date 2026-04-30)))
 (universe_path "universes/sp500-historical/sp500-2000-01-01.sexp")
 (universe_size 515)
 (config_overrides
  (((enable_short_side false))
   ((stops_config ((catastrophic_stop_pct 0.10))))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (expected ((total_return_pct ((min -90.0) (max 9000.0))) (total_trades ((min 1) (max 9000)))
   (win_rate ((min 0.0) (max 100.0))) (sharpe_ratio ((min -3.0) (max 5.0)))
   (max_drawdown_pct ((min 0.0) (max 90.0))) (avg_holding_days ((min 0.0) (max 800.0)))
   (sortino_ratio_annualized ((min -3.0) (max 10.0))) (calmar_ratio ((min -3.0) (max 5.0)))
   (ulcer_index ((min 0.0) (max 60.0))) (open_positions_value ((min -1.0e12) (max 1.0e12))))))
