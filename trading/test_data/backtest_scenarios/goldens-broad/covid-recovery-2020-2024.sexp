;; Golden (broad): COVID crash and recovery through 2024, against the full
;; sector-map universe.
;;
;; Intended for nightly/GHA scale runs — ≤3 broad goldens are kept for
;; full-universe regression coverage; see
;; dev/plans/backtest-scale-optimization-2026-04-17.md §Step 1.
;;
;; Expected ranges inherited from the 2026-04-13 baseline (1,654 stocks);
;; will shift under the expanded sector map (follow-up #3 in
;; dev/status/backtest-infra.md).
((name "covid-recovery-2020-2024")
 (description "COVID crash and recovery through 2024 (broad universe)")
 (period ((start_date 2020-01-02) (end_date 2024-12-31)))
 (universe_path "universes/broad.sexp")
 (universe_size 1654)
 (config_overrides ())
 (expected
  ((total_return_pct   ((min 15.0)  (max 45.0)))
   (total_trades       ((min 90)    (max 130)))
   (win_rate           ((min 40.0)  (max 55.0)))
   (sharpe_ratio       ((min 0.70)  (max 1.40)))
   (max_drawdown_pct   ((min 30.0)  (max 45.0)))
   (avg_holding_days   ((min 25.0)  (max 45.0)))
   (unrealized_pnl     ((min 1000.0) (max 3000000.0))))))
