;; LADDER V3 — faithful-StopLimit arm, 4-week local-range anchor.
;; The book ticket done RIGHT per dev/plans/entry-ticket-right-basis-2026-08-08.md:
;; resting StopLimit at the top of the CURRENT trading range (4w local top, not
;; the stale 52-wk graded E), E frozen at first-qualifying breakout (Fix #2
;; #2241), honest next-open Market-leg fills (Fix #1 #2238), and the
;; SUPPORT-FLOOR stop kept verbatim (stop_anchor_at_entry_base deliberately
;; OFF — the 15% max_stop_distance_pct gate acts as the book §5.1 "prefer other
;; candidates" FILTER, not a stop re-anchor).
;; Comparators: record-nextopen (+7,321%) and book-honest (+310%) from
;; dev/notes/fill-model-ladder-v2-2026-08-08.md; localtop26 (+474%) from the
;; 08-06 ladder (no freeze/next-open).
;; Run with the split-safe warehouse (/tmp/snap_top3000_dedup_v5thin_adj),
;; SNAPSHOT_CACHE_MB=1024, --no-emit-all-eligible, --parallel 1.
;; NOT a golden — staging scenario, sentinel bands.
((name "top3000-2000-2026-record-convention-faithful-w4")
 (description "Faithful StopLimit ticket: 4w local-range trigger + frozen E + next-open fills + support-floor stop (15% as filter). Ladder v3 arm.")
 (period ((start_date 2000-01-01) (end_date 2026-06-26)))
 (universe_path "../goldens-custom-universe/composition/top-3000-2000.sexp")
 (universe_size 3000)
 (config_overrides
  (((enable_sim_entry_stoplimit true))
   ((sim_entry_trigger_at_suggested true))
   ((entry_anchor_local_range_weeks 4))
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
   ((stale_exit_after_days (5)))))
 (expected ((total_return_pct ((min -90.0) (max 90000.0))) (total_trades ((min 1) (max 90000)))
   (win_rate ((min 0.0) (max 100.0))) (sharpe_ratio ((min -3.0) (max 5.0)))
   (max_drawdown_pct ((min 0.0) (max 90.0))) (avg_holding_days ((min 0.0) (max 800.0)))
   (sortino_ratio_annualized ((min -3.0) (max 10.0))) (calmar_ratio ((min -3.0) (max 5.0)))
   (ulcer_index ((min 0.0) (max 60.0))) (open_positions_value ((min -1.0e12) (max 1.0e12))))))
