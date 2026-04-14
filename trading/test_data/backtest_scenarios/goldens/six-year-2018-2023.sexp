;; Golden scenario: 6-year run covering COVID crash and recovery.
;;
;; Baseline observed on 2026-04-13 against 1,654 stocks:
;;   final_portfolio_value 1569627.07
;;   total_return_pct 57.0   total_trades 77   win_rate 28.57
;;   sharpe_ratio 1.28       max_drawdown_pct 34.04   avg_holding_days 29.87
;;
;; Expected ranges are intentionally wider than observed values to absorb
;; non-determinism from Hashtbl iteration ordering (see PR #298).
((name "six-year-2018-2023")
 (description "6-year run covering COVID crash and recovery")
 (period ((start_date 2018-01-02) (end_date 2023-12-29)))
 (universe_size 1654)
 (config_overrides ())
 (expected
  ((total_return_pct   ((min 30.0)  (max 90.0)))
   (total_trades       ((min 60)    (max 100)))
   (win_rate           ((min 22.0)  (max 40.0)))
   (sharpe_ratio       ((min 0.80)  (max 1.80)))
   (max_drawdown_pct   ((min 25.0)  (max 45.0)))
   (avg_holding_days   ((min 20.0)  (max 45.0))))))
