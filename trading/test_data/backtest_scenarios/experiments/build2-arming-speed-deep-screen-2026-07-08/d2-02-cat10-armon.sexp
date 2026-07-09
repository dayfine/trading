;; Build-2 arming-speed DEEP screen — catastrophic_stop_pct=0.10, fast_v_arm_on_rate_alone=true.
;; Long-only, sp500-2000 PIT universe, 2000-2010 (spans the 2000-02 dot-com grind
;; and the 2008 GFC cascade). Deep companion to
;; experiments/build2-arming-speed-screen-2026-06-22 (which covered the 2020
;; fast-V + 2013-2017 bull); #1708 screened NEEDS-DEEP-DATA there. 364-warmup
;; basis (2026-07-08). CSV mode reads gitignored data/ (deep fetch).
((name "d2-02-cat10-armon")
 (description "Build-2 arming-speed DEEP: catastrophic_stop_pct=0.10, arm-on-rate-alone ON. Long-only sp500-2000 2000-2010.")
 (period ((start_date 2000-01-01) (end_date 2010-12-31)))
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
 (expected
  ((total_return_pct ((min -90.0) (max 5000.0))) (total_trades ((min 1) (max 5000)))
   (win_rate ((min 0.0) (max 100.0))) (sharpe_ratio ((min -3.0) (max 5.0)))
   (max_drawdown_pct ((min 0.0) (max 90.0))) (avg_holding_days ((min 0.0) (max 800.0)))
   (sortino_ratio_annualized ((min -3.0) (max 10.0))) (calmar_ratio ((min -3.0) (max 5.0)))
   (ulcer_index ((min 0.0) (max 60.0))) (open_positions_value ((min -1.0e12) (max 1.0e12))))))
