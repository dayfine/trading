;; TTL RE-TEST — defect D of dev/plans/entry-anchor-and-ttl-2026-08-15.md.
;; Base = ladder-v4 cell 00 "core-w4" (every v4 knob at its no-op), verbatim,
;;   except the two F2 fields. Same universe, window and warehouse as the
;;   seeded ladder-v4 run, so cell A's measured null carries.
;;
;; WHY: the tested TTL axis was {0, 4, 8} weeks and never reached the useful
;;   range. On cell 13's 942 joined trades the 29-91d rest bucket is 16.1% of
;;   trades and 28% of realized P&L at 8,376/trade, and ttl4's 28-day cut lands
;;   on its LOWER EDGE. This axis is {13, 26, 52} weeks.
;;
;; WHAT THE #2349 SPLIT MAKES ASKABLE: entry_order_ttl_weeks armed the
;;   book-supported weekly re-screen cancel AND an invented clock together, and
;;   returned [] at 0 without consulting the re-screen at all. The two are now
;;   independent, so "re-screen alone" (01) and "clock alone" (05) are cells
;;   that could not previously be expressed.
;;
;; THE NULL: 132.5pp on this exact base/window/universe, from three path salts
;;   (dev/experiments/ladder-v4-seeded-2026-08-14/results.md). No gap below it
;;   is interpretable. Cell 00 here re-runs the null's salt-0 draw (281.71) as a
;;   determinism tripwire — a different number means the binary moved.
;;
;; PROVENANCE: split-safe warehouse /tmp/snap_top3000_dedup_v5thin_adj,
;;   --no-emit-all-eligible, --parallel 1, universe top-3000 PIT-2000,
;;   window 2000-01-01 -> 2026-06-26, TRADING_PATH_SEED_SALT=0.
;; NOT a golden — staging scenario, sentinel bands.
((name "broad5y-02-rangetop")
 (description "F1 freshness axis: Range_top_breakout vs the Ma_cross core. Single-flag delta; everything else verbatim from ttl-retest-00-null.")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "../goldens-custom-universe/composition/top-3000-2019.sexp")
 (universe_size 3000)
 (config_overrides
  (;; --- v2-core base (verbatim from the ladder-v3 faithful arm) ---
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
   ;; --- v4 axes (every axis written explicitly, including no-op values, so
   ;;     each spec states its full v4 coordinate and a typo fails validation
   ;;     rather than silently running the baseline — the #1051 hazard) ---
   ((entry_anchor_local_range_weeks 4))
   ((entry_freshness_basis Range_top_breakout))
   ((enable_entry_ticket_rescreen false))
   ((entry_order_max_rest_weeks 0))
   ((stop_width_mode Drop_over_max))
   ((stop_width_size_down_max_pct 0.0))
   ((volume_confirm_at_fill false))
   ((stops_config ((max_stop_distance_pct 0.15))))
   ((stops_config ((support_floor_anchor_scope Window_extreme))))))
 (expected ((total_return_pct ((min -90.0) (max 90000.0))) (total_trades ((min 1) (max 90000)))
   (win_rate ((min 0.0) (max 100.0))) (sharpe_ratio ((min -3.0) (max 5.0)))
   (max_drawdown_pct ((min 0.0) (max 90.0))) (avg_holding_days ((min 0.0) (max 800.0)))
   (sortino_ratio_annualized ((min -3.0) (max 10.0))) (calmar_ratio ((min -3.0) (max 5.0)))
   (ulcer_index ((min 0.0) (max 60.0))) (open_positions_value ((min -1.0e12) (max 1.0e12))))))
