;; longonly A-D-live full window 1999-2026 (sp500-2000 PIT). skip_ad_breadth=false,
;; enable_short_side=false. Build-0 A-D-default-flip evidence (see
;; dev/backtest/ad-default-fullwindow-2026-06-22/FINDINGS.md). Reads data/ breadth.
((name "longonly-adlive")
 (description "longonly A-D-live (skip_ad_breadth=false enable_short_side=false), sp500-2000 PIT, 1999-2026.")
 (period ((start_date 1999-01-01) (end_date 2026-04-30)))
 (universe_path "universes/sp500-historical/sp500-2000-01-01.sexp")
 (universe_size 515)
 (config_overrides
  (((enable_short_side false))
   ((skip_ad_breadth false))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (expected ((total_return_pct ((min -90.0) (max 90000.0))) (total_trades ((min 1) (max 99000)))
   (win_rate ((min 0.0) (max 100.0))) (sharpe_ratio ((min -3.0) (max 5.0)))
   (max_drawdown_pct ((min 0.0) (max 90.0))) (avg_holding_days ((min 0.0) (max 800.0)))
   (sortino_ratio_annualized ((min -3.0) (max 10.0))) (calmar_ratio ((min -3.0) (max 5.0)))
   (ulcer_index ((min 0.0) (max 60.0))) (open_positions_value ((min -1.0e12) (max 1.0e12))))))
