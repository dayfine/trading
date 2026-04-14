;; Expected metric ranges per scenario for the Weinstein strategy baseline.
;; Derived from 3 golden scenarios run on 2026-04-13 against 1,654 stocks.
;; Code version: main@origin at commit rqytmwpz (post #291 merge).
;;
;; Each scenario has its own ranges reflecting the market regime it covers.
;; A 2018-2023 run cannot be compared to a 2015-2020 run on the same scale —
;; the latter includes a strong bull market and produces ~5x returns.
;;
;; Results are NOT fully deterministic due to Hashtbl iteration ordering in
;; strategy internals (PR #298). Ranges below are set wide enough to absorb
;; this variance while still catching genuine regressions.
;;
;; Usage: future performance gate tests match scenario name, then compare
;; actual metrics against that scenario's ranges. A metric outside range
;; indicates regression (or improvement that warrants updating this file).

((scenarios
  ((name "2018-2023-six-year")
   (period ((start_date 2018-01-02) (end_date 2023-12-29)))
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
     (avg_holding_days 29.87)))
   (expected_ranges
    ((total_return_pct   ((min 30.0)  (max 90.0)))
     (total_trades       ((min 60)    (max 100)))
     (win_rate           ((min 22.0)  (max 40.0)))
     (sharpe_ratio       ((min 0.80)  (max 1.80)))
     (max_drawdown_pct   ((min 25.0)  (max 45.0)))
     (avg_holding_days   ((min 20.0)  (max 45.0))))))

  ((name "2015-2020-bull-crash")
   (period ((start_date 2015-01-02) (end_date 2020-12-31)))
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
     (avg_holding_days 49.58)))
   (expected_ranges
    ((total_return_pct   ((min 200.0) (max 400.0)))
     (total_trades       ((min 70)    (max 110)))
     (win_rate           ((min 25.0)  (max 45.0)))
     (sharpe_ratio       ((min 0.50)  (max 1.20)))
     (max_drawdown_pct   ((min 30.0)  (max 50.0)))
     (avg_holding_days   ((min 35.0)  (max 65.0))))))

  ((name "2020-2024-covid-recovery")
   (period ((start_date 2020-01-02) (end_date 2024-12-31)))
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
     (avg_holding_days 34.40)))
   (expected_ranges
    ((total_return_pct   ((min 15.0)  (max 45.0)))
     (total_trades       ((min 90)    (max 130)))
     (win_rate           ((min 40.0)  (max 55.0)))
     (sharpe_ratio       ((min 0.70)  (max 1.40)))
     (max_drawdown_pct   ((min 30.0)  (max 45.0)))
     (avg_holding_days   ((min 25.0)  (max 45.0))))))))
