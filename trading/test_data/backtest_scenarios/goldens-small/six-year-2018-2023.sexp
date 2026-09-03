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
;;
;; Cell E rollout 2026-05-11: applies the new standard strategy config
;; (max_position_pct_long=0.14, max_long_exposure_pct=0.70, min_cash_pct=0.30,
;; stage3 force-exit h=1, laggard rotation h=2). Replaces prior default-sized
;; baseline (84% return / 19 trades / 24% DD on 0.30/0.90/0.10 sizing).
;; Measured 2026-05-11 (Cell E):
;;   total_return_pct   56.6   total_trades 320   win_rate 34.4
;;   sharpe_ratio       0.55   max_drawdown 25.8  avg_holding_days  39
;;   open_positions_value 1,241,577
;; Lower return than old (rotation realises losses) but 17x more trades.
;; Tolerances ±15%.
((name "six-year-2018-2023")
 (description "6-year run covering COVID crash and recovery — Cell E config")
 (period ((start_date 2018-01-02) (end_date 2023-12-29)))
 (universe_size 302)
 (config_overrides
  (((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 ;; Cost-model overlay (PR #1260 wiring). See bull-crash-2015-2020.sexp for
 ;; the full rationale. [retail_default] with per_trade=0 is byte-equal to
 ;; [None] under current wiring (only [apply_per_trade_commission] is hooked);
 ;; spread / per_share will activate once [Cost_model.to_engine_costs] is
 ;; wired into [Panel_runner] — Open work item in `dev/status/cost-model.md`.
 (cost_model
  ((per_trade_commission 0.0)
   (per_share_commission 0.0)
   (bid_ask_spread_bps 5.0)
   (market_impact_bps_per_pct_adv 0.0)))
 (expected
  ;; Re-pinned 2026-06-23 for the A-D-live default flip (synthetic breadth tail).
  ;; Re-centered 2026-07-08 for the warmup 210→364 fix (RS present from first
  ;; screen; dev/notes/warmup-364-repin-2026-07-08.md). Measured: 79.13% / 321
  ;; trades / win 38.01 / Sharpe 0.72 / DD 19.05 / hold 40.55 / OPV 1,465,187
  ;; (was in-band pre-re-pin — re-centered ±15% around the 364 actuals).
  ;; Verified INERT under the 2026-07-11 REALISM-DEFAULTS flip (user mandate;
  ;; min_entry_dollar_adv 0.0→1e6 + stale_exit_after_days None→Some 5; ledger
  ;; 2026-07-10-realism-defaults-flip): re-measured = BIT-IDENTICAL (79.13% / 321 /
  ;; 38.01 / 0.72 / 19.05 / 40.55 / OPV 1,465,187 / force_liqs 0). Liquid 302-symbol
  ;; universe → gate + stale-exit no-op. Bands unchanged.
  ;; RE-PINNED 2026-09-03 for the D1/D2 exit-basis default flip (PR #2648: sim_exit_fill_next_open + stop_skip_entry_bar on). ±15% around the NEW-arm actual at pinned build 398f57111 (total_return_pct: at least ±5pp); paired old arm (both knobs pinned false, run directly) + notes in dev/experiments/exit-basis-flip-2026-09-03/. NOTE: the prior pin was already stale — it predates the 2026-08-24 (#2530) and 2026-08-26 (#2569) default flips and the tier-2 nightly runs continue-on-error. Correctness re-pin: no return claim attaches to the delta.
  ((total_return_pct ((min -31.5947) (max -21.5947)))
   (total_trades ((min 216.7500) (max 293.2500)))
   (win_rate ((min 23.3333) (max 31.5686)))
   (sharpe_ratio ((min -0.2975) (max -0.2199)))
   (max_drawdown_pct ((min 30.3600) (max 41.0753)))
   (avg_holding_days ((min 45.2633) (max 61.2386)))
   (open_positions_value ((min 406734.4350) (max 550287.7650))))))
