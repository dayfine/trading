;; w_early_stage2 reweight surface, top-3000-2011 2011-2026, fork-per-fold.
;; baseline = None (= w_stage2_breakout/2 = 15). axis values: Some 22/30/38.
((base_scenario "dev/experiments/cascade-reweight-wfcv-2026-06-10/base_top3000.sexp")
 (window_spec
  (Rolling
   ((start_date 2011-01-01)(end_date 2026-04-30)(train_days 0)(test_days 365)(step_days 365))))
 (axes
  (((key (screening_config weights w_early_stage2)) (values ((22) (30) (38))))))
 (variants (((label "baseline") (overrides ()))))
 (baseline_label "baseline")
 (gate ((metric Sharpe) (m 8) (n 15) (worst_delta 0.30))))
