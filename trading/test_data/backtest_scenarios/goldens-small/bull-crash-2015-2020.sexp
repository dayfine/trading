;; Golden scenario: strong bull market through 2020 crash.
;;
;; Baseline re-pinned on 2026-04-18 post-PR #409 (`_held_symbols` now
;; excludes Closed positions → symbols re-enter after stop-out). 302-symbol
;; small universe (`universes/small.sexp`). Representative values:
;;   final_portfolio_value ~4.39M        total_return_pct ~339
;;   total_trades 15 (= n_round_trips)   win_rate ~37
;;   sharpe_ratio ~1.04                  max_drawdown_pct ~37
;;   avg_holding_days ~101               unrealized_pnl ~4.37M
;;
;; Pre-#409 the count was 6 round-trips because once a symbol's position
;; closed it was blacklisted from re-entry (bug). Post-#409, symbols cycle
;; multiple times.
;;
;; IMPORTANT: `total_trades` = `List.length round_trips` (completed
;; buy→sell cycles), NOT `wincount + losscount`.
;;
;; Previous baseline (1,654 stocks, 2026-04-13) preserved in git history.
;; Ranges are wider than observed values to absorb Hashtbl iteration ordering
;; noise (see PR #298).
;;
;; [unrealized_pnl] range is wide: goal is to catch regression to exactly 0
;; (PR #393's fix).
((name "bull-crash-2015-2020")
 (description "Strong bull market through the 2020 crash")
 (period ((start_date 2015-01-02) (end_date 2020-12-31)))
 (universe_size 302)
 (config_overrides ())
 (expected
  ((total_return_pct   ((min 250.0) (max 400.0)))
   (total_trades       ((min 10)    (max 25)))
   (win_rate           ((min 28.0)  (max 45.0)))
   (sharpe_ratio       ((min 0.60)  (max 1.40)))
   (max_drawdown_pct   ((min 30.0)  (max 45.0)))
   (avg_holding_days   ((min 80.0)  (max 140.0)))
   (unrealized_pnl     ((min 1000.0) (max 6000000.0))))))
