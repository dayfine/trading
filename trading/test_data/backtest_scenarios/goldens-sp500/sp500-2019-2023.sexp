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
 ;; enable_short_side disabled 2026-04-29: short-side gaps surfaced on the
 ;; sp500 baseline rerun (post-#680). 128 short entries during 2019's Bearish
 ;; macro rode the 2020-2023 bull market with stops not firing correctly; the
 ;; portfolio went negative on multiple days. Until short-side stops + the
 ;; visibility/force-liquidation gaps are closed, this scenario runs long-only.
 ;; Tracked in dev/notes/short-side-gaps-2026-04-29.md.
 (config_overrides (((enable_short_side false))))
 ;; BASELINE_PENDING — wide ranges while we capture the long-only baseline
 ;; (post-#680, enable_short_side=false). Re-pin once the maintainer-local
 ;; rerun lands and the short-side gaps note has the corrected metrics.
 (expected
  ((total_return_pct   ((min -100.0)      (max 500.0)))
   (total_trades       ((min 0)           (max 1000)))
   (win_rate           ((min 0.0)         (max 100.0)))
   (sharpe_ratio       ((min -10.0)       (max 10.0)))
   (max_drawdown_pct   ((min 0.0)         (max 100.0)))
   (avg_holding_days   ((min 0.0)         (max 1000.0)))
   (unrealized_pnl     ((min -10000000.0) (max 10000000.0))))))
