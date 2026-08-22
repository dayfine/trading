;; HONEST LADDER — E-anchored arm (band 2pp). Identical to
;; top3000-2000-2026-record-convention.sexp PLUS sim_entry_trigger_at_suggested
;; (#2209): entries are StopLimit(E, E×(1±2/100)) genuinely RESTING at the
;; screener breakout level E, per the 2026-08-05 user decision (Step 0 = b).
;; (enable_sim_entry_stoplimit + entry_extension_max_pct, PR #2202).
;; Purpose: full-window broad cap-on-vs-off comparison + trade-level fill
;; diff vs the control arm, extending the 31-fold sp500 REJECT
;; (ledger 2026-08-04-sim-entry-stoplimit-surface) to the record basis.
;; Run with the split-safe warehouse (/tmp/snap_top3000_dedup_v5thin_adj),
;; SNAPSHOT_CACHE_MB=1024, --no-emit-all-eligible, --parallel 1.
;; NOT a golden — staging scenario, sentinel bands.
((name "grid1-g2a2")
 (description "FUNDING GRID arm — fullbook-graded base + G2a retries 2.")
 (period ((start_date 2000-01-01) (end_date 2026-06-26)))
 (universe_path "../goldens-custom-universe/composition/top-3000-2000.sexp")
 (universe_size 3000)
 ;; entry_order_max_rest_weeks pinned at its pre-promotion value 0
 ;; (unbounded) so this recorded arm stays reproducible after the default
 ;; moved 0 -> 26 on 2026-08-18 (PR #2384). Do not drop this pin.
 (config_overrides
  (((entry_fill_reject_retries 2))
   ((enable_sim_entry_stoplimit true)) ((entry_order_max_rest_weeks 0))
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
   ((stale_exit_after_days (5)))))
 (expected ((total_return_pct ((min -90.0) (max 90000.0))) (total_trades ((min 1) (max 90000)))
   (win_rate ((min 0.0) (max 100.0))) (sharpe_ratio ((min -3.0) (max 5.0)))
   (max_drawdown_pct ((min 0.0) (max 90.0))) (avg_holding_days ((min 0.0) (max 800.0)))
   (sortino_ratio_annualized ((min -3.0) (max 10.0))) (calmar_ratio ((min -3.0) (max 5.0)))
   (ulcer_index ((min 0.0) (max 60.0))) (open_positions_value ((min -1.0e12) (max 1.0e12))))))
