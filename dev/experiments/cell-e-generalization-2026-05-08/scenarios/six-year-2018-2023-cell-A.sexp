;; perf-tier: 2
;; perf-tier-rationale: 302-symbol small universe over 6 years; nightly cadence (≤30 min budget). See dev/plans/perf-scenario-catalog-2026-04-25.md tier 2.
;;
;; Golden scenario: 6-year run covering COVID crash and recovery.
;;
;; Baseline re-pinned on 2026-04-18 post-PR #409 (`_held_symbols` now
;; excludes Closed positions → symbols re-enter after stop-out). 302-symbol
;; small universe (`universes/small.sexp`). Representative values:
;;   final_portfolio_value ~1.84M        total_return_pct ~84
;;   total_trades 19 (= n_round_trips)   win_rate ~33
;;   sharpe_ratio ~0.66                  max_drawdown_pct ~24
;;   avg_holding_days ~74                open_positions_value ~1.81M
;;
;; Pre-#409 the count was 7 round-trips with total_return ~145 (most of
;; the gain parked in stuck-open positions from 2018). Post-#409 the
;; strategy cycles symbols, realizing profits and losses more frequently;
;; total_return drops as realized losses accumulate — this is the true
;; signal the strategy produces.
;;
;; IMPORTANT: `total_trades` = `List.length round_trips` (completed
;; buy→sell cycles), NOT `wincount + losscount`.
;;
;; Previous baseline (1,654 stocks, 2026-04-13) preserved in git history.
;;
;; [open_positions_value] range is wide: goal is to catch regression to
;; exactly 0 (PR #393's fix) while tolerating drift as the small universe is
;; re-curated. (Pre-rename this pin was named [unrealized_pnl] but matched the
;; mtm-value semantics now exposed under [Metric_types.OpenPositionsValue].)
((name "six-year-2018-2023")
 (description "6-year run covering COVID crash and recovery")
 (period ((start_date 2018-01-02) (end_date 2023-12-29)))
 (universe_size 302)
 (config_overrides ())
 (expected
  ((total_return_pct   ((min 50.0)  (max 180.0)))
   (total_trades       ((min 12)    (max 30)))
   (win_rate           ((min 28.0)  (max 42.0)))
   (sharpe_ratio       ((min 0.30)  (max 1.30)))
   (max_drawdown_pct   ((min 18.0)  (max 35.0)))
   (avg_holding_days   ((min 55.0)  (max 100.0)))
   (open_positions_value ((min 1000.0) (max 4000000.0))))))
