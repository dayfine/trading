;; Cell B WF-CV spec — deep 2000-2010, force_exit on/off surface.
((base_scenario "/tmp/grid/base_cellB_deep.sexp")
 (window_spec
  (Rolling
   ((start_date 2000-01-01)
    (end_date 2010-12-31)
    (train_days 0)
    (test_days 365)
    (step_days 365))))
 (variants
  (((label "force_exit_off")
    (overrides (((enable_stage3_force_exit false)))))
   ((label "baseline") (overrides ()))))
 (baseline_label "baseline")
 (gate ((metric Sharpe) (m 6) (n 10) (worst_delta 0.30))))
