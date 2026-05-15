;; Walk-forward regression fixture — 2026-05-08 hand-curated 8-fold
;; experiment encoded as a Window_spec.Explicit.
;;
;; Original experiment: dev/experiments/cell-e-walk-forward-2026-05-08/
;;   16 scenarios = 4 underlying windows × 2 chronological halves
;;                 × {Cell A, Cell E} = 8 (window, variant) cells × 2
;; verdict: Cell E won 11 of 12 distinct cell measurements.
;;
;; This fixture's purpose is NOT to reproduce the experiment results
;; (which require small + sp500 universes and ~30 min wall). Its purpose
;; is to assert the harness can EXPRESS the 8 folds via the Explicit
;; variant introduced in PR-A (#1111). The associated test asserts:
;;
;;   Spec.load <this file> |> .window_spec |> Window_spec.generate
;;     → 8 folds, names matching the original scenario names.
;;
;; Re-running the experiment via this fixture is a follow-up (out of
;; scope for PR-B per the plan).
;;
;; Note: bull-crash-2018-2020 and six-year-2018-2020 are bit-identical
;; windows; the original experiment kept both as distinct cells for
;; traceability. This fixture preserves that.
((base_scenario "goldens-small/bull-crash-2015-2020.sexp")
 (window_spec
  (Explicit
   (((name "bull-crash-2015-2017")
     (train_period ())
     (test_period ((start_date 2015-01-02) (end_date 2017-12-29))))
    ((name "bull-crash-2018-2020")
     (train_period ())
     (test_period ((start_date 2018-01-02) (end_date 2020-12-31))))
    ((name "covid-2020-2022h1")
     (train_period ())
     (test_period ((start_date 2020-01-02) (end_date 2022-06-30))))
    ((name "covid-2022h2-2024")
     (train_period ())
     (test_period ((start_date 2022-07-01) (end_date 2024-12-31))))
    ((name "six-year-2018-2020")
     (train_period ())
     (test_period ((start_date 2018-01-02) (end_date 2020-12-31))))
    ((name "six-year-2021-2023")
     (train_period ())
     (test_period ((start_date 2021-01-04) (end_date 2023-12-29))))
    ((name "sp500-2019-2021h1")
     (train_period ())
     (test_period ((start_date 2019-01-02) (end_date 2021-06-30))))
    ((name "sp500-2021h2-2023")
     (train_period ())
     (test_period ((start_date 2021-07-01) (end_date 2023-12-29)))))))
 (variants
  (;; Cell A — degenerate baseline: stage3 force-exit + laggard rotation
   ;; DISABLED. The 2026-05-08 cell-A.sexp scenarios used
   ;; (config_overrides ()) — they assumed the base scenario itself was
   ;; cell-A. Modern goldens have cell-E baked in, so we override back
   ;; to defaults here for the variant comparison.
   ((label "cell-A")
    (overrides
     (((enable_stage3_force_exit false))
      ((enable_laggard_rotation false)))))
   ;; Cell E — stage3 force-exit + laggard rotation ENABLED. Empty
   ;; overrides because cell-E is the canonical strategy config now;
   ;; the base scenario already encodes it.
   ((label "cell-E") (overrides ()))))
 (baseline_label "cell-A")
 ;; Gate: Cell E must beat Cell A on Sharpe in at least 5 of 8 folds,
 ;; with no fold worse by more than 0.30 Sharpe.  The original
 ;; experiment's "11 of 12" verdict gates harder than this — kept
 ;; loose here because PR-B does not run the sweep; the gate values
 ;; matter only when the follow-up sweep produces fold_actuals.
 (gate ((metric Sharpe) (m 5) (n 8) (worst_delta 0.30))))
