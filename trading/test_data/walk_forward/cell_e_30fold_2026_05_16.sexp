;; Walk-forward production fixture — ~30 rolling OOS folds across the
;; full 2010-2026 sp500 historical window, gated on Sharpe.
;;
;; Mathematics: start_date=2010-01-01, end_date=2026-04-30 spans 5,966
;; calendar days. With test_days=365 and step_days=182, anchors are
;; placed every 182 days; the harness keeps each fold whose test
;; window fits before end_date.
;;
;;   first anchor: 2010-01-01, test 2010-01-01..2010-12-31
;;   last anchor:  2025-04-30, test 2025-04-30..2026-04-29
;;   anchor stride 182 days → (5966 - 365) / 182 ≈ 30.78 → 30 folds.
;;
;; PR-B ships this spec; the actual sweep is a local-only follow-up
;; (multi-hour wall-time). The pinned test asserts ≥28 folds (target
;; 30, allow end-of-range clamping for leap years / non-365-day-year
;; calendar drift).
;;
;; Baseline = cell-E (the canonical strategy config). Variant cell-A
;; is the degenerate baseline (no stage3 force-exit, no laggard
;; rotation) — the harness needs a "known no-op comparison" to
;; sanity-check the gate plumbing. If cell-A wins on a fold, that's
;; signal worth investigating.
((base_scenario "goldens-sp500-historical/sp500-2010-2026.sexp")
 (window_spec
  (Rolling
   ((start_date 2010-01-01)
    (end_date 2026-04-30)
    (train_days 0) ;; OOS-only — no separate train window
    (test_days 365)
    (step_days 182))))
 (variants
  (;; cell-A: disables Cell E features for direct comparison.
   ((label "cell-A")
    (overrides
     (((enable_stage3_force_exit false))
      ((enable_laggard_rotation false)))))
   ;; cell-E: empty overrides (uses base scenario's config as-is).
   ((label "cell-E") (overrides ()))))
 (baseline_label "cell-E")
 ;; Gate: cell-A must beat cell-E on Sharpe in ≥17 of 30 folds, no
 ;; fold worse by >0.30 Sharpe. We're gating on cell-A vs cell-E
 ;; (cell-E is baseline), so a PASS would mean cell-E feature
 ;; bundle is NOT a net win — signal worth investigating.
 (gate ((metric Sharpe) (m 17) (n 30) (worst_delta 0.30))))
