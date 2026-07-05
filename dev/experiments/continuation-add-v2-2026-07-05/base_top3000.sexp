;; BROAD deep long-only base for the continuation-add v2 surface — top-3000-2000 PIT,
;; 2000-2026, catstop ON, PRODUCTION caps (0.30/0.70/0.30). Mirror of
;; goldens-sp500-historical/top3000-2000-2026-catstop.sexp with concentration at
;; the production default (0.30, #1753) since scale-in adds cap at
;; max_position_pct_long. Broad is the DECISIVE cell for this mechanism (the
;; capacity bottleneck + gap-and-go monsters live on breadth; sp500 risks a
;; false null per the 2026-06-25 correction + declining-MA breadth lesson).
((name "continuation-add-v2-base-top3000")
 (description "BROAD deep long-only + catstop base for the continuation-add v2 WF-CV (top-3000-2000 PIT, production caps).")
 (period ((start_date 2000-01-01) (end_date 2026-04-30)))
 (universe_path "../goldens-custom-universe/composition/top-3000-2000.sexp")
 (universe_size 3000)
 (config_overrides
  (((enable_short_side false))
   ((stops_config ((catastrophic_stop_pct 0.10))))
   ((portfolio_config ((max_position_pct_long 0.30))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (expected ((total_return_pct ((min -90.0) (max 90000.0))) (total_trades ((min 1) (max 90000)))
   (win_rate ((min 0.0) (max 100.0))) (sharpe_ratio ((min -3.0) (max 5.0)))
   (max_drawdown_pct ((min 0.0) (max 90.0))) (avg_holding_days ((min 0.0) (max 800.0)))
   (sortino_ratio_annualized ((min -3.0) (max 10.0))) (calmar_ratio ((min -3.0) (max 5.0)))
   (ulcer_index ((min 0.0) (max 60.0))) (open_positions_value ((min -1.0e12) (max 1.0e12))))))
