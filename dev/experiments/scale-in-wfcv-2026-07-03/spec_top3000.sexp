;; Scale-in v1 WF-CV surface — BROAD top-3000 (the DECISIVE cell; see base header).
;; Same variants as spec_sp500. Run with --snapshot-dir (warehouse mmap) +
;; --parallel 1 (fork-per-fold; N=3000 memory).
((base_scenario "/workspaces/trading-1/dev/experiments/scale-in-wfcv-2026-07-03/base_top3000.sexp")
 (window_spec
  (Rolling
   ((start_date 2000-01-01)(end_date 2026-04-30)(train_days 0)(test_days 730)(step_days 730))))
 (variants
  (((label "baseline") (overrides ()))
   ((label "scale_in_pullback")
    (overrides (((enable_scale_in true))
                ((scale_in_config ((initial_entry_fraction 0.5)))))))
   ((label "scale_in_either")
    (overrides (((enable_scale_in true))
                ((scale_in_config ((initial_entry_fraction 0.5)(add_trigger Either)))))))))
 (baseline_label "baseline")
 (gate ((metric Sharpe)(m 7)(n 13)(worst_delta 0.30))))
