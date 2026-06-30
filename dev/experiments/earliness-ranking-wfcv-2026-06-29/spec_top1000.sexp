;; Candidate-ranking tiebreak WF-CV surface — Cell-E broad top-1000 PIT-1998,
;; 2000-2026, 2-year non-overlapping folds (13 folds), fork-per-fold.
;; baseline = candidate_ranking=Alphabetical (default, current behavior);
;; variant = candidate_ranking=Quality (RS magnitude -> earliness -> volume tiebreak).
;; FRAMING: this is a FAITHFULNESS/realism fix (RS-for-selection is a Weinstein
;; spine item), NOT a return-seeking lever. Success bar = DO-NO-HARM across folds
;; (not "beat baseline"). The two arms are bit-identical except where score ties
;; at the cap/cash boundary get reordered, so expect near-identical metrics.
((base_scenario "/workspaces/trading-1/dev/experiments/earliness-ranking-wfcv-2026-06-29/base_top1000.sexp")
 (window_spec
  (Rolling
   ((start_date 2000-01-01)(end_date 2026-04-30)(train_days 0)(test_days 730)(step_days 730))))
 (variants
  (((label "baseline") (overrides ()))
   ((label "earliness_ranking")
    (overrides (((screening_config ((candidate_ranking Quality_earliness)))))))))
 (baseline_label "baseline")
 (gate ((metric Sharpe)(m 7)(n 13)(worst_delta 0.30))))
