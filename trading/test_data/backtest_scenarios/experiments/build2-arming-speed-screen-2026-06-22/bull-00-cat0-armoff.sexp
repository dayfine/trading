;; Build-2 arming-speed INERT-ELSEWHERE check — no-crash bull 2013-2017.
;; cat=0.0 arm=false. If cat10-armon ≈ baseline here, the stop is dormant in bulls
;; (armed only on Fast_v; no fast-V crash in 2013-2017) = clean tail-insurance.
((name "bull-00-cat0-armoff")
 (description "Build-2 arming-speed inert check: cat=0.0 arm=false, long-only sp500-2015 2013-2017 (no-crash bull).")
 (period ((start_date 2013-01-01) (end_date 2017-12-31)))
 (universe_path "universes/sp500-historical/sp500-2015-01-01.sexp")
 (universe_size 506)
 (config_overrides
  (((enable_short_side false))
   ((fast_v_arm_on_rate_alone false))
   ((stops_config ((catastrophic_stop_pct 0.0))))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (expected ((total_return_pct ((min -90.0) (max 1000.0))) (total_trades ((min 1) (max 5000)))
   (win_rate ((min 0.0) (max 100.0))) (sharpe_ratio ((min -3.0) (max 5.0)))
   (max_drawdown_pct ((min 0.0) (max 90.0))) (avg_holding_days ((min 0.0) (max 800.0)))
   (sortino_ratio_annualized ((min -3.0) (max 10.0))) (calmar_ratio ((min -3.0) (max 5.0)))
   (ulcer_index ((min 0.0) (max 60.0))) (open_positions_value ((min -1.0e12) (max 1.0e12))))))
