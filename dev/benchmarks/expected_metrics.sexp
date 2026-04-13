;; Expected metric ranges for the Weinstein strategy baseline.
;; Derived from 3 golden scenarios run on 2026-04-13 against 1,654 stocks.
;; Code version: main@origin at commit rqytmwpz (post #291 merge).
;;
;; Results are NOT fully deterministic due to Hashtbl iteration ordering in
;; strategy internals (PR #298). Ranges below are set wide enough to absorb
;; this variance while still catching genuine regressions.
;;
;; Usage: future performance gate tests compare actual metrics against these
;; ranges. A metric outside its range indicates a regression (or improvement
;; that warrants updating this file).

((scenarios
  ((scenario_1
    ((period "2018-01-02 to 2023-12-29")
     (universe_size 1654)
     (observed
      ((final_portfolio_value 1569627.07)
       (total_return_pct 57.0)
       (total_pnl -14984.72)
       (win_count 22)
       (loss_count 55)
       (total_trades 77)
       (win_rate 28.57)
       (sharpe_ratio 1.28)
       (max_drawdown_pct 34.04)
       (avg_holding_days 29.87)))))

   (scenario_2
    ((period "2015-01-02 to 2020-12-31")
     (universe_size 1654)
     (observed
      ((final_portfolio_value 4054482.88)
       (total_return_pct 305.0)
       (total_pnl -5510.31)
       (win_count 28)
       (loss_count 56)
       (total_trades 84)
       (win_rate 33.33)
       (sharpe_ratio 0.79)
       (max_drawdown_pct 38.67)
       (avg_holding_days 49.58)))))

   (scenario_3
    ((period "2020-01-02 to 2024-12-31")
     (universe_size 1654)
     (observed
      ((final_portfolio_value 1268701.63)
       (total_return_pct 27.0)
       (total_pnl 38835.51)
       (win_count 52)
       (loss_count 57)
       (total_trades 109)
       (win_rate 47.71)
       (sharpe_ratio 1.00)
       (max_drawdown_pct 37.95)
       (avg_holding_days 34.40)))))))

 ;; Acceptable ranges across all scenarios. A future run that falls outside
 ;; these ranges should be investigated as a potential regression.
 (expected_ranges
  ((total_return_pct ((min 20.0) (max 350.0)))
   (total_trades     ((min 70)   (max 120)))
   (win_rate         ((min 25.0) (max 55.0)))
   (sharpe_ratio     ((min 0.60) (max 1.50)))
   (max_drawdown_pct ((min 25.0) (max 45.0)))
   (avg_holding_days ((min 20.0) (max 60.0))))))
