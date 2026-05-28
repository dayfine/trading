;; Mechanism-ablation 1b-wide-stops — WIDEN stops to near-disable them.
;;
;; The 1b post-mortem showed 5 of 10 exits were stop_loss with per-trade
;; losses of 1-4%. Suspicion: Cell-E's tight stops (initial_stop_pct=0.08)
;; whipsaw on routine SPY pullbacks that retrace 3-5% then continue up.
;;
;; Knobs touched (4):
;;   screening_config.candidate_params.initial_stop_pct = 0.30 (was 0.08)
;;   screening_config.candidate_params.installed_stop_min_pct = 0.30 (was 0.0)
;;   stops_config.max_stop_distance_pct = 0.50 (was 0.15) — must LIFT the gate
;;     or every 30%-stop candidate is rejected with Stop_too_wide
;;   stops_config.min_correction_pct = 0.30 (was 0.08) — needs a 30% pullback
;;     to count as a correction (so trailing stops rarely tighten)
;;
;; All other 1b knobs unchanged.
((name "1b-wide-stops-spy-only")
 (description "1b - 30%% wide stops (near-disabled): SPY-only, both rotation runners enabled")
 (period ((start_date 1998-12-22) (end_date 2025-12-31)))
 (universe_path "universes/spy-only.sexp")
 (universe_size 1)
 (config_overrides
  (((portfolio_config ((max_position_pct_long 1.0))))
   ((portfolio_config ((max_long_exposure_pct 1.0))))
   ((portfolio_config ((min_cash_pct 0.0))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))
   ((screening_config ((candidate_params ((initial_stop_pct 0.30))))))
   ((screening_config ((candidate_params ((installed_stop_min_pct 0.30))))))
   ((stops_config ((max_stop_distance_pct 0.50))))
   ((stops_config ((min_correction_pct 0.30))))))
 (expected
  ((total_return_pct        ((min -90.0)      (max 5000.0)))
   (total_trades            ((min   0)        (max 1000)))
   (win_rate                ((min   0.0)      (max  100.0)))
   (sharpe_ratio            ((min  -2.0)      (max    3.0)))
   (max_drawdown_pct        ((min   0.0)      (max   95.0)))
   (avg_holding_days        ((min   0.0)      (max 5000.0))))))
