;; Exit-timing SURFACE sweep — DEEP 1998-2026 re-validation.
;;
;; Same 9-cell surface as exit-timing-surface-2026-05-30.sexp
;; (hysteresis_weeks {1,2,3} x stage3_exit_margin_pct {0.0,0.02,0.05}) + baseline,
;; but on the FULL 1998-2026 cycle (dotcom run-up + bust + GFC). Window migrated
;; from 2000-2026 per #1672 so the deep baseline captures the whole dotcom
;; round-trip (1998-99 run-up included) instead of starting near the peak.
;; Converts the exit-timing REJECT from single-regime (2010-2026, post-GFC bull)
;; to a genuinely multi-regime rejection — the standard codified in
;; .claude/rules/promotion-confirmation.md.
;;
;; Base scenario: goldens-sp500-historical/sp500-1998-2026.sexp — the committed
;; 28y deep base (as-of-1998 top-3000 composition snapshot, cell-E config). The
;; previous base (goldens-sp500-historical/sp500-2000-2026.sexp) was never
;; checked in — this spec's base_scenario dangled since creation; deep runs used
;; a research-dir scenario. Honest runs of this spec MUST be warehouse-backed
;; (--snapshot-dir over the delisting-complete top-3000 warehouse): a direct run
;; against committed test_data CSVs trades a survivor sliver (see the base
;; scenario's header warning).
;;
;; Geometry: Rolling 1998-2026, test_days=365 step_days=182 => 55 OOS folds
;; (pinned by test_spec.ml: gate.n must equal the generated count or
;; Fold_gate.evaluate SKIPs the verdict). Gate m=28 keeps the prior majority
;; ratio (26/51). Decision is the cross-variant ranking (Variant_ranking
;; Pareto + Deflated_sharpe), harvested post-run.

((base_scenario "goldens-sp500-historical/sp500-1998-2026.sexp")
 (window_spec
  (Rolling
   ((start_date 1998-01-01)
    (end_date 2026-04-30)
    (train_days 0)
    (test_days 365)
    (step_days 182))))
 (baseline_label "baseline")
 (gate ((metric Sharpe) (m 28) (n 55) (worst_delta 0.20)))
 (axes
  ((axes
    (((key (stage3_force_exit_config hysteresis_weeks)) (values (1 2 3)))
     ((key (stage3_exit_margin_pct)) (values (0.0 0.02 0.05)))))
   (expansion Cartesian))))
