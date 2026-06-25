;; BROAD deep long-only base — top-3000-as-of-2000 PIT, 2000-2026, catstop ON.
;; Exact mirror of goldens-sp500-historical/sp500-2000-2026-catstop.sexp with the
;; ONLY change being the universe: SP500-515 -> top-3000-2000 (3000 names). This
;; isolates the BREADTH effect for the capacity/concentration WF-CV — the SP500
;; basis is too narrow to exercise the capacity bottleneck (few breakout winners
;; competing for cash), per the 2026-06-25 user correction. Run via
;; walk_forward_runner --snapshot-dir /tmp/snap_top3000_1998_2026 --parallel 1
;; (N=3000 needs fork-per-fold + warehouse mmap to fit the 7.75 GB container).
;; Same conservative Cell-E config as the deep goldens (0.14 / hyst-2) — the
;; concentration axis sweeps max_position_pct_long. WF base only (folds drive period).
((name "top3000-2000-2026-catstop-deep")
 (description "BROAD deep long-only + catastrophic_stop_pct=0.10 base for the capacity/concentration WF-CV (top-3000-2000 PIT).")
 (period ((start_date 2000-01-01) (end_date 2026-04-30)))
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
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (expected ((total_return_pct ((min -90.0) (max 90000.0))) (total_trades ((min 1) (max 90000)))
   (win_rate ((min 0.0) (max 100.0))) (sharpe_ratio ((min -3.0) (max 5.0)))
   (max_drawdown_pct ((min 0.0) (max 90.0))) (avg_holding_days ((min 0.0) (max 800.0)))
   (sortino_ratio_annualized ((min -3.0) (max 10.0))) (calmar_ratio ((min -3.0) (max 5.0)))
   (ulcer_index ((min 0.0) (max 60.0))) (open_positions_value ((min -1.0e12) (max 1.0e12))))))
