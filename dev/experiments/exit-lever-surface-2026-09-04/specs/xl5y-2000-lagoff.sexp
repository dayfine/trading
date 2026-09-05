;; THE CANONICAL RECORD BASELINE (2026-08-24) — 26y broad record-convention
;; run at the book-faithful stops basis. Config is the record convention
;; (same overrides as the funding-grid grid1-null lineage) with the two
;; #2530 flips (initial_stop_buffer 1.0, reset_anchor_on_stalled_cycle true)
;; inherited as build defaults — deliberately NOT pinned in config_overrides.
;; Build: c7660cac3 (post-#2530). Results + params.sexp in ../results/.
;; Every arm after 2026-08-24 diffs against this run (supersedes the
;; unreproducible grid1-null 305% record, #2503).
;; Run with the split-safe warehouse (/tmp/snap_top3000_dedup_v5thin_adj),
;; SNAPSHOT_CACHE_MB=1024, --no-emit-all-eligible, --parallel 1.
;; NOT a golden — staging scenario, sentinel bands.
((name "xl5y-2000-lagoff")
 (description "CANONICAL RECORD BASELINE (2026-08-24): record convention at the book-faithful stops basis (initial_stop_buffer 1.0, reset_anchor_on_stalled_cycle true, inherited as defaults). Supersedes the unreproducible grid1-null 305% record (#2503).")
 (period ((start_date 2000-01-03) (end_date 2004-12-31)))
 (universe_path "../goldens-custom-universe/composition/top-3000-2000.sexp")
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
   ((enable_laggard_rotation false))
   ((laggard_rotation_config ((hysteresis_weeks 2))))
   ((liquidity_config ((min_entry_dollar_adv 1000000.0))))
   ((liquidity_config ((min_hold_dollar_adv 500000.0))))
   ((stale_exit_after_days (5)))))
 (expected ((total_return_pct ((min -90.0) (max 90000.0))) (total_trades ((min 1) (max 90000)))
   (win_rate ((min 0.0) (max 100.0))) (sharpe_ratio ((min -3.0) (max 5.0)))
   (max_drawdown_pct ((min 0.0) (max 90.0))) (avg_holding_days ((min 0.0) (max 800.0)))
   (sortino_ratio_annualized ((min -3.0) (max 10.0))) (calmar_ratio ((min -3.0) (max 5.0)))
   (ulcer_index ((min 0.0) (max 60.0))) (open_positions_value ((min -1.0e12) (max 1.0e12))))))
