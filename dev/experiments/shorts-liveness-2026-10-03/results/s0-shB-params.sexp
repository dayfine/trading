((code_version 29e81f8881d5360459f313f77b169f4899e77519)
 (start_date 2007-06-01) (end_date 2012-06-29) (initial_cash 1000000.00)
 (universe_size 4192)
 (data_dir
  /workspaces/trading-1/.claude/worktrees/sweep-shorts/trading/test_data)
 (commission ((per_share 0.01) (minimum 1.00)))
 (overrides
  (((enable_sim_entry_stoplimit true))
   ((sim_entry_trigger_at_suggested true))
   ((sim_entry_stoplimit_fresh_bar_only true))
   ((sim_stop_exit_fill_on_trigger_bar true))
   ((stop_anchor_at_entry_base true)) ((entry_extension_max_pct 2.0))
   ((reject_declining_ma_long_entry true)) ((enable_short_side true))
   ((neutral_blocks_shorts true)) ((enable_slow_grind_short_gate true))
   ((short_min_price 17.0)) ((short_borrow_min_dollar_adv 1000000.0))
   ((margin_config ((enabled true))))
   ((margin_config ((maintenance_margin_pct 0.30))))
   ((margin_config
     ((short_borrow_rate_tiers
       (((price_below 5.0) (value 1.00)) ((price_below 17.0) (value 0.25)))))))
   ((margin_config
     ((short_maintenance_tiers
       (((price_below 5.0) (value 1.00)) ((price_below 17.0) (value 0.83)))))))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))
   ((liquidity_config ((min_entry_dollar_adv 1000000.0))))
   ((liquidity_config ((min_hold_dollar_adv 500000.0))))
   ((stale_exit_after_days (5)))
   ((macro_config ((breadth_direction ((enabled true))))))
   ((require_structural_stop true)) ((max_one_share_class_per_issuer true)))))
