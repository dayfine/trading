;; First-fold sanity for the continuation-add v2 surface: broad fold-010
;; (2019-12-27..2021-12-25) with the cont_add variant config. Question: do
;; continuation adds emit AND fill (visible as sibling rows in trades.csv
;; post-#1847)? Not a verdict input — a mechanism liveness check.
((name "cont-add-sanity-f010")
 (description "Sanity: broad top-3000 fold-010, full-size entries + Consolidation_breakout adds @ ext 0.25.")
 (period ((start_date 2019-12-27) (end_date 2021-12-25)))
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
   ((scale_in_config ((initial_entry_fraction 1.0)(add_fraction (1.0))(add_trigger Consolidation_breakout)(extension_max_pct 0.25))))))
 (expected ((total_return_pct ((min -100.0)(max 100000.0)))(total_trades ((min 0)(max 1000000)))(win_rate ((min 0.0)(max 100.0)))(sharpe_ratio ((min -100.0)(max 100.0)))(max_drawdown_pct ((min 0.0)(max 100.0)))(avg_holding_days ((min 0.0)(max 100000.0))))))
