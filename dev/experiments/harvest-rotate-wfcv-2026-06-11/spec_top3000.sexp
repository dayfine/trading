;; Harvest-rotate WF-CV surface — Cell-E top-3000-2011, 2011-2026, fork-per-fold.
;; baseline = enable_harvest_rotate=false (default). Variants flip it on and
;; sweep harvest_fraction (the trim fraction; 0.5 = the book's "sell half").
;; Step 4a of dev/plans/harvest-rotate-rigorous-test-2026-06-10.md.
((base_scenario "/workspaces/trading-1/dev/experiments/harvest-rotate-wfcv-2026-06-11/base_top3000.sexp")
 (window_spec
  (Rolling
   ((start_date 2011-01-01)(end_date 2026-04-30)(train_days 0)(test_days 365)(step_days 365))))
 (variants
  (((label "baseline") (overrides ()))
   ((label "harvest_k033")
    (overrides (((enable_harvest_rotate true)) ((harvest_fraction 0.33)))))
   ((label "harvest_k050")
    (overrides (((enable_harvest_rotate true)) ((harvest_fraction 0.5)))))
   ((label "harvest_k100")
    (overrides (((enable_harvest_rotate true)) ((harvest_fraction 1.0)))))))
 (baseline_label "baseline")
 (gate ((metric Sharpe)(m 8)(n 15)(worst_delta 0.30))))
