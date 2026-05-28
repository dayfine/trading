;; Mechanism-ablation 1b-buy-and-hold-on-stage2 — maximally permissive
;; Weinstein-Stage-2 timing: DISABLE laggard + DISABLE stage3 + wide stops.
;;
;; This is the upper-bound test for "Weinstein-style entry-only timing on
;; SPY". The strategy still requires Stage-2 entry (screener cascade is
;; unchanged) but no rotation runner and no stops fire to remove the
;; position until the screener itself transitions SPY out of Stage-2 by
;; downgrading the candidate's grade or sector rating (or until a 30%+
;; trailing-stop tighten).
;;
;; Knobs touched:
;;   enable_laggard_rotation = false
;;   enable_stage3_force_exit = false
;;   screening_config.candidate_params.initial_stop_pct = 0.30
;;   screening_config.candidate_params.installed_stop_min_pct = 0.30
;;   stops_config.max_stop_distance_pct = 0.50
;;   stops_config.min_correction_pct = 0.30
;;
;; If THIS run still loses to BAH-SPY, the Stage-2 entry filter itself is
;; the bottleneck — SPY simply doesn't qualify as a Stage-2 breakout
;; candidate often enough to capture the obvious bull runs.
((name "1b-buy-and-hold-on-stage2-spy-only")
 (description "1b - maximally permissive: no laggard, no stage3, 30%% stops — upper-bound for entry-only timing")
 (period ((start_date 1998-12-22) (end_date 2025-12-31)))
 (universe_path "universes/spy-only.sexp")
 (universe_size 1)
 (config_overrides
  (((portfolio_config ((max_position_pct_long 1.0))))
   ((portfolio_config ((max_long_exposure_pct 1.0))))
   ((portfolio_config ((min_cash_pct 0.0))))
   ((enable_stage3_force_exit false))
   ((enable_laggard_rotation false))
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
