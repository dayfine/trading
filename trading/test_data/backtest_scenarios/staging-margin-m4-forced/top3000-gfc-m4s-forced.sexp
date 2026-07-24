;; MARGIN M4 STAGE-2 SQUEEZE STRESS, cell 2 of 3 (2026-07-23) — GFC
;; window (2007-2010) with the short book fully armed: margin accounting ON,
;; M3a tier tables (FINRA-style maintenance: sub-$5 -> 100%, $5-17 -> 83%,
;; base fallback 0.30 per long-short-margin-mechanics-2026-06-12 §1; HTB
;; borrow-rate tiers sub-$5 -> 100%/yr, $5-17 -> 25%/yr, fallback flat 50bps)
;; + M3b deterministic buy-in stress (every sub-$5 short bought in at Friday
;; close) + M3a borrow-availability entry gate ($1M dollar-ADV, mirroring the
;; long entry floor). Long side stays the promoted-bundle record dials with
;; the E-capped entry bound (cap 1.0, unlevered).
;; Purpose: force-cover / buy-in ORDERING audit per event (plan M4.2) — not a
;; performance claim. NOT a golden — staging scenario, sentinel bands.
((name "top3000-gfc-m4s-forced")
 (description "M4 FORCED-ENGAGEMENT cell: GFC window, punitive thresholds (HTB<\$25 buy-in, 90-120% maintenance) purely to generate force-cover + buy-in events for the ordering audit. NOT an economics claim.")
 (period ((start_date 2007-01-01) (end_date 2010-12-31)))
 (universe_path "../goldens-custom-universe/composition/top-3000-2000.sexp")
 (universe_size 3000)
 (config_overrides
  (((extension_stop_config ((trigger_ratio 2.0) (trail_pct 0.25))))
   ((reject_declining_ma_long_entry true))
   ((enable_short_side true))
   ((max_long_exposure_pct_entry 1.0))
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
   ((overhead_supply
     (((proximity_decay 0.7) (saturation_bars 8.0) (recent_far_floor 0.0)
       (stale_mid_floor 0.0) (stale_old_floor 0.0) (min_history_bars 0)
       (insufficient_score 0.5) (heavy_resistance_bars 8)
       (moderate_resistance_bars 3)))))
   ((screening_config ((weights ((w_overhead_supply (30)))))))
   ((virgin_crossing_readmission true))
   ((short_borrow_min_dollar_adv 1000000.0))
   ((margin_config ((enabled true))))
   ((margin_config ((maintenance_margin_pct 0.90))))
   ((margin_config
     ((short_borrow_rate_tiers
       (((price_below 5.0) (value 1.00)) ((price_below 17.0) (value 0.25)))))))
   ((margin_config
     ((short_maintenance_tiers
       (((price_below 5.0) (value 1.20)) ((price_below 17.0) (value 1.00)) ((price_below 100.0) (value 0.90)))))))
   ((margin_config ((short_buyin_stress_mode true))))
   ((margin_config ((short_buyin_htb_price_below 25.0))))))
 (expected ((total_return_pct ((min -95.0) (max 90000.0))) (total_trades ((min 1) (max 90000)))
   (win_rate ((min 0.0) (max 100.0))) (sharpe_ratio ((min -3.0) (max 5.0)))
   (max_drawdown_pct ((min 0.0) (max 95.0))) (avg_holding_days ((min 0.0) (max 800.0)))
   (sortino_ratio_annualized ((min -5.0) (max 10.0))) (calmar_ratio ((min -3.0) (max 5.0)))
   (ulcer_index ((min 0.0) (max 80.0))) (open_positions_value ((min -1.0e12) (max 1.0e12))))))
