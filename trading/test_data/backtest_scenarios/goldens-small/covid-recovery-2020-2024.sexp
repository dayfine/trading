;; perf-tier: 2
;; perf-tier-rationale: 302-symbol small universe over 5 years; nightly cadence (≤30 min budget). See dev/plans/perf-scenario-catalog-2026-04-25.md tier 2.
;;
;; Golden scenario: COVID crash and recovery through 2024.
;;
;; Baseline re-pinned on 2026-04-18 post-PR #409 (`_held_symbols` now
;; excludes Closed positions → symbols re-enter after stop-out). 302-symbol
;; small universe (`universes/small.sexp`). Representative values:
;;   final_portfolio_value ~1.08M        total_return_pct ~8
;;   total_trades 21 (= n_round_trips)   win_rate ~31
;;   sharpe_ratio ~0.17                  max_drawdown_pct ~36
;;   avg_holding_days ~70                unrealized_pnl ~0.86M
;;
;; Pre-#409 the count was 8 round-trips; post-#409, symbols cycle
;; multiple times through the 2020 crash + 2022 correction. Return is
;; low-single-digit positive due to choppy regime; pin range is wide.
;;
;; IMPORTANT: `total_trades` = `List.length round_trips` (completed
;; buy→sell cycles), NOT `wincount + losscount`.
;;
;; Previous baseline (1,654 stocks, 2026-04-13) preserved in git history.
;;
;; [unrealized_pnl] range is wide: goal is to catch regression to exactly 0
;; (PR #393's fix).
((name "covid-recovery-2020-2024")
 (description "COVID crash and recovery through 2024")
 (period ((start_date 2020-01-02) (end_date 2024-12-31)))
 (universe_size 302)
 (config_overrides ())
 (expected
  ((total_return_pct   ((min -5.0)  (max 40.0)))
   (total_trades       ((min 12)    (max 30)))
   (win_rate           ((min 25.0)  (max 40.0)))
   (sharpe_ratio       ((min -0.3)  (max 0.80)))
   (max_drawdown_pct   ((min 25.0)  (max 45.0)))
   (avg_holding_days   ((min 55.0)  (max 120.0)))
   (unrealized_pnl     ((min 1000.0) (max 2500000.0))))))
