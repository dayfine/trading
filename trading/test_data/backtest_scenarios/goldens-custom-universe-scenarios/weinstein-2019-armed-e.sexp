;; perf-tier: 3
;; perf-tier-rationale: broad (top-3000 PIT-2019) 5y cell pinning the
;; E-anchored resting-entry configuration — the only tier-3 cell where the
;; entry-ticket lifecycle machinery executes on a broad universe. Runs in
;; the custom-universe postsubmit alongside weinstein-2019-top-500.
;;
;; E-ANCHORED ENTRY-CONFIGURATION GOLDEN (2026-08-31, follow-up to PR #2587).
;;
;; WHY THIS CELL EXISTS: the golden suite pins the trigger-at-close default
;; path in 11 cells but the trigger-at-E configuration — the book's resting
;; GTC ticket (weinstein-book-reference.md §4.7), the record-convention
;; honest-tradeable lineage, and the ONLY path where the entry-ticket
;; lifecycle knobs (entry_order_max_rest_weeks, rescreen, freshness) execute
;; at all — in exactly one 5y sp500 cell (sp500-2019-2023-armed-stoplimit).
;; The #2587 paired-golden table measured that asymmetry directly: 11/12
;; goldens bit-identical under the clock flip because their tickets fill
;; within a bar and never rest. This cell adds a BROAD (top-3000 PIT-2019)
;; pin of the armed path so a regression in the resting-ticket machinery is
;; caught outside large-caps. Coverage-per-shape, not more of the same shape.
;;
;; LINEAGE: config is the clock-surface cell-B arm at the promoted default
;; (dev/experiments/clock-surface-2026-08-27/specs/clockB-52.sexp) with the
;; ((entry_order_max_rest_weeks 52)) override REMOVED — the golden inherits
;; the code default (52 since #2587) deliberately, so any future default
;; flip of the clock (or of any lifecycle knob) is listed by
;; goldens_affected_check as inheriting HERE, where it actually executes.
;;
;; PINS: +-15% around the salt-0 actuals of the 2026-08-31 CSV-mode
;; verification run at post-#2587 main (16ad01974): 79.1953% / 187 trades /
;; win 30.48 / sharpe 0.8014 / maxDD 19.88 / avg_hold 54.81, wall 221s.
;; TRADING_PATH_SEED_SALT unset in CI = salt 0 (market_state.ml
;; parse_salt), so the run is deterministic and the band guards code
;; drift, not path noise.
;;
;; ⚠ DATA-BASIS NOTE — these pins are NOT the experiment's cell-B numbers.
;; The clock-surface cell-B run (clockB-52-s0: 25.31% / 182 / DD 27.00)
;; used the split-safe snapshot warehouse built from the FULL local bar
;; store (delisted-aware); this golden runs CI's committed test_data CSV
;; subset, a survivor-tilted basis, and the same config returns 79.2%
;; there. The gap is the data basis, not code. A golden pins the
;; CI-reproducible basis by design (universe-discipline: goldens are
;; drift tripwires, not measurement surfaces — never quote this cell's
;; return as evidence about the strategy). Cross-basis comparisons are
;; invalid in either direction.
;;
;; wall_seconds pinned [0, 1800]: 221s measured locally WITH
;; --no-emit-all-eligible, ~8x headroom for a GHA runner (min floored at 0
;; per #2547 — a min guards nothing). ⚠ Without that flag the runner's
;; opt-OUT all_eligible diagnostic scans 3,001 symbols after actual.sexp is
;; written (measured 48+ min, qc-behavioral review 5064470899) — the
;; postsubmit script passes the flag as of this PR; ad-hoc local runs of
;; this cell should too.
((name "weinstein-2019-armed-e")
 (description
   "Broad E-anchored entry golden: top-3000 PIT-2019 composition, 2019-01-02 → 2023-12-29, with the armed StopLimit entry stack (enable_sim_entry_stoplimit + sim_entry_trigger_at_suggested + local-range anchor 4w) over the record-convention base. Pins the book-ticket resting-entry path — the only configuration where the entry-ticket lifecycle knobs execute — on a broad universe; companion to goldens-sp500/sp500-2019-2023-armed-stoplimit.sexp (5y sp500).")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "../goldens-custom-universe/composition/top-3000-2019.sexp")
 (universe_size 3000)
 (config_overrides
  (;; --- the armed StopLimit / E-anchored entry stack (the point of this cell) ---
   ((enable_sim_entry_stoplimit true))
   ((sim_entry_trigger_at_suggested true))
   ((entry_extension_max_pct 2.0))
   ((freeze_entry_at_first_breakout true))
   ((sim_entry_fill_next_open true))
   ((entry_anchor_local_range_weeks 4))
   ((entry_freshness_basis Ma_cross))
   ((enable_entry_ticket_rescreen false))
   ;; entry_order_max_rest_weeks deliberately NOT pinned — inherits the code
   ;; default (52 since #2587) so future lifecycle-default flips list this
   ;; cell as affected. See header.
   ;; --- record-convention base (verbatim from clockB-52 / ladder-v4 core) ---
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
   ((stop_width_mode Drop_over_max))
   ((stop_width_size_down_max_pct 0.0))
   ((volume_confirm_at_fill false))
   ((stops_config ((max_stop_distance_pct 0.15))))
   ((stops_config ((support_floor_anchor_scope Window_extreme))))))
 (deviates_from_live
  (;; NOTE: entries exist ONLY for knobs whose value here DIFFERS from live —
   ;; the golden_live_drift linter FAILs on declarations matching live. The
   ;; armed stack's enable_sim_entry_stoplimit / entry_extension_max_pct /
   ;; extension_stop_config / reject_declining_ma_long_entry /
   ;; stale_exit_after_days and the ladder-v4 no-op coordinates all match
   ;; live's effective config and are deliberately NOT declared.
   (sim_entry_trigger_at_suggested "part of the armed StopLimit entry stack (the point of this cell)")
   (sim_entry_fill_next_open "part of the armed StopLimit entry stack (the point of this cell)")
   (freeze_entry_at_first_breakout "part of the armed StopLimit entry stack (the point of this cell)")
   (entry_anchor_local_range_weeks "part of the armed StopLimit entry stack (local-range 4w anchor)")
   (enable_short_side "long-only cell: arms the short leg off; the code default (and therefore live) is on")
   (stops_config "catastrophic-stop 0.10 + max_stop_distance_pct 0.15 + support_floor_anchor_scope Window_extreme arming; live runs the code defaults")
   (liquidity_config "record-convention liquidity realism arming; live runs the code defaults")
   (portfolio_config "record-convention concentration arming (position 0.14 / exposure 0.70 / min_cash 0.30); live runs the code defaults")
   (enable_stage3_force_exit "record-convention Stage-3 force-exit arming; live leaves it default-off")
   (stage3_force_exit_config "hysteresis_weeks 1 belongs to the arming above; the code default is 2")
   (enable_laggard_rotation "record-convention laggard-rotation arming; live leaves it default-off")
   (laggard_rotation_config "hysteresis_weeks 2 belongs to the arming above; the code default is 4")
   (screening_config "live arms candidate_ranking=Quality (#1782, report ordering) and failed_breakout_tolerance_pct=0.05 (#2084); the backtest defaults stay unarmed per experiment-flag R1")
   (resistance_lookback_bars "live feeds the resistance/support mapper 520 weekly bars for the human report only")
   (entry_through_band_pct "live-only entry-reconciliation band for the printed ticket (#2103); read by Weekly_snapshot_generator, never by on_market_close")
   (sparse_tail_min_bars "live-only sparse-tail eligibility gate (#2083 fix 1); report-layer data hygiene, no backtest consumer")
   (sparse_tail_window_trading_days "live-only sparse-tail eligibility gate (#2083 fix 1); report-layer data hygiene, no backtest consumer")
   (rename_detect_min_overlap_days "live-only ticker-rename detector (#2083 fix 2); report-layer data hygiene, no backtest consumer")
   (rename_detect_match_fraction "live-only ticker-rename detector (#2083 fix 2); report-layer data hygiene, no backtest consumer")))
 (expected
  ((total_return_pct  ((min 67.3160)  (max 91.0746)))
   (total_trades      ((min 158.95)   (max 215.05)))
   (win_rate          ((min 25.9091)  (max 35.0535)))
   (sharpe_ratio      ((min 0.6812)   (max 0.9216)))
   (max_drawdown_pct  ((min 16.8977)  (max 22.8617)))
   (avg_holding_days  ((min 46.5864)  (max 63.0286)))
   (wall_seconds      ((min 0.0)      (max 1800.0))))))
