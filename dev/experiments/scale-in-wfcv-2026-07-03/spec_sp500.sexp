;; Scale-in v1 WF-CV surface (plan dev/plans/capital-management-scale-in-2026-07-02.md §6;
;; mechanism merged default-off via #1830-#1833). Cell-E sp500-515 PIT-2000, 2000-2026,
;; 2-year non-overlapping folds (13, bear-inclusive: dot-com + GFC + 2022), production caps.
;; baseline = enable_scale_in=false (default); variants arm the mechanism at
;; initial_entry_fraction=0.5 with the Pullback (v1 default) and Either triggers —
;; Either exists for the §3.4 monster-under-sizing check.
((base_scenario "/workspaces/trading-1/dev/experiments/scale-in-wfcv-2026-07-03/base_sp500.sexp")
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
