;; perf-tier: 2
;; perf-tier-rationale: 1654-symbol full-universe smoke over 6 months, ~5-10 min wall; too heavy for per-PR gate (≤2 min) — fits nightly cadence. See dev/plans/perf-scenario-catalog-2026-04-25.md tier 2.
;;
;; Smoke scenario: first half of 2020 (COVID crash). Runs quickly (~5-10 min).
;; Ranges are broad sanity checks, not regression gates.
;;
;; [open_positions_value] / [unrealized_pnl] are NOT pinned here because a
;; crash regime can plausibly leave the portfolio fully liquidated (all stops
;; hit) OR holding a few late-stage positions — the end-of-window state is
;; too regime-dependent to pick a single range. Revisit once follow-up #3
;; (universe rerun) lands.
;;
;; Cell E rollout 2026-05-11: standard strategy config applied for consistency
;; with goldens. Trade count widens ~3-10x; ranges loosened. Smoke gate.
((name "crash-2020h1")
 (description "Crash regime sanity check (H1 2020) — Cell E config")
 (period ((start_date 2020-01-02) (end_date 2020-06-30)))
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
  ((total_return_pct   ((min -70.0) (max 50.0)))
   (total_trades       ((min 0)     (max 500)))
   (win_rate           ((min 0.0)   (max 100.0)))
   (sharpe_ratio       ((min -5.0)  (max 3.0)))
   (max_drawdown_pct   ((min 0.0)   (max 80.0)))
   (avg_holding_days   ((min 0.0)   (max 200.0))))))
