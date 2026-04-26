;; perf-tier: 4
;; perf-tier-rationale: Full sector-map (broad) universe over 6 years incl. COVID; release-gate cadence (≤8 h). Currently SKIPPED placeholder pending re-pin and data-panels Stage-4 (5000-symbol broadening). See dev/plans/perf-scenario-catalog-2026-04-25.md tier 4.
;;
;; STATUS: SKIPPED — ranges stale (1,654-symbol era); re-pin pending a GHA
;; workflow. Do not treat as a regression gate until re-pinned. See
;; `dev/status/backtest-infra.md` follow-up.
;;
;; Golden (broad): 6-year run covering COVID crash and recovery, against the
;; full sector-map universe.
;;
;; Intended for nightly/GHA scale runs — ≤3 broad goldens are kept for
;; full-universe regression coverage; see
;; dev/plans/backtest-scale-optimization-2026-04-17.md §Step 1 and
;; dev/decisions.md 2026-04-17 item 2.
;;
;; Shares the same name as the small-universe counterpart under
;; goldens-small/ for easy A/B; the runner keys by [name + universe_path].
;; Expected ranges here are inherited from the 2026-04-13 baseline
;; (1,654-symbol universe) and remain the apples-to-apples reference
;; until a post-Finviz baseline re-run updates them
;; (dev/status/backtest-infra.md follow-up #3).
;;
;; [unrealized_pnl] range is wide: the goal is to catch regression to
;; exactly 0 (the bug PR #393 fixed). The universe has grown from 1,654 to
;; ~10,472 stocks, so the exact value at the upper end will shift when
;; the goldens are rerun; pick a ceiling high enough to tolerate that
;; without re-pinning per sector-map refresh.
((name "six-year-2018-2023")
 (description "6-year run covering COVID crash and recovery (broad universe)")
 (period ((start_date 2018-01-02) (end_date 2023-12-29)))
 (universe_path "universes/broad.sexp")
 (universe_size 1654)
 (config_overrides ())
 (expected
  ((total_return_pct   ((min 30.0)  (max 90.0)))
   (total_trades       ((min 60)    (max 100)))
   (win_rate           ((min 22.0)  (max 40.0)))
   (sharpe_ratio       ((min 0.80)  (max 1.80)))
   (max_drawdown_pct   ((min 25.0)  (max 45.0)))
   (avg_holding_days   ((min 20.0)  (max 45.0)))
   (unrealized_pnl     ((min 1000.0) (max 3000000.0))))))
