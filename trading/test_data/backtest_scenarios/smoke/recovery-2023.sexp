;; Smoke scenario: calendar year 2023 recovery. Runs quickly (~5-10 min).
;; Ranges are broad sanity checks, not regression gates.
;;
;; [unrealized_pnl] range is intentionally wide: it catches regression to
;; exactly 0 (the bug PR #393 fixed) as well as unreasonable values, while
;; tolerating the universe-size flux documented under follow-up #3 in
;; dev/status/backtest-infra.md.
((name "recovery-2023")
 (description "Recovery regime sanity check (2023)")
 (period ((start_date 2023-01-02) (end_date 2023-12-31)))
 (universe_size 1654)
 (config_overrides ())
 (expected
  ((total_return_pct   ((min -20.0) (max 60.0)))
   (total_trades       ((min 0)     (max 60)))
   (win_rate           ((min 0.0)   (max 100.0)))
   (sharpe_ratio       ((min -2.0)  (max 5.0)))
   (max_drawdown_pct   ((min 0.0)   (max 40.0)))
   (avg_holding_days   ((min 0.0)   (max 100.0)))
   (unrealized_pnl     ((min 1000.0) (max 2000000.0))))))
