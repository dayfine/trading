;; perf-tier: research
;; perf-tier-rationale: DEEP long-short base for the neutral_blocks_shorts
;; walk-forward CV (faithful-short-deep-screen-2026-06-22 → promote-track).
;; Long-short twin of the deep universe, on the point-in-time sp500-as-of-2000
;; membership (incl. delistings) over 2000-2026 (dot-com bust + GFC + bull).
;; Used ONLY as the WF base_scenario (the window_spec drives the folds); the
;; period here is a default. Reads the gitignored repo-root data/ store (deep
;; 1998-2026 bars fetched 2026-06-22). NOT a pinned golden — research-tier,
;; sentinel bands only.
;;
;; 2026-07-09 neutral_blocks_shorts default flip (false→true, user-mandated
;; faithfulness flip): not re-run here (the deep data/ store is absent in this
;; environment). No re-pin needed — the flip is near-inert (the 2010-2026
;; longshort twin re-ran BIT-IDENTICAL; the 2000-2010 deep screen blocked
;; exactly one Neutral-tape short over 11y, ≈0 cost — see
;; dev/notes/p1a-deep-short-screens-364-2026-07-09.md §Attribution) and the
;; 368% VERIFIED baseline sits deep inside the sanity-wide bands below, which
;; a near-inert change cannot escape.
((name "sp500-2000-2026-longshort-deep")
 (description
   "Deep long-short base (sp500-as-of-2000 PIT, 2000-2026, enable_short_side=true) for the neutral_blocks_shorts WF-CV. Same overlay as sp500-2010-2026-longshort.")
 (period ((start_date 2000-01-01) (end_date 2026-04-30)))
 (universe_path "universes/sp500-historical/sp500-2000-01-01.sexp")
 (universe_size 515)
 (config_overrides
  (((enable_short_side true))
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
  ((portfolio_config "record-convention concentration arming (position 0.14 / exposure 0.70 / min_cash 0.30); live runs the code defaults")
   (enable_stage3_force_exit "record-convention Stage-3 force-exit arming; live leaves it default-off")
   (stage3_force_exit_config "hysteresis_weeks 1 belongs to the arming above; the code default is 2")
   (enable_laggard_rotation "record-convention laggard-rotation arming; live leaves it default-off")
   (laggard_rotation_config "hysteresis_weeks 2 belongs to the arming above; the code default is 4")
   (extension_stop_config "live arms the extension-stop insurance (trigger 2.0 / trail 0.25, ledger 2026-07-14-extension-stop-insurance-accept); this cell pins the pre-insurance basis")
   (reject_declining_ma_long_entry "live arms the declining-MA long-entry rejection (#1775); this cell pins the pre-arming basis")
   (screening_config "live arms candidate_ranking=Quality (#1782, report ordering) and failed_breakout_tolerance_pct=0.05 (#2084); the backtest defaults stay unarmed per experiment-flag R1")
   (resistance_lookback_bars "live feeds the resistance/support mapper 520 weekly bars for the human report only")
   (entry_through_band_pct "live-only entry-reconciliation band for the printed ticket (#2103); read by Weekly_snapshot_generator, never by on_market_close")
   (entry_extension_max_pct "live arms 15.0, this cell runs the 0.0 default (uncapped); neither value has a defensible provenance -- unification is the open #2404 decision (#2403)")
   (sparse_tail_min_bars "live-only sparse-tail eligibility gate (#2083 fix 1); report-layer data hygiene, no backtest consumer")
   (sparse_tail_window_trading_days "live-only sparse-tail eligibility gate (#2083 fix 1); report-layer data hygiene, no backtest consumer")
   (rename_detect_min_overlap_days "live-only ticker-rename detector (#2083 fix 2); report-layer data hygiene, no backtest consumer")
   (rename_detect_match_fraction "live-only ticker-rename detector (#2083 fix 2); report-layer data hygiene, no backtest consumer")))
 (cost_model
  ((per_trade_commission 0.0)
   (per_share_commission 0.0)
   (bid_ask_spread_bps 5.0)
   (market_impact_bps_per_pct_adv 0.0)))
 (expected
  ((total_return_pct        ((min -90.0)  (max 5000.0)))
   (total_trades            ((min   1)    (max 9000)))
   (win_rate                ((min   0.0)  (max 100.0)))
   (sharpe_ratio            ((min  -3.0)  (max   5.0)))
   (max_drawdown_pct        ((min   0.0)  (max  90.0)))
   (avg_holding_days        ((min   0.0)  (max 800.0)))
   (sortino_ratio_annualized ((min -3.0)  (max  10.0)))
   (calmar_ratio            ((min  -3.0)  (max   5.0)))
   (ulcer_index             ((min   0.0)  (max  60.0)))
   (open_positions_value    ((min -1.0e12) (max 1.0e12))))))
