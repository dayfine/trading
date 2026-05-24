;; Walk-forward primary fixture — 28-fold annual non-overlapping OOS
;; window across the full 1998-2026 delisted-aware top-3000 universe.
;; Authored against `dev/plans/tuning-research-driven-program-v2-2026-05-25.md`
;; Milestone M4 (T4.1).
;;
;; Mathematics: start_date=1998-01-01, end_date=2026-04-30 spans 10,346
;; calendar days. With test_days=365 and step_days=365, anchors are
;; placed annually; the harness keeps each fold whose test window fits
;; before end_date.
;;
;;   first anchor: 1998-01-01, test 1998-01-01..1998-12-31
;;   28th anchor:  2025-01-01 (= 1998-01-01 + 27*365), test ..2025-12-31
;;   29th anchor:  2026-01-01, test ..2026-12-31 (past end_date → dropped)
;;
;; So the expected fold count is 28 (target). The pinned test asserts
;; the count lands in [27, 29] to absorb leap-year drift across the
;; 28-year span (365-day step vs 365.25-day astronomical year ≈ 7-day
;; cumulative drift over 28 years).
;;
;; **Plan v2 delta #4 — Cell E baseline dropped for 1998-2026 sweep.**
;; The Pareto vector for the M4 sweep is (mean_sharpe, mean_max_dd,
;; pass-vs-BAH-SPY, pass-vs-BAH-BRK-A); there is no Cell-A
;; counterpart for the 1998-2026 window worth re-computing. This
;; fixture therefore ships a single `cell-E` variant (empty overrides
;; — base scenario already encodes Cell E).
;;
;; **Gate is non-firing by construction.** `Spec.t` requires the
;; field, but the sweep's go/no-go logic is multi-objective and lives
;; in the BO scorer (qNEHVI Pareto front + DSR + outer-holdout per M2
;; / M3), not in this gate. With `m=0` and a huge `worst_delta`, the
;; gate trivially passes regardless of fold-actuals and serves only as
;; structural placeholder until the schema is relaxed.
;;
;; **Holdout folds**: the last 4 of 28 folds (1-indexed 25-28) are
;; reserved as out-of-sample validation for the Bayesian tuner per
;; plan §M3. The walk-forward runner ignores `holdout_folds`
;; ([\@\@sexp.allow_extra_fields] on Spec.t); the BO scorer consumes
;; the list via Phase-3 `Bayesian_runner_spec`.
;;
;; **Universe rotation** through the 28 top-3000-YYYY snapshots is
;; T4.2's responsibility; the base scenario points at top-3000-1998
;; as a placeholder.
((base_scenario "goldens-sp500-historical/sp500-1998-2026.sexp")
 (window_spec
  (Rolling
   ((start_date 1998-01-01)
    (end_date 2026-04-30)
    (train_days 0) ;; OOS-only — no separate train window
    (test_days 365)
    (step_days 365)))) ;; annual non-overlapping; finer granularity (182d → ~56 folds) is a follow-up
 (variants
  (;; cell-E: empty overrides (uses base scenario's config as-is).
   ;; Single variant — no cell-A counterpart for 1998-2026 per plan delta #4.
   ((label "cell-E") (overrides ()))))
 (baseline_label "cell-E")
 ;; Non-firing gate (placeholder; Spec.t requires the field). The M4
 ;; sweep gates on qNEHVI Pareto front + DSR + outer-holdout, not on
 ;; per-fold M-of-N. m=0 + huge worst_delta means evaluate() trivially
 ;; passes for any fold actuals.
 (gate ((metric Sharpe) (m 0) (n 28) (worst_delta 100.0)))
 ;; Phase-3 BO holdout: last 4 of 28 folds (~2022-2025 by anchor).
 (holdout_folds (25 26 27 28)))
