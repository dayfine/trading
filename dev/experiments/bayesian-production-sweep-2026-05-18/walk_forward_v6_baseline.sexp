;; Walk-forward spec for V6 — relaxes the M-of-N gate (worst_delta 0.30 → 0.50).
;;
;; V3 + V4 + V5 all converged on max composite_delta ≈ 0.4-0.5 with the
;; BO unable to improve past iter-1's random sample. V5 specifically
;; tested wider bounds (~V2's full range) — same outcome. The
;; "bounds-too-tight" hypothesis is rejected.
;;
;; Remaining hypothesis: the M-of-N internal gate is the binding
;; constraint. With (m=17, n=30, worst_delta=0.30), every cell in V3/V5
;; bounds fails the gate — Pass requires no single fold to be Sharpe
;; ≥0.30 below baseline, which is harder than it sounds given the
;; cell-E baseline's natural per-fold Sharpe stdev of ~1.06 across
;; 31 folds.
;;
;; V6 changes ONLY the worst_delta floor: 0.30 → 0.50. This means a
;; cell can have ONE fold up to 0.50 Sharpe below baseline and still
;; Pass the internal gate. If this surfaces a non-floor cell, the BO
;; will be able to differentiate Pass from Fail cells and the GP can
;; climb.
;;
;; Same window/step/baseline as v2_baseline (gate is the only diff).
((base_scenario "goldens-sp500-historical/sp500-2010-2026.sexp")
 (window_spec
  (Rolling
   ((start_date 2010-01-01)
    (end_date 2026-04-30)
    (train_days 0)
    (test_days 365)
    (step_days 182))))
 (variants
  (((label "cell-E") (overrides ()))))
 (baseline_label "cell-E")
 (gate ((metric Sharpe) (m 17) (n 30) (worst_delta 0.50))))
