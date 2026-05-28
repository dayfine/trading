;; Mechanism-ablation 1b-baseline — reproduces the canonical 1b SPY-only
;; fullsize scenario verbatim so all ablation deltas measure exactly one
;; mechanism's contribution.
;;
;; Universe: SPY only (1 symbol).
;; Window: 1998-12-22 → 2025-12-31 (matches 1b/2b family).
;; Portfolio: max_position=1.0, max_long_exposure=1.0, min_cash=0.0
;; Mechanisms enabled (Cell-E defaults): stage3_force_exit h=1,
;;   laggard_rotation h=2, default stops (initial_stop_pct=0.08,
;;   max_stop_distance_pct=0.15, min_correction_pct=0.08,
;;   installed_stop_min_pct=0.0).
;;
;; Expected (prior run): +0.22% total / 10 trades / 0.008% CAGR /
;;   2.09% MaxDD / 3.77% time-in-market — see
;;   dev/notes/spy-only-fullsize-2026-05-28.md.
((name "1b-baseline-spy-only")
 (description "Mechanism-ablation 1b baseline: SPY-only Weinstein, Cell-E mechanisms (stage3+laggard enabled, default stops)")
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
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (expected
  ((total_return_pct        ((min -90.0)      (max 5000.0)))
   (total_trades            ((min   0)        (max 1000)))
   (win_rate                ((min   0.0)      (max  100.0)))
   (sharpe_ratio            ((min  -2.0)      (max    3.0)))
   (max_drawdown_pct        ((min   0.0)      (max   95.0)))
   (avg_holding_days        ((min   0.0)      (max 5000.0))))))
