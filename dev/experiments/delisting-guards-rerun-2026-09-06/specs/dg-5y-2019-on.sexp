;; #2672 paired re-run, 2019 window (2019-01-02..2023-12-29) on the 2019-VINTAGE
;; warehouse /tmp/snap_top3000_2019 (top-3000-2019 PIT composition; DTV/ABK present).
;; Config = the record convention (rec26y-new lineage) with the period/universe swapped;
;; arm on = the three #2672 guards ON (entry_max_bar_age_days 10, stale_exit_without_prior_bar true, stub_print_max_ratio 0.05). Salt 0. NOT a golden — staging scenario.
((name "dg-5y-2019-on")
 (description "#2672 paired re-run: record convention on the delisting-guards build; arm = guards OFF (default) vs ON")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "../goldens-custom-universe/composition/top-3000-2019.sexp")
 (universe_size 3000)
 ;; entry_order_max_rest_weeks pinned at its pre-promotion value 0
 ;; (unbounded) so this arm stays comparable to the recorded grid1-null
 ;; baseline after the default moved 0 -> 26 (PR #2384). Do not drop this pin.
 (config_overrides
  (((enable_sim_entry_stoplimit true)) ((entry_order_max_rest_weeks 0))
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
   ;; #2672 guards ON (names finalised from the merged PR)
   ((entry_max_bar_age_days 10))
   ((stale_exit_without_prior_bar true))
   ((stub_print_max_ratio 0.05))))
 (expected ((total_return_pct ((min -90.0) (max 90000.0))) (total_trades ((min 1) (max 90000)))
   (win_rate ((min 0.0) (max 100.0))) (sharpe_ratio ((min -3.0) (max 5.0)))
   (max_drawdown_pct ((min 0.0) (max 90.0))) (avg_holding_days ((min 0.0) (max 800.0)))
   (sortino_ratio_annualized ((min -3.0) (max 10.0))) (calmar_ratio ((min -3.0) (max 5.0)))
   (ulcer_index ((min 0.0) (max 60.0))) (open_positions_value ((min -1.0e12) (max 1.0e12))))))
