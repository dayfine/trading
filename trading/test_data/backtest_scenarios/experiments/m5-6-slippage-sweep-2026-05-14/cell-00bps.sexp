;; M5.6 cost-model slippage sweep — Cell 0bps (baseline, zero friction).
;;
;; Reuses the canonical Cell E config from
;; goldens-sp500/sp500-2019-2023.sexp / m5-5-axis-1x2-cross-sweep baseline:
;;   - max_position_pct_long  0.14
;;   - max_long_exposure_pct  0.70
;;   - min_cash_pct           0.30
;;   - enable_stage3_force_exit true (hysteresis_weeks 1)
;;   - enable_laggard_rotation  true (hysteresis_weeks 2)
;;   - shorts ON (default)
;;
;; Pinned cross-sweep baseline (2026-05-12, 500-sym sp500.sexp,
;; engine_config.slippage_bps = 0 implicit):
;;   total_return_pct 50.66  total_trades 264  win_rate 37.5
;;   sharpe_ratio 0.56  max_drawdown_pct 21.56  calmar_ratio 0.40
;;   sortino_ratio_annualized 0.75  ulcer_index 8.41  avg_holding_days 40.78
;;
;; Cell 0bps must match this baseline byte-for-byte (slippage_bps absent
;; = 0 = pre-cost-knob behaviour, per PR #920 default contract).
((name "m5-6-slippage-cell-00bps")
 (description "M5.6 slippage sweep — 0 bps (zero-friction baseline, anchors against pinned Cell E)")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 500)
 (config_overrides
  (((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (slippage_bps 0)
 (expected
  ((total_return_pct        ((min -50.0)       (max 500.0)))
   (total_trades            ((min   1)         (max 1000)))
   (win_rate                ((min   0.0)       (max 100.0)))
   (sharpe_ratio            ((min  -2.0)       (max   3.0)))
   (max_drawdown_pct        ((min   0.0)       (max  80.0)))
   (avg_holding_days        ((min   0.0)       (max 300.0)))
   (sortino_ratio_annualized ((min -2.0)       (max   5.0)))
   (calmar_ratio            ((min  -2.0)       (max   3.0)))
   (ulcer_index             ((min   0.0)       (max  50.0)))
   (wall_seconds            ((min   0.0)       (max 3600.0))))))
