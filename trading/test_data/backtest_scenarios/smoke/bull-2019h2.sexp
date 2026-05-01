;; perf-tier: 2
;; perf-tier-rationale: 1654-symbol full-universe smoke over 6 months, ~5-10 min wall; too heavy for per-PR gate (≤2 min) — fits nightly cadence. See dev/plans/perf-scenario-catalog-2026-04-25.md tier 2.
;;
;; Smoke scenario: bullish second half of 2019. Runs quickly (~5-10 min).
;; Ranges are broad sanity checks, not regression gates.
;;
;; [open_positions_value] range is intentionally wide: it catches regression
;; to exactly 0 (the bug PR #393 fixed) as well as unreasonable values, while
;; tolerating the universe-size flux documented under follow-up #3 in
;; dev/status/backtest-infra.md. (Pre-rename this pin was named
;; [unrealized_pnl] but its semantics matched the renamed
;; [Metric_types.OpenPositionsValue] — signed mtm, not true paper P&L.)
((name "bull-2019h2")
 (description "Bull market sanity check (H2 2019)")
 (period ((start_date 2019-06-01) (end_date 2019-12-31)))
 (universe_size 1654)
 (config_overrides ())
 (expected
  ((total_return_pct   ((min -10.0) (max 40.0)))
   (total_trades       ((min 0)     (max 40)))
   (win_rate           ((min 0.0)   (max 100.0)))
   (sharpe_ratio       ((min -2.0)  (max 5.0)))
   (max_drawdown_pct   ((min 0.0)   (max 30.0)))
   (avg_holding_days   ((min 0.0)   (max 100.0)))
   (open_positions_value ((min 1000.0) (max 2000000.0))))))
