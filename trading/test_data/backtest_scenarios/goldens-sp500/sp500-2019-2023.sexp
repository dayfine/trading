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
;; Expected ranges are pinned around the canonical run with cushion sized to
;; absorb the start-date IQR observed in the PR #788 fuzz (5 variants at
;; ±2w around 2019-01-02). Re-pin with each deliberate strategy behaviour
;; change; don't bump these to absorb regressions.
;;
;; Measured baseline (2026-05-02, post-#744+#745+#746+#771):
;;   total_return_pct  +60.86  total_trades 86   win_rate ~22.35
;;   sharpe_ratio       0.55   max_drawdown 34.15
;;
;; Verified via PR #788 fuzz: 5 variants ±2w start_date all returned
;; +37.92% to +60.86% / Sharpe 0.41-0.56 / MaxDD 31.28-35.99 / 82-99 trades
;; (see dev/experiments/fuzz-startdate-canonical-full/fuzz_distribution.md).
;; The pin shift from the prior 2026-04-30 baseline (-0.01% / 32 trades /
;; 5.81% MaxDD) reflects the structural changes in #744 (sizing fix), #745
;; (cash-deployment fix), #746 (long/short cap split), and #771 (stop
;; tuning). Bands are sized to absorb the fuzz IQR plus cushion so future
;; small drift (start-date sensitivity, calendar rolls) does not flap CI.
;;
;; (Pre-rename: this metric was named [unrealized_pnl] but its semantics
;; matched the renamed [Metric_types.OpenPositionsValue] — signed mtm value
;; of open positions, NOT true paper P&L. The rename in PR
;; feat/metrics-unrealized-pnl-rename clarifies the distinction; the
;; corrected [UnrealizedPnl] metric (= OpenPositionsValue minus position
;; cost basis) is now also emitted but not yet pinned here.)
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
  ((total_return_pct   ((min  30.0)       (max  70.0)))
   (total_trades       ((min 70)          (max 110)))
   (win_rate           ((min 15.0)        (max  35.0)))
   (sharpe_ratio       ((min  0.30)       (max   0.70)))
   (max_drawdown_pct   ((min 25.0)        (max  42.0)))
   (avg_holding_days   ((min 65.0)        (max 115.0)))
   (open_positions_value ((min 1200000.0) (max 1700000.0))))))
