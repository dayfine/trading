;; Continuation-add v2 WF-CV surface — BROAD-ONLY (top-3000 is the decisive
;; cell; NO sp500 cell per user directive 2026-07-04). Plan:
;; dev/plans/continuation-add-v2-2026-07-04.md (#1852); mechanism #1855.
;;
;; The shape under test: FULL-size initial entries + FULL-size continuation
;; adds (the book's Ch. 3 continuation buy) — the un-taxed press-the-winner
;; half of scale-in. extension_max_pct 0.25 is REQUIRED (consolidation
;; breakout closes sit up to ~22% above the 30w MA; 0.15 kills the trigger —
;; the "Either dead at 0.15" hazard, see scale_in_detector.mli).
;;
;; Run with --snapshot-dir /workspaces/trading-1/dev/data/snapshots/wfcv-top3000-1998
;; + --parallel 1 (fork-per-fold; N=3000 memory). PRE-FLIGHT: sweep-hygiene
;; checklist (Docker.raw < 30 GB — recompact first; 55 GB as of 2026-07-04).
;; Instrument add flow (emit/funded/filled) on the first fold before trusting
;; conclusions — the #1846 lesson. trades.csv is trustworthy post-#1847.
((base_scenario "/workspaces/trading-1/dev/experiments/continuation-add-v2-2026-07-05/base_top3000.sexp")
 (window_spec
  (Rolling
   ((start_date 2000-01-01)(end_date 2026-04-30)(train_days 0)(test_days 730)(step_days 730))))
 (variants
  (((label "baseline") (overrides ()))
   ((label "cont_add")
    (overrides (((enable_scale_in true))
                ((scale_in_config ((initial_entry_fraction 1.0)(add_fraction (1.0))(add_trigger Consolidation_breakout)(extension_max_pct 0.25)))))))
   ((label "cont_add_tight")
    (overrides (((enable_scale_in true))
                ((scale_in_config ((initial_entry_fraction 1.0)(add_fraction (1.0))(add_trigger Consolidation_breakout)(extension_max_pct 0.25)(consolidation ((band_pct 0.06)))))))))
   ((label "cont_add_vol")
    (overrides (((enable_scale_in true))
                ((scale_in_config ((initial_entry_fraction 1.0)(add_fraction (1.0))(add_trigger Consolidation_breakout)(extension_max_pct 0.25)(consolidation ((volume_ratio_min 1.5)))))))))))
 (baseline_label "baseline")
 (gate ((metric Sharpe)(m 7)(n 13)(worst_delta 0.30))))
