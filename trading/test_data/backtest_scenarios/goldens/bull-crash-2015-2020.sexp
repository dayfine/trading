;; Golden scenario: strong bull market through 2020 crash.
;;
;; Baseline observed on 2026-04-13 against 1,654 stocks:
;;   final_portfolio_value 4054482.88
;;   total_return_pct 305.0   total_trades 84   win_rate 33.33
;;   sharpe_ratio 0.79        max_drawdown_pct 38.67   avg_holding_days 49.58
;;
;; Expected ranges are intentionally wider than observed values to absorb
;; non-determinism from Hashtbl iteration ordering (see PR #298).
((name "bull-crash-2015-2020")
 (description "Strong bull market through the 2020 crash")
 (period ((start_date 2015-01-02) (end_date 2020-12-31)))
 (universe_size 1654)
 (config_overrides ())
 (expected
  ((total_return_pct   ((min 200.0) (max 400.0)))
   (total_trades       ((min 70)    (max 110)))
   (win_rate           ((min 25.0)  (max 45.0)))
   (sharpe_ratio       ((min 0.50)  (max 1.20)))
   (max_drawdown_pct   ((min 30.0)  (max 50.0)))
   (avg_holding_days   ((min 35.0)  (max 65.0))))))
