;; BROAD deep long-only base — top-3000-as-of-2000 PIT, 2000-2026, catstop ON.
;; Exact mirror of goldens-sp500-historical/sp500-2000-2026-catstop.sexp with the
;; ONLY change being the universe: SP500-515 -> top-3000-2000 (3000 names). This
;; isolates the BREADTH effect for the capacity/concentration WF-CV — the SP500
;; basis is too narrow to exercise the capacity bottleneck (few breakout winners
;; competing for cash), per the 2026-06-25 user correction. Run via
;; walk_forward_runner --snapshot-dir /tmp/snap_top3000_1998_2026 --parallel 1
;; (N=3000 needs fork-per-fold + warehouse mmap to fit the 7.75 GB container).
;; Same conservative Cell-E config as the deep goldens (0.14 / hyst-2) — the
;; concentration axis sweeps max_position_pct_long. WF base only (folds drive period).
((name "top3000-2000-2026-catstop-deep")
 (description "BROAD deep long-only + catastrophic_stop_pct=0.10 base for the capacity/concentration WF-CV (top-3000-2000 PIT).")
 (period ((start_date 2000-01-01) (end_date 2026-04-30)))
 (universe_path "../goldens-custom-universe/composition/top-3000-2000.sexp")
 (universe_size 3000)
 (config_overrides
  (((entry_order_max_rest_weeks 0))
   ((enable_short_side false))
   ((stops_config ((catastrophic_stop_pct 0.10))))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 ;; Deviations from the live weekly-picks config
 ;; (dev/weekly-picks/live-config-overrides.sexp), enforced by the
 ;; golden_live_drift linter (#2403). Data-only: Scenario.t is
 ;; [@@sexp.allow_extra_fields], so the runner parses and ignores this block.
 (deviates_from_live
  ((stops_config "catastrophic-stop arming this -catstop cell isolates (catastrophic_stop_pct 0.10); live runs the 0.0 default")
   (enable_short_side "long-only cell: arms the short leg off; the code default (and therefore live) is on")
   (portfolio_config "record-convention concentration arming (position 0.14 / exposure 0.70 / min_cash 0.30); live runs the code defaults")
   (enable_stage3_force_exit "record-convention Stage-3 force-exit arming; live leaves it default-off")
   (stage3_force_exit_config "hysteresis_weeks 1 belongs to the arming above; the code default is 2")
   (enable_laggard_rotation "record-convention laggard-rotation arming; live leaves it default-off")
   (laggard_rotation_config "hysteresis_weeks 2 belongs to the arming above; the code default is 4")
   (extension_stop_config "live arms the extension-stop insurance (trigger 2.0 / trail 0.25, ledger 2026-07-14-extension-stop-insurance-accept); this cell pins the pre-insurance basis")
   (reject_declining_ma_long_entry "live arms the declining-MA long-entry rejection (#1775); this cell pins the pre-arming basis")
   (screening_config "live arms candidate_ranking=Quality (#1782, report ordering) and failed_breakout_tolerance_pct=0.05 (#2084); the backtest defaults stay unarmed per experiment-flag R1")
   (resistance_lookback_bars "live feeds the resistance/support mapper 520 weekly bars for the human report only")
   (entry_through_band_pct "live-only entry-reconciliation band for the printed ticket (#2103); read by Weekly_snapshot_generator, never by on_market_close")
   (sparse_tail_min_bars "live-only sparse-tail eligibility gate (#2083 fix 1); report-layer data hygiene, no backtest consumer")
   (sparse_tail_window_trading_days "live-only sparse-tail eligibility gate (#2083 fix 1); report-layer data hygiene, no backtest consumer")
   (rename_detect_min_overlap_days "live-only ticker-rename detector (#2083 fix 2); report-layer data hygiene, no backtest consumer")
   (rename_detect_match_fraction "live-only ticker-rename detector (#2083 fix 2); report-layer data hygiene, no backtest consumer")))
 ;; Verified 2026-07-11 under the realism-defaults flip (entry gate $1M ADV +
 ;; stale-exit 5d default-on; ledger 2026-07-10-realism-defaults-flip), 364
 ;; warehouse: ret 5729.2%  trades 1109  win 36.5  sharpe 0.79  maxDD 40.6
 ;; hold 45.9  OPV $54.0M (unrealized $44.9M — MTM-TOP-HEAVY, realized portion
 ;; is much smaller; do NOT quote the topline as tradeable). vs the un-armed
 ;; +2063% baseline: stale-exit ghost-cash recycling LIFTS this delisted-heavy
 ;; deep window (same mechanism as the goldens-broad 07-11 re-pins), most of
 ;; the honest-tradeable +6889% arming lift — hold-exit (still default-off)
 ;; was NOT the driver. Sentinel bands unchanged (research-tier).
 (expected ((total_return_pct ((min -90.0) (max 90000.0))) (total_trades ((min 1) (max 90000)))
   (win_rate ((min 0.0) (max 100.0))) (sharpe_ratio ((min -3.0) (max 5.0)))
   (max_drawdown_pct ((min 0.0) (max 90.0))) (avg_holding_days ((min 0.0) (max 800.0)))
   (sortino_ratio_annualized ((min -3.0) (max 10.0))) (calmar_ratio ((min -3.0) (max 5.0)))
   (ulcer_index ((min 0.0) (max 60.0))) (open_positions_value ((min -1.0e12) (max 1.0e12))))))
