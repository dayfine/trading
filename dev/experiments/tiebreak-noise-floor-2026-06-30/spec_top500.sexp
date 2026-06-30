;; Noise-floor control tiebreaks — top500 PIT-1998, 2000-2026, 13 folds.
;; baseline (Alphabetical) + 3 UNINFORMATIVE controls (reverse-alpha, symbol-length,
;; deterministic hash~random). Brackets the selection noise floor: if all controls
;; cluster and RS(#1788)/earliness sit inside, "no sort beats unbiased sampling" is proven.
((base_scenario "/workspaces/trading-1/dev/experiments/tiebreak-noise-floor-2026-06-30/base_top500.sexp")
 (window_spec
  (Rolling
   ((start_date 2000-01-01)(end_date 2026-04-30)(train_days 0)(test_days 730)(step_days 730))))
 (variants
  (((label "baseline") (overrides ()))
   ((label "reverse_alpha")
    (overrides (((screening_config ((candidate_ranking Reverse_alphabetical)))))))
   ((label "symbol_length")
    (overrides (((screening_config ((candidate_ranking Symbol_length)))))))
   ((label "hash_random")
    (overrides (((screening_config ((candidate_ranking Hash_order)))))))))
 (baseline_label "baseline")
 (gate ((metric Sharpe)(m 7)(n 13)(worst_delta 0.30))))
