;; Forensics: cash-reserve fold-011 (2022 bear window) trade-level trace — r30.
;; Question: what exactly flips r20 to +12.7% while baseline is -10.2% and r30 -15.5%?
((name "cashres-f011-r30")
 (description "Forensics: broad top-3000 fold-011 2021-12-26..2023-12-25, cash-reserve r30.")
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
   ((cash_reserve_pct 0.30))))
 (expected ((total_return_pct ((min -100.0)(max 100000.0)))(total_trades ((min 0)(max 1000000)))(win_rate ((min 0.0)(max 100.0)))(sharpe_ratio ((min -100.0)(max 100.0)))(max_drawdown_pct ((min 0.0)(max 100.0)))(avg_holding_days ((min 0.0)(max 100000.0))))))
