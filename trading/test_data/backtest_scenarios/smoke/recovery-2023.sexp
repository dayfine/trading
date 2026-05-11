;; perf-tier: 2
;; perf-tier-rationale: 1654-symbol full-universe smoke over 12 months, ~5-10 min wall; too heavy for per-PR gate (≤2 min) — fits nightly cadence. See dev/plans/perf-scenario-catalog-2026-04-25.md tier 2.
;;
;; Smoke scenario: calendar year 2023 recovery. Runs quickly (~5-10 min).
;; Ranges are broad sanity checks, not regression gates.
;;
;; [open_positions_value] range is intentionally wide: it catches regression
;; to exactly 0 (the bug PR #393 fixed) as well as unreasonable values, while
;; tolerating the universe-size flux documented under follow-up #3 in
;; dev/status/backtest-infra.md. (Pre-rename this pin was named
;; [unrealized_pnl] but its semantics matched the renamed
;; [Metric_types.OpenPositionsValue] — signed mtm, not true paper P&L.)
;;
;; Cell E rollout 2026-05-11: standard strategy config applied for consistency
;; with goldens. Trade count widens ~3-10x; ranges loosened. Smoke gate.
((name "recovery-2023")
 (description "Recovery regime sanity check (2023) — Cell E config")
 (period ((start_date 2023-01-02) (end_date 2023-12-31)))
 (universe_size 1654)
 (config_overrides
  (((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (expected
  ((total_return_pct   ((min -30.0) (max 200.0)))
   (total_trades       ((min 0)     (max 500)))
   (win_rate           ((min 0.0)   (max 100.0)))
   (sharpe_ratio       ((min -2.0)  (max 5.0)))
   (max_drawdown_pct   ((min 0.0)   (max 60.0)))
   (avg_holding_days   ((min 0.0)   (max 200.0)))
   (open_positions_value ((min 1000.0) (max 5000000.0))))))
