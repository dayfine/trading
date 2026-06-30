;; Hash re-run with FNV-1a (the h*31 hash was length-monotonic = Symbol_length).
;; baseline (Alphabetical, reproduces v1) + hash_random (Hash_order, FNV-1a fixed).
((base_scenario "/workspaces/trading-1/dev/experiments/tiebreak-noise-floor-2026-06-30/base_top1000.sexp")
 (window_spec
  (Rolling ((start_date 2000-01-01)(end_date 2026-04-30)(train_days 0)(test_days 730)(step_days 730))))
 (variants
  (((label "baseline") (overrides ()))
   ((label "hash_random")
    (overrides (((screening_config ((candidate_ranking Hash_order)))))))))
 (baseline_label "baseline")
 (gate ((metric Sharpe)(m 7)(n 13)(worst_delta 0.30))))
