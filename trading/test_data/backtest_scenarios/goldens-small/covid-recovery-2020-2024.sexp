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
;;   avg_holding_days ~70                open_positions_value ~0.86M
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
;; [open_positions_value] range is wide: goal is to catch regression to
;; exactly 0 (PR #393's fix). (Pre-rename this pin was named
;; [unrealized_pnl] but matched mtm-value semantics; see metric_types.mli
;; for the corrected meaning.)
;;
;; Cell E rollout 2026-05-11: applies the new standard strategy config
;; (max_position_pct_long=0.14, max_long_exposure_pct=0.70, min_cash_pct=0.30,
;; stage3 force-exit h=1, laggard rotation h=2). Replaces prior default-sized
;; baseline (8% return / 21 trades / 36% DD on 0.30/0.90/0.10 sizing).
;; Measured 2026-05-11 (Cell E):
;;   total_return_pct   80.8   total_trades 280   win_rate 38.2
;;   sharpe_ratio       0.80   max_drawdown 24.3  avg_holding_days  38
;;   open_positions_value 1,634,151
;; Return 10x (8 → 81), MaxDD cut 12pp (36 → 24). Tolerances ±15%.
;;
;; Re-pinned 2026-07-08 for the warmup 210→364 fix (RS warmup gap,
;; dev/notes/rs-warmup-gap-2026-07-07.md): the panel now carries 52 weeks of
;; pre-window history, so rs_value is present from the first screen instead
;; of None for every symbol in the first 22 weeks. Day-1 candidate ranking
;; changes, path drifts after. Measured 2026-07-08 against test_data:
;;   total_return_pct  106.39  total_trades 273   win_rate 38.83
;;   sharpe_ratio        1.02  max_drawdown 17.67 avg_holding_days 40.54
;;   open_positions_value 1,540,015
;; (Pre-change 210-warmup baseline re-measured same day: 78.5% / 283 trades /
;; DD 23.8 — in-band on all pins except open_positions_value 1,342,622,
;; which had already drifted below the 2026-05-11 band.) Tolerances ±15%.
((name "covid-recovery-2020-2024")
 (description "COVID crash and recovery through 2024 — Cell E config")
 (period ((start_date 2020-01-02) (end_date 2024-12-31)))
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
  ((total_return_pct   ((min  90.4)        (max 122.3)))
   (total_trades       ((min 232)          (max 314)))
   (win_rate           ((min  33.0)        (max  44.7)))
   (sharpe_ratio       ((min   0.86)       (max   1.17)))
   (max_drawdown_pct   ((min  15.0)        (max  20.3)))
   (avg_holding_days   ((min  34.5)        (max  46.6)))
   (open_positions_value ((min 1309000.0)  (max 1771000.0))))))
