;; perf-tier: 3
;; perf-tier-rationale: ~500-symbol S&P 500 universe over 5 years (2019-2023, includes COVID + recovery + 2022 bear). Weekly cadence (≤2 h budget). See dev/plans/perf-scenario-catalog-2026-04-25.md tier 3.
;;
;; S&P 500 golden — regression-pinned trading + performance benchmark.
;; Universe is a 491-symbol S&P 500 snapshot (universes/sp500.sexp,
;; generated 2026-04-26). Period covers a full Weinstein cycle:
;;   * 2019: late-cycle advance.
;;   * 2020 H1: COVID crash (Stage 4 trigger).
;;   * 2020 H2 - 2021: V-shaped recovery (Stage 1 → Stage 2 transitions).
;;   * 2022: bear (Stage 4 across most names).
;;   * 2023: recovery, leadership rotation.
;;
;; This is the foundation benchmark for downstream feature work — short-side
;; strategy, segmentation-based stage classifier, stop-buffer tuning, etc.
;; Once metrics here are pinned, follow-on PRs measure against this baseline.
;;
;; Initial expected ranges tightened to ±10–15% around the baseline measured
;; on 2026-04-26 (see dev/notes/sp500-golden-baseline-2026-04-26.md for the
;; baseline run and reasoning). Re-pin with each deliberate strategy
;; behaviour change; don't bump these to absorb regressions.
;;
;; The S&P 500 is a moving target; the universe sexp is a fixed snapshot
;; so reruns are reproducible. Refresh the universe via the build script
;; (TODO: dev/scripts/build_sp500_universe.sh) when re-baselining.
((name "sp500-2019-2023")
 (description "S&P 500 over 2019-2023 — full Weinstein cycle benchmark")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 491)
 (config_overrides ())
 (expected
  ((total_return_pct   ((min 15.0)        (max 22.0)))
   (total_trades       ((min 125)         (max 145)))
   (win_rate           ((min 24.0)        (max 33.0)))
   (sharpe_ratio       ((min 0.05)        (max 0.50)))
   (max_drawdown_pct   ((min 40.0)        (max 55.0)))
   (avg_holding_days   ((min 75.0)        (max 90.0)))
   (unrealized_pnl     ((min 1000000.0)   (max 1300000.0))))))
