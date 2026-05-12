;; H1 vs H2 diagnostic — extreme single-dim sweeps to confirm whether the
;; screener-weight axis is functionally inert under the cascade gate.
;;
;; Hypothesis (from grid-screening-weights-2026-05-12/report.md):
;;   H1 — cascade is grade-driven; uniform scaling of weights leaves ranking
;;        the same → score is monotonic → no candidate-set change. Confirmed
;;        by any narrow-range grid showing identical metrics.
;;   H2 — 0.5..1.5 range is too narrow to flip ranking ties; an extreme range
;;        (0.0..5.0) might surface ranking inversions.
;;
;; Test: 2×1×1×1 grid (rs = {0.0, 5.0}, others = 1.0) — 2 cells × 3 scenarios.
;; If both cells produce identical metrics → H1 confirmed (weights are inert).
;; If they differ → H2: the previous 81-cell 0.5..1.5 range was just too narrow.
;;
;; Wall-time at --parallel 2 on smoke catalog: ~15min.
((params
   (("screening_config.weights.rs"       (0.0 5.0))))
 (objective Sharpe)
 (scenarios
   ("trading/test_data/backtest_scenarios/smoke/bull-2019h2.sexp"
    "trading/test_data/backtest_scenarios/smoke/crash-2020h1.sexp"
    "trading/test_data/backtest_scenarios/smoke/recovery-2023.sexp")))
