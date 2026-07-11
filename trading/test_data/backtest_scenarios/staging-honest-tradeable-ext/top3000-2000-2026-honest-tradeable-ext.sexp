;; S1 AXTI-exit-verification run (2026-07-11, next-session-priorities S1):
;; the honest-tradeable deep record run (dev/notes/honest-tradeable-baseline-
;; 2026-07-10.md) extended from end 2026-04-30 to 2026-06-26 to observe the
;; AXTI exit (branch A: trailing stop advanced past the mid-May pullback ->
;; exit ~$90-100 around Jun 8; branch B: stop at April low -> still holding
;; ~$70). Same base as goldens-sp500-historical/top3000-2000-2026-catstop plus
;; the honest-tradeable measurement convention overrides (all three realism
;; dials explicit: entry gate + hold exit + stale exit; entry gate and stale
;; are the post-#1926 defaults anyway, min_hold 5e5 is the record-run
;; convention). NOT a golden — staging scenario, sentinel bands.
((name "top3000-2000-2026-honest-tradeable-ext")
 (description "Honest-tradeable deep record run extended to 2026-06-26 for the AXTI exit observation (S1).")
 (period ((start_date 2000-01-01) (end_date 2026-06-26)))
 (universe_path "../goldens-custom-universe/composition/top-3000-2000.sexp")
 (universe_size 3000)
 (config_overrides
  (((enable_short_side false))
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
