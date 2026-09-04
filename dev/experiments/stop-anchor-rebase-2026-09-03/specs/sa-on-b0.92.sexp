;; STOP-ANCHOR SURFACE (#2408) — arm sa-on-b0.92.
;; Axes: stop_anchor_at_entry_base=true, initial_stop_buffer=0.92.
;;   Approx fallback stop width = 1 - buffer*0.96 (buffer 1.0 -> 4% = current
;;   default / book §5.3 band floor; 0.98 -> ~5.9%; 0.96 -> ~7.8%;
;;   0.92 -> ~11.7%; 0.885 -> ~15.0% = the user's flat-15 test value, which is
;;   §5.1's REJECTION threshold, included to test it, not endorse it).
;; BASE: clock-surface cell-B lineage verbatim (broad5y core, record-convention
;;   E-anchored family armed) — REQUIRED, not optional: stop_anchor_at_entry_base
;;   additionally gates on (sim_entry_trigger_at_suggested &&
;;   enable_sim_entry_stoplimit); on the shipped default path the flag alone is
;;   a structural no-op (weinstein_strategy_config.mli docstring).
;; entry_order_max_rest_weeks pinned 52 explicitly per the #2611 decision record
;;   (record-convention specs pin the knob; constant across arms).
;; PROVENANCE: split-safe warehouse /tmp/snap_top3000_dedup_v5thin_adj,
;;   --no-emit-all-eligible, --parallel 1, universe top-3000 PIT-2019,
;;   window 2019-01-02 -> 2023-12-29, salt per chain leg.
;; NOT a golden — staging scenario, sentinel bands.
((name "sa-on-b0.92")
 (description "stop-anchor surface arm sa-on-b0.92 (#2408): anchor=true buffer=0.92")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "../goldens-custom-universe/composition/top-3000-2019.sexp")
 (universe_size 3000)
 (config_overrides
  (;; --- v2-core base (verbatim from clock-surface cell B) ---
   ((enable_sim_entry_stoplimit true))
   ((sim_entry_trigger_at_suggested true))
   ((entry_extension_max_pct 2.0))
   ((freeze_entry_at_first_breakout true))
   ((sim_entry_fill_next_open true))
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
   ((entry_anchor_local_range_weeks 4))
   ((entry_freshness_basis Ma_cross))
   ((enable_entry_ticket_rescreen false))
   ((entry_order_max_rest_weeks 52))
   ((stop_width_mode Drop_over_max))
   ((stop_width_size_down_max_pct 0.0))
   ((volume_confirm_at_fill false))
   ((stops_config ((max_stop_distance_pct 0.15))))
   ((stops_config ((support_floor_anchor_scope Window_extreme))))
   ;; --- surface axes ---
   ((stop_anchor_at_entry_base true))
   ((initial_stop_buffer 0.92))))
 (expected ((total_return_pct ((min -90.0) (max 90000.0))) (total_trades ((min 1) (max 90000)))
   (win_rate ((min 0.0) (max 100.0))) (sharpe_ratio ((min -3.0) (max 5.0)))
   (max_drawdown_pct ((min 0.0) (max 90.0))) (avg_holding_days ((min 0.0) (max 800.0)))
   (sortino_ratio_annualized ((min -3.0) (max 10.0))) (calmar_ratio ((min -3.0) (max 5.0)))
   (ulcer_index ((min 0.0) (max 60.0))) (open_positions_value ((min -1.0e12) (max 1.0e12))))))
