;; 81-cell flagship sweep on screening.weights.* (M5.5 T-A).
;;
;; 4-dim grid (3^4 = 81 cells) over the four primary screener-scoring weights.
;; Smoke catalog window keeps wall-time under the 2hr gate documented in
;; dev/status/tuning.md §"Remaining work".
;;
;; Objective: Sharpe (single-metric scalar that is both signed-meaningful and
;; comparable across cells).
;;
;; Acceptance criterion (per m5-experiments-roadmap-2026-05-02.md §M5.5 T-A):
;; - Best cell must produce a strictly-higher Sharpe than the baseline
;;   (rs=1.0, volume=1.0, breakout=1.0, sector=1.0) — otherwise the
;;   screener-weight axis isn't worth tuning further and we can pin defaults.
;; - Wall-time <= 2hr on smoke scenarios.
((params
   (("screening_config.weights.rs"       (0.5 1.0 1.5))
    ("screening_config.weights.volume"   (0.5 1.0 1.5))
    ("screening_config.weights.breakout" (0.5 1.0 1.5))
    ("screening_config.weights.sector"   (0.5 1.0 1.5))))
 (objective Sharpe)
 (scenarios
   ("trading/test_data/backtest_scenarios/smoke/bull-2019h2.sexp"
    "trading/test_data/backtest_scenarios/smoke/crash-2020h1.sexp"
    "trading/test_data/backtest_scenarios/smoke/recovery-2023.sexp")))
