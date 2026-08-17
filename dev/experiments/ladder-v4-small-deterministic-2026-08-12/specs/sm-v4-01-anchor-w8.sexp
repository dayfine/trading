;; LADDER V4 — cell 01 "anchor-w8": anchor axis delta — 8-week local-range top instead of 4-week.
;; Experiment: dev/plans/entry-ticket-async-v2-2026-08-10.md §5 (ladder v4).
;; Base = the ladder-v3 faithful-StopLimit arm (the v2-core cell, committed at
;;   ../ladder-v3-faithful-stoplimit-2026-08-09/): resting StopLimit at the top
;;   of the CURRENT trading range, E frozen at the first qualifying breakout
;;   (#2241), honest next-open Market-leg fills (#2238), support-floor stop.
;; v4 coordinate: anchor=8w freshness=Ma_cross ttl=0w width=Drop@0.15 volume_confirm=false
;; v3 killed its w8 arm mid-run; v4 restores it because the anchor is now also the freshness reference (F1), so the anchor window is load-bearing twice over.
;;
;; ANCHOR-AXIS TRUNCATED — plan §5 lists anchor in {4, 8, base-extent}, but the
;;   base-extent anchor DOES NOT EXIST on main: entry_anchor_local_range_weeks
;;   is a plain int lookback and no base-extent variant was ever built. The v4
;;   anchor axis therefore runs {4, 8} ONLY — i.e. the AGGRESSIVE cells. Per
;;   plan §3-F1's own caveat the book's anchor is "the top of the CURRENT
;;   trading range" and bases "can last months or years", so a 4-8 week local
;;   high can be an intra-base swing high: these windows are APPROXIMATIONS of
;;   the book anchor, not the definition. v4 is NOT a fully-explored anchor
;;   axis and must not be read as one.
;; OVERHEAD GRADING: this arm applies NO hard §4.3 overhead gate. Overhead
;;   enters only via the default-on continuous supply score (overhead_supply
;;   armed + screener w_overhead_supply=30, bundle-promoted 2026-07-23) — a
;;   RANK DEMOTION of heavy-overhead names, never an exclusion. Per plan §1 a
;;   faithful process may legitimately exclude the crash-recovery monsters, so
;;   AXTI-capture is NOT a success criterion for this cell.
;; PRESET: full-size tickets (a TRADER sizing dial) on the INVESTOR stop/exit
;;   base — a deliberate mix (plan §3 "Preset statement"), because scale-in
;;   (half + half) was built and REJECTED (#1855 arc, fat-tail tax).
;; F5 REPORT DIVERGENCE: Weekly_snapshot_generator does NOT thread the F5
;;   placement waiver (qc-behavioral finding on #2267), so once
;;   volume_confirm_at_fill is armed the simulator and the weekly report
;;   disagree on admission. Compare arms to arms, never sim to report.
;; AUDIT LIMIT: ticket-age-at-FILL is structurally capped at ~1 week until the
;;   position_id join lands (#2270 audit limitation). The TTL axis's
;;   BEHAVIOURAL effect is measurable; "how long tickets actually rested before
;;   filling" is NOT yet measurable.
;; COMPARATORS (fixed, same window/universe as v3): record-nextopen +7,321%;
;;   book-honest +310%; faithful w4 +318%; faithful w13 +262%
;;   (dev/notes/ladder-v3-faithful-stoplimit-2026-08-09.md).
;; PROVENANCE: split-safe warehouse /tmp/snap_top3000_dedup_v5thin_adj,
;;   SNAPSHOT_CACHE_MB=1024, --no-emit-all-eligible, --parallel 1, universe
;;   top-3000 PIT-2000, window 2000-01-01 -> 2026-06-26.
;; NOT a golden — staging scenario, sentinel bands.
((name "sm-v4-01-anchor-w8")
 (description "Ladder v4 cell 01 (anchor-w8): anchor=8w freshness=Ma_cross ttl=0w width=Drop@0.15 volume_confirm=false. anchor axis delta — 8-week local-range top instead of 4-week.")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 500)
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
   ((entry_anchor_local_range_weeks 8))
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
