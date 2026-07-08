;; perf-tier: 2
;; perf-tier-rationale: 302-symbol small universe over 6 years; nightly cadence (≤30 min budget). See dev/plans/perf-scenario-catalog-2026-04-25.md tier 2.
;;
;; Golden scenario: strong bull market through 2020 crash.
;;
;; Baseline re-pinned on 2026-04-18 post-PR #409 (`_held_symbols` now
;; excludes Closed positions → symbols re-enter after stop-out). 302-symbol
;; small universe (`universes/small.sexp`). Representative values:
;;   final_portfolio_value ~4.39M        total_return_pct ~339
;;   total_trades 15 (= n_round_trips)   win_rate ~37
;;   sharpe_ratio ~1.04                  max_drawdown_pct ~37
;;   avg_holding_days ~101               open_positions_value ~4.37M
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
;; [open_positions_value] range is wide: goal is to catch regression to
;; exactly 0 (PR #393's fix). (Pre-rename this pin was named
;; [unrealized_pnl] but matched mtm-value semantics; see metric_types.mli
;; for the corrected meaning.)
;;
;; Cell E rollout 2026-05-11: applies the new standard strategy config
;; (max_position_pct_long=0.14, max_long_exposure_pct=0.70, min_cash_pct=0.30,
;; stage3 force-exit h=1, laggard rotation h=2). Replaces prior default-sized
;; baseline (339% return / 15 trades / 37% DD on 0.30/0.90/0.10 sizing).
;; Measured 2026-05-11 (Cell E):
;;   total_return_pct  110.6   total_trades 283   win_rate 41.0
;;   sharpe_ratio       0.93   max_drawdown 18.5  avg_holding_days  46
;;   open_positions_value 2,085,155
;; MaxDD cut by half (37% → 18.5%) via Cell E rotation. Tolerances ±15%.
((name "bull-crash-2015-2020")
 (description "Strong bull market through the 2020 crash — Cell E config")
 (period ((start_date 2015-01-02) (end_date 2020-12-31)))
 (universe_size 302)
 (config_overrides
  (((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 ;; Cost-model overlay (PR #1260 wiring). [retail_default] declares the
 ;; expected cost regime: flat-fee retail broker (per_trade=$0, per_share=$0,
 ;; bid_ask=5 bps, no market impact). With the current wiring (only
 ;; [apply_per_trade_commission] hooked into the simulator),
 ;; [per_trade_commission=0.0] means this overlay is byte-equal to
 ;; [cost_model = None]; the pinned ranges below are unchanged. The
 ;; [bid_ask_spread_bps=5.0] and [per_share_commission] knobs will become
 ;; material once [Cost_model.to_engine_costs] is wired into [Panel_runner]
 ;; — Open work item in `dev/status/cost-model.md`. Pinning the overlay
 ;; declaratively now means future wiring lands without touching every
 ;; golden again.
 (cost_model
  ((per_trade_commission 0.0)
   (per_share_commission 0.0)
   (bid_ask_spread_bps 5.0)
   (market_impact_bps_per_pct_adv 0.0)))
 (expected
  ;; Re-pinned 2026-06-23 for the A-D-live default flip (synthetic breadth tail).
  ;; A-D-live's conservative gate cut bull-window return here (110→59) — expected:
  ;; the breadth edge is short-timing, which this long-only window can't exploit.
  ;; Re-centered 2026-07-08 for the warmup 210→364 fix (RS present from first
  ;; screen; dev/notes/warmup-364-repin-2026-07-08.md). Measured: 54.57% / 285
  ;; trades / win 39.65 / Sharpe 0.61 / DD 19.71 / hold 43.11 / OPV 1,382,427
  ;; (was in-band pre-re-pin — re-centered ±15% around the 364 actuals).
  ((total_return_pct   ((min  46.4)        (max  62.8)))
   (total_trades       ((min 242)          (max 328)))
   (win_rate           ((min  33.7)        (max  45.6)))
   (sharpe_ratio       ((min   0.52)       (max   0.70)))
   (max_drawdown_pct   ((min  16.8)        (max  22.7)))
   (avg_holding_days   ((min  36.6)        (max  49.6)))
   (open_positions_value ((min 1175000.0)  (max 1590000.0))))))
