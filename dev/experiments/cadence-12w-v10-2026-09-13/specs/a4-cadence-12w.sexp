;; Item-4 arm (dev/experiments/cadence-12w-v10-2026-09-13/README.md): the a0-breadth-on-null spec of
;; stop-width-by-state-2026-09-08 with name/description changed and the 09-05 cadence candidate's TWO overrides
;; prepended: initial_stop_buffer 0.9167 (12% initial width) + stop_update_cadence Weekly (sw26y-w12-W lineage).
;; Runs on /tmp/snap_top3000_2000_v10dedup in the pinned worktree sweep-detgate. NOT a golden — staging scenario.
((name "a4-cadence-12w")
 (description "Item 4: 12% initial stop + weekly trail-update cadence (the 09-05 both-window survivor), re-measured on the deduped warehouse against a0-breadth-on-null-s<salt>-v10 at the same salt.")
 (period ((start_date 2000-01-01) (end_date 2026-06-26)))
 (universe_path "../goldens-custom-universe/composition/top-3000-2000.sexp")
 (universe_size 3000)
 ;; entry_order_max_rest_weeks pinned at its pre-promotion value 0
 ;; (unbounded) so this arm stays comparable to the recorded grid1-null
 ;; baseline after the default moved 0 -> 26 (PR #2384). Do not drop this pin.
 (config_overrides
  (((initial_stop_buffer 0.9167)) ((stop_update_cadence Weekly)) ((enable_sim_entry_stoplimit true)) ((entry_order_max_rest_weeks 0))
   ((sim_entry_trigger_at_suggested true))
   ((stop_anchor_at_entry_base true))
   ((entry_extension_max_pct 2.0))
   ((extension_stop_config ((trigger_ratio 2.0) (trail_pct 0.25))))
   ((reject_declining_ma_long_entry true))
   ((enable_short_side false))
   ((stops_config ((catastrophic_stop_pct 0.10))))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))
   ((liquidity_config ((min_entry_dollar_adv 1000000.0))))
   ((liquidity_config ((min_hold_dollar_adv 500000.0))))
   ((stale_exit_after_days (5)))
   ((macro_config ((breadth_direction ((enabled true))))))))
 (expected ((total_return_pct ((min -90.0) (max 90000.0))) (total_trades ((min 1) (max 90000)))
   (win_rate ((min 0.0) (max 100.0))) (sharpe_ratio ((min -3.0) (max 5.0)))
   (max_drawdown_pct ((min 0.0) (max 90.0))) (avg_holding_days ((min 0.0) (max 800.0)))
   (sortino_ratio_annualized ((min -3.0) (max 10.0))) (calmar_ratio ((min -3.0) (max 5.0)))
   (ulcer_index ((min 0.0) (max 60.0))) (open_positions_value ((min -1.0e12) (max 1.0e12))))))
