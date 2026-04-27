;; perf-tier: 3
;; perf-tier-rationale: Hybrid-tier Phase 1 Experiment A control. Same shape as goldens-sp500/sp500-2019-2023.sexp (S&P 500, 5y) — runs head-to-head with sp500-no-candidates.sexp to decompose load-N vs active-N residency. Weekly cadence (~2:30 wall on the 2026-04-26 baseline). See dev/plans/hybrid-tier-phase1-2026-04-26.md.
;;
;; Hybrid-tier Phase 1 Experiment A — DEFAULT variant.
;;
;; Identical to goldens-sp500/sp500-2019-2023.sexp (zero overrides). The
;; sibling file sp500-no-candidates.sexp differs only in
;; (config_overrides ((screening_config ((max_buy_candidates 0) (max_short_candidates 0))))),
;; producing zero new positions over the run while keeping every other phase
;; (CSV load, panel build, screener cascade scoring) identical.
;;
;; Comparing peak RSS and wall between the two variants tells us whether
;; β = 4.3 MB / loaded symbol scales with loaded N (residency dominates) or
;; active N (per-position state dominates). See the experiment note at
;; dev/notes/hybrid-tier-phase1-cost-model-2026-04-26.md.
;;
;; Expected ranges intentionally wide — this scenario is for measurement,
;; not regression. The sister file goldens-sp500/sp500-2019-2023.sexp is the
;; tight-pinned regression golden.
((name "sp500-default-hybrid-tier-phase1")
 (description "Hybrid-tier Phase 1 Experiment A control — S&P 500 5y, no overrides")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 491)
 (config_overrides ())
 (expected
  ((total_return_pct   ((min -50.0)        (max 100.0)))
   (total_trades       ((min 50)           (max 300)))
   (win_rate           ((min 0.0)          (max 100.0)))
   (sharpe_ratio       ((min -5.0)         (max 5.0)))
   (max_drawdown_pct   ((min 0.0)          (max 80.0)))
   (avg_holding_days   ((min 0.0)          (max 365.0))))))
