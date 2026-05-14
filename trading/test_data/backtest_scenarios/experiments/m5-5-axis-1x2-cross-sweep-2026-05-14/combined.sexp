;; M5.5 axis-1 x axis-2 cross-sweep — combined cell.
;;
;; Twin of goldens-sp500/sp500-2019-2023.sexp (Cell E config, shorts ON);
;; BOTH axis-1 (installed_stop_min_pct = 0.08, PR #1079) AND axis-2
;; (stops_config.min_correction_pct = 0.10, PR #1083) overlays applied.
;;
;; Hypothesis: combined cell may reach Calmar ~0.90+ if additive; may also
;; conflict (one mechanism dominates, combining double-counts).
;;
;; Note: the two overlays target distinct top-level config keys
;; (screening_config vs stops_config), so they compose through _apply_overrides
;; without the deep-merge silent-drop hazard from PR #1051/#1069.
((name "m5-5-axis-cross-combined")
 (description "Cross-sweep combined (installed_stop_min_pct=0.08 + min_correction_pct=0.10)")
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
   ((laggard_rotation_config ((hysteresis_weeks 2))))
   ((screening_config ((candidate_params ((installed_stop_min_pct 0.08))))))
   ((stops_config ((min_correction_pct 0.10))))))
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
