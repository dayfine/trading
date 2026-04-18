;; Golden (broad): strong bull market through 2020 crash, against the full
;; sector-map universe.
;;
;; Intended for nightly/GHA scale runs — ≤3 broad goldens are kept for
;; full-universe regression coverage; see
;; dev/plans/backtest-scale-optimization-2026-04-17.md §Step 1.
;;
;; Expected ranges inherited from the 2026-04-13 baseline (1,654 stocks);
;; will shift under the expanded sector map (follow-up #3 in
;; dev/status/backtest-infra.md).
((name "bull-crash-2015-2020")
 (description "Strong bull market through the 2020 crash (broad universe)")
 (period ((start_date 2015-01-02) (end_date 2020-12-31)))
 (universe_path "universes/broad.sexp")
 (universe_size 1654)
 (config_overrides ())
 (expected
  ((total_return_pct   ((min 200.0) (max 400.0)))
   (total_trades       ((min 70)    (max 110)))
   (win_rate           ((min 25.0)  (max 45.0)))
   (sharpe_ratio       ((min 0.50)  (max 1.20)))
   (max_drawdown_pct   ((min 30.0)  (max 50.0)))
   (avg_holding_days   ((min 35.0)  (max 65.0)))
   (unrealized_pnl     ((min 1000.0) (max 8000000.0))))))
