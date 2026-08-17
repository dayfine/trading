;; P0.2 PAYOFF RUN — candidate-universe compression over a BROAD universe.
;;
;; Config is the ladder-v4 cell-00 "core-w4" arm, copied verbatim from the
;; 302-symbol acceptance run (dev/experiments/candidate-universe-acceptance-
;; 2026-08-13/). ONE variable differs from that run: universe breadth,
;; 302 -> 3000. Same window, same knobs, same comparison.
;;
;; This pair is NOT a golden and NOT an experiment arm — the numbers it
;; produces are meaningful only against each other. The question is whether a
;; capture-derived fixture reproduces the full-universe run BYTE-FOR-BYTE
;; while being an order of magnitude smaller; the return figure itself is not
;; a result and must not be quoted as one.
;;
;; PROVENANCE: split-safe warehouse /tmp/snap_top3000_dedup_v5thin_adj,
;;   --no-emit-all-eligible, --parallel 1, universe top-3000 (as-of 2010
;;   membership, forward-looking at the membership level — see the universe
;;   file's own header), window 2018-01-02 -> 2023-12-29.
((name "p02-top3000-fixture")
 (description "P0.2 payoff fixture re-run — top-3000, 2018-2023. Ladder v4 cell 00 (core-w4): anchor=4w freshness=Ma_cross ttl=0w width=Drop@0.15 volume_confirm=false. the v2-core cell — every v4 knob at its no-op.")
 (period ((start_date 2018-01-02) (end_date 2023-12-29)))
 (universe_path "universes/broad3000-candidates-2018-2023.sexp")
 (universe_size 0)
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
   ((entry_freshness_basis Ma_cross))
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
