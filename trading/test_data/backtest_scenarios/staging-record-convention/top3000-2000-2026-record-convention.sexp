;; THE RECORD CONVENTION (2026-07-14) — the labeled config for 28y deep record
;; runs on the dedup-v2 warehouse. Supersedes staging-honest-tradeable-ext as
;; the record convention: same honest-tradeable measurement dials PLUS the two
;; armed mechanisms per the 2026-07-14 arming decision (ledger
;; 2026-07-14-extension-stop-insurance-accept):
;;   - extension_stop (trigger 2.0xWMA30, trail 25%) — insurance-ACCEPT,
;;     banks parabolic tops (8/8 firings incl. AXTI $59M), MaxDD 40.9->32.3.
;;   - reject_declining_ma_long_entry — #1775 ARM-FOR-BROAD + 07-13 matrix
;;     confirming evidence (removes AIR-2020-class waterfall buys, V8->PASS).
;; Code defaults stay no-op (experiment-flag R1); arming is THIS explicit
;; config only. Run with the dedup-v2 snapshot warehouse
;; (/tmp/snap_top3000_1998_2026_dedup_v2) + --no-emit-all-eligible.
;; NOT a golden — staging scenario, sentinel bands.
((name "top3000-2000-2026-record-convention")
 (description "28y deep record convention: honest-tradeable dials + armed extension_stop(2.0,0.25) + reject_declining_ma (Run D basis, 2026-07-13 matrix).")
 (period ((start_date 2000-01-01) (end_date 2026-06-26)))
 (universe_path "../goldens-custom-universe/composition/top-3000-2000.sexp")
 (universe_size 3000)
 (config_overrides
  (((extension_stop_config ((trigger_ratio 2.0) (trail_pct 0.25))))
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
