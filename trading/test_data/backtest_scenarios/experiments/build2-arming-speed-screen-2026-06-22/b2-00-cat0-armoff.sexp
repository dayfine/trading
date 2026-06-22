;; Build-2 arming-speed screen — catastrophic_stop_pct=0.0, fast_v_arm_on_rate_alone=false.
;; Long-only, sp500-2015 universe, 2018-2021 (spans the 2020 fast-V). Tests whether
;; arming Fast_v on rate-alone (#1708) lets the catastrophic stop fire BEFORE the
;; structural gap-down in the 2020-V. CSV mode reads gitignored data/ (deep fetch).
((name "b2-00-cat0-armoff")
 (description "Build-2 arming-speed: catastrophic_stop_pct=0.0 fast_v_arm_on_rate_alone=false, long-only sp500-2015 2018-2021.")
 (period ((start_date 2018-01-01) (end_date 2021-12-31)))
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
 (expected
  ((total_return_pct ((min -90.0) (max 1000.0))) (total_trades ((min 1) (max 5000)))
   (win_rate ((min 0.0) (max 100.0))) (sharpe_ratio ((min -3.0) (max 5.0)))
   (max_drawdown_pct ((min 0.0) (max 90.0))) (avg_holding_days ((min 0.0) (max 800.0)))
   (sortino_ratio_annualized ((min -3.0) (max 10.0))) (calmar_ratio ((min -3.0) (max 5.0)))
   (ulcer_index ((min 0.0) (max 60.0))) (open_positions_value ((min -1.0e12) (max 1.0e12))))))
