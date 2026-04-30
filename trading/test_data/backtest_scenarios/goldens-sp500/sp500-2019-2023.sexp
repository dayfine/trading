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
;; Expected ranges pinned ±10-15% around the post-G9 with-shorts baseline
;; measured 2026-04-30 (see dev/notes/sp500-shortside-reenabled-2026-04-30.md
;; for the rerun results and dev/notes/short-side-gaps-2026-04-29.md for the
;; G1-G9 gap closure history). Re-pin with each deliberate strategy
;; behaviour change; don't bump these to absorb regressions.
;;
;; Measured baseline (2026-04-30, post-#710 G9 fix):
;;   total_return_pct  -0.01  total_trades 32   win_rate 37.50
;;   sharpe_ratio       0.01  max_drawdown 5.81  avg_holding_days 43.03
;;   unrealized_pnl     391,949   force_liquidations 0
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
  ((total_return_pct   ((min -15.0)       (max  15.0)))
   (total_trades       ((min 27)          (max  37)))
   (win_rate           ((min 31.0)        (max  44.0)))
   (sharpe_ratio       ((min -0.5)        (max  0.5)))
   (max_drawdown_pct   ((min 3.0)         (max  9.0)))
   (avg_holding_days   ((min 37.0)        (max  50.0)))
   (unrealized_pnl     ((min 330000.0)    (max  450000.0))))))
