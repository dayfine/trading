;; Mechanism-ablation 2b-no-laggard-wide-stops — combined ablation.
;;
;; Combines 2b-no-laggard + 2b-wide-stops. If either single ablation moves
;; the needle, this composite tests whether they're additive. If the
;; composite still loses to BAH-SPY, both mechanisms together aren't the
;; bind on the sector-ETF surface — pushes the diagnosis upstream to the
;; Stage-2 entry filter / screener.
((name "2b-no-laggard-wide-stops-sector-etf")
 (description "2b - laggard DISABLED + 30%% wide stops: 11 SPDR ETFs, stage3 still enabled")
 (period ((start_date 1998-12-22) (end_date 2025-12-31)))
 (universe_path "universes/spdr-sectors-11.sexp")
 (universe_size 11)
 (config_overrides
  (((portfolio_config ((max_position_pct_long 0.10))))
   ((portfolio_config ((max_long_exposure_pct 1.0))))
   ((portfolio_config ((min_cash_pct 0.0))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation false))
   ((screening_config ((candidate_params ((initial_stop_pct 0.30))))))
   ((screening_config ((candidate_params ((installed_stop_min_pct 0.30))))))
   ((stops_config ((max_stop_distance_pct 0.50))))
   ((stops_config ((min_correction_pct 0.30))))))
 (expected
  ((total_return_pct        ((min -90.0)      (max 5000.0)))
   (total_trades            ((min   0)        (max 5000)))
   (win_rate                ((min   0.0)      (max  100.0)))
   (sharpe_ratio            ((min  -2.0)      (max    3.0)))
   (max_drawdown_pct        ((min   0.0)      (max   95.0)))
   (avg_holding_days        ((min   0.0)      (max 5000.0))))))
