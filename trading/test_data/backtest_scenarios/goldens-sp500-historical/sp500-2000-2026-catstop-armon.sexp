;; Deep long-only base: catastrophic_stop_pct=0.10 + fast_v_arm_on_rate_alone=true,
;; for the fast_v_min_rate_pct THRESHOLD SURFACE WF-CV. The arming knob is ON; the
;; axis sweeps the arming rate threshold to suppress the 2010/2011 whipsaw the
;; arming-speed WF-CV found. sp500-as-of-2000 PIT, 2000-2026. Reads data/.
((name "sp500-2000-2026-catstop-armon-deep")
 (description "Deep long-only + cat_stop 0.10 + arm_on_rate=true base for the fast_v_min_rate_pct surface.")
 (period ((start_date 2000-01-01) (end_date 2026-04-30)))
 (universe_path "universes/sp500-historical/sp500-2000-01-01.sexp")
 (universe_size 515)
 (config_overrides
  (((enable_short_side false))
   ((fast_v_arm_on_rate_alone true))
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
  ((fast_v_arm_on_rate_alone "the fast-V rate-alone arming this -armon cell isolates; live runs the code default")
   (stops_config "catastrophic-stop arming this -catstop cell isolates (catastrophic_stop_pct 0.10); live runs the 0.0 default")
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
   (entry_extension_max_pct "live arms 15.0, this cell runs the 0.0 default (uncapped); neither value has a defensible provenance -- unification is the open #2404 decision (#2403)")
   (sparse_tail_min_bars "live-only sparse-tail eligibility gate (#2083 fix 1); report-layer data hygiene, no backtest consumer")
   (sparse_tail_window_trading_days "live-only sparse-tail eligibility gate (#2083 fix 1); report-layer data hygiene, no backtest consumer")
   (rename_detect_min_overlap_days "live-only ticker-rename detector (#2083 fix 2); report-layer data hygiene, no backtest consumer")
   (rename_detect_match_fraction "live-only ticker-rename detector (#2083 fix 2); report-layer data hygiene, no backtest consumer")))
 (expected ((total_return_pct ((min -90.0) (max 9000.0))) (total_trades ((min 1) (max 9000)))
   (win_rate ((min 0.0) (max 100.0))) (sharpe_ratio ((min -3.0) (max 5.0)))
   (max_drawdown_pct ((min 0.0) (max 90.0))) (avg_holding_days ((min 0.0) (max 800.0)))
   (sortino_ratio_annualized ((min -3.0) (max 10.0))) (calmar_ratio ((min -3.0) (max 5.0)))
   (ulcer_index ((min 0.0) (max 60.0))) (open_positions_value ((min -1.0e12) (max 1.0e12))))))
