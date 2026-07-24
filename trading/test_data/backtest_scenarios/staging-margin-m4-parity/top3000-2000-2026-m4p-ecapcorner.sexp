;; MARGIN M4 STAGE-1 PARITY, arm 4 of 4 (2026-07-23) — arm 3 (E-capped anchor)
;; PLUS the M4.3 leverage-surface CORNER CELL written explicitly:
;; initial_long_margin_req 1.0 + long_margin_rate_annual_pct 0.0, applied via
;; the same override mechanism the surface will use. Gate: byte-compare
;; against arm 3 — proves "M1 at (1.0, rate 0) == E-capped" (plan M4.1), i.e.
;; the surface's unlevered corner anchors bit-identically to the E-capped
;; baseline, on the shorts-on path (margin runner ticking, borrow-fee /
;; force-cover seams live).
;; NOT a golden — staging scenario, sentinel bands.
((name "top3000-2000-2026-m4p-ecapcorner")
 (description "M4 parity arm 4: arm 3 + explicit req=1.0/rate=0 (leverage-surface corner anchors to E-capped).")
 (period ((start_date 2000-01-01) (end_date 2026-06-26)))
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
   ((initial_long_margin_req 1.0))
   ((long_margin_rate_annual_pct 0.0))))
 (expected ((total_return_pct ((min -95.0) (max 90000.0))) (total_trades ((min 1) (max 90000)))
   (win_rate ((min 0.0) (max 100.0))) (sharpe_ratio ((min -3.0) (max 5.0)))
   (max_drawdown_pct ((min 0.0) (max 95.0))) (avg_holding_days ((min 0.0) (max 800.0)))
   (sortino_ratio_annualized ((min -3.0) (max 10.0))) (calmar_ratio ((min -3.0) (max 5.0)))
   (ulcer_index ((min 0.0) (max 60.0))) (open_positions_value ((min -1.0e12) (max 1.0e12))))))
