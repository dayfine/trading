;; Deep long-only base: catastrophic_stop_pct=0.10 + fast_v_arm_on_rate_alone=true,
;; for the fast_v_min_rate_pct THRESHOLD SURFACE WF-CV. The arming knob is ON; the
;; axis sweeps the arming rate threshold to suppress the 2010/2011 whipsaw the
;; arming-speed WF-CV found. sp500-as-of-2000 PIT, 2000-2026. Reads data/.
((name "sp500-2000-2026-catstop-armon-deep")
 (description "Deep long-only + cat_stop 0.10 + arm_on_rate=true base for the fast_v_min_rate_pct surface.")
 (period ((start_date 2000-01-01) (end_date 2026-04-30)))
 (universe_path "universes/sp500-historical/sp500-2000-01-01.sexp")
 (universe_size 515)
 (config_overrides
  (((enable_short_side false))
   ((fast_v_arm_on_rate_alone true))
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
