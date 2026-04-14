;; Golden scenario: COVID crash and recovery through 2024.
;;
;; Baseline observed on 2026-04-13 against 1,654 stocks:
;;   final_portfolio_value 1268701.63
;;   total_return_pct 27.0   total_trades 109  win_rate 47.71
;;   sharpe_ratio 1.00       max_drawdown_pct 37.95   avg_holding_days 34.40
;;
;; Expected ranges are intentionally wider than observed values to absorb
;; non-determinism from Hashtbl iteration ordering (see PR #298).
((name "covid-recovery-2020-2024")
 (description "COVID crash and recovery through 2024")
 (period ((start_date 2020-01-02) (end_date 2024-12-31)))
 (universe_size 1654)
 (config_overrides ())
 (expected
  ((total_return_pct   ((min 15.0)  (max 45.0)))
   (total_trades       ((min 90)    (max 130)))
   (win_rate           ((min 40.0)  (max 55.0)))
   (sharpe_ratio       ((min 0.70)  (max 1.40)))
   (max_drawdown_pct   ((min 30.0)  (max 45.0)))
   (avg_holding_days   ((min 25.0)  (max 45.0))))))
