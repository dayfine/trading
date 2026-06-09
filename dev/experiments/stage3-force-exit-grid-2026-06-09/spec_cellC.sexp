;; Cell C WF-CV spec — top-1000-2011 2011-2026, force_exit on/off surface.
((base_scenario "/tmp/grid/base_cellC_top1000.sexp")
 (window_spec
  (Rolling
   ((start_date 2011-01-01)
    (end_date 2026-04-30)
    (train_days 0)
    (test_days 365)
    (step_days 365))))
 (variants
  (((label "force_exit_off")
    (overrides (((enable_stage3_force_exit false)))))
   ((label "baseline") (overrides ()))))
 (baseline_label "baseline")
 (gate ((metric Sharpe) (m 8) (n 15) (worst_delta 0.30))))
