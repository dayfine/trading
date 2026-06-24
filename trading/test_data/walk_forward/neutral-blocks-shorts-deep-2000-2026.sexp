;; neutral_blocks_shorts WF-CV — DEEP 2000-2026, promote-track validation.
;;
;; The faithful-short deep screen (faithful-short-deep-screen-2026-06-22) found
;; neutral_blocks_shorts strictly helpful-or-inert across a bull (2010-26) and a
;; bear (2000-10) regime: inert in bears (all shorts already Bearish-tape) and
;; removes the loss-making bull-regime Neutral-tape squeeze shorts. This WF-CV is
;; the promote-track step (experiment-gap-closing → promotion-confirmation.md):
;; does true ≥ baseline across rolling OOS folds spanning dot-com + GFC + bull?
;;
;; 2-cell flag axis on the deep long-short base. Rolling 2000-2026, test 365 /
;; step 365 (train 0) => ~26 non-overlapping OOS folds. Decision = cross-variant
;; Variant_ranking (Pareto) + Deflated_sharpe, harvested post-run with
;; rank_variants. CSV mode reads the gitignored data/ deep store (1998-2026).
;; Caveat: static sp500-as-of-2000 universe (stale in late folds) — affects both
;; cells equally, so the baseline-vs-variant comparison holds; the short-gate
;; decision is macro/index-driven (universe-independent) regardless.
((base_scenario "test_data/backtest_scenarios/goldens-sp500-historical/sp500-2000-2026-longshort.sexp")
 (window_spec
  (Rolling
   ((start_date 2000-01-01)
    (end_date 2026-04-30)
    (train_days 0)
    (test_days 365)
    (step_days 365))))
 (baseline_label "baseline")
 (gate ((metric Sharpe) (m 14) (n 26) (worst_delta 0.0)))
 (axes
  ((axes
    (((flag neutral_blocks_shorts) (values (true false)))))
   (expansion Cartesian))))
