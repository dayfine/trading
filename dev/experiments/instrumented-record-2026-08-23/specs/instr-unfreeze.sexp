;; INSTRUMENTED RECORD-CONVENTION — UNFREEZE ARM. Identical to instr-null.sexp
;; (the grid1-null record-convention clone) PLUS the #2492 flag
;; reset_anchor_on_stalled_cycle=true: a completed-but-non-improving correction
;; cycle still resets the anchor and counts the cycle (the book-faithful
;; reading per weinstein-book-reference.md §5.2 resolved question 2026-08-23),
;; unfreezing the trailing ratchet on fallback-stop positions (#2486).
;; Paired against instr-null to measure the freeze's real-data footprint.
;; Run with the split-safe warehouse (/tmp/snap_top3000_dedup_v5thin_adj),
;; SNAPSHOT_CACHE_MB=1024, --no-emit-all-eligible, --parallel 1.
;; NOT a golden — staging scenario, sentinel bands.
((name "instr-unfreeze")
 (description "Instrumented 26y record-convention + reset_anchor_on_stalled_cycle=true (#2492 unfreeze) — paired arm B against instr-null.")
 (period ((start_date 2000-01-01) (end_date 2026-06-26)))
 (universe_path "../goldens-custom-universe/composition/top-3000-2000.sexp")
 (universe_size 3000)
 ;; entry_order_max_rest_weeks pinned at 0 — same comparability pin as
 ;; instr-null / the recorded grid1-null baseline. Do not drop.
 (config_overrides
  (((enable_sim_entry_stoplimit true)) ((entry_order_max_rest_weeks 0))
   ((sim_entry_trigger_at_suggested true))
   ((stop_anchor_at_entry_base true))
   ((entry_extension_max_pct 2.0))
   ((extension_stop_config ((trigger_ratio 2.0) (trail_pct 0.25))))
   ((reject_declining_ma_long_entry true))
   ((enable_short_side false))
   ((stops_config ((catastrophic_stop_pct 0.10))))
   ((stops_config ((reset_anchor_on_stalled_cycle true))))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))
   ((liquidity_config ((min_entry_dollar_adv 1000000.0))))
   ((liquidity_config ((min_hold_dollar_adv 500000.0))))
   ((stale_exit_after_days (5)))))
 (expected ((total_return_pct ((min -90.0) (max 90000.0))) (total_trades ((min 1) (max 90000)))
   (win_rate ((min 0.0) (max 100.0))) (sharpe_ratio ((min -3.0) (max 5.0)))
   (max_drawdown_pct ((min 0.0) (max 90.0))) (avg_holding_days ((min 0.0) (max 800.0)))
   (sortino_ratio_annualized ((min -3.0) (max 10.0))) (calmar_ratio ((min -3.0) (max 5.0)))
   (ulcer_index ((min 0.0) (max 60.0))) (open_positions_value ((min -1.0e12) (max 1.0e12))))))
