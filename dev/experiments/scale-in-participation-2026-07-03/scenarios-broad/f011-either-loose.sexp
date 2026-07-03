;; Participation-effect measurement (P0, next-session-priorities-2026-07-03):
;; broad top-3000 fold-011 (2021-12-26..2023-12-25), variant either-loose.
;; Mirrors base_top3000.sexp overrides (production caps + catstop 0.10).
((name "part-broad-f011-either-loose")
 (description "Participation measurement: broad top-3000 fold-011 (2021-12-26..2023-12-25), either-loose.")
 (period ((start_date 2021-12-26) (end_date 2023-12-25)))
 (universe_path "../goldens-custom-universe/composition/top-3000-2000.sexp")
 (universe_size 3000)
 (config_overrides
  (((enable_short_side false))
   ((stops_config ((catastrophic_stop_pct 0.10))))
   ((portfolio_config ((max_position_pct_long 0.30))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))
   ((enable_scale_in true))
   ((scale_in_config ((initial_entry_fraction 0.5)(add_trigger Either)(extension_max_pct 0.25))))))
 (expected ((total_return_pct ((min -100.0)(max 100000.0)))(total_trades ((min 0)(max 1000000)))(win_rate ((min 0.0)(max 100.0)))(sharpe_ratio ((min -100.0)(max 100.0)))(max_drawdown_pct ((min 0.0)(max 100.0)))(avg_holding_days ((min 0.0)(max 100000.0))))))
