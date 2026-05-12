;; perf-tier: 3
;; perf-tier-rationale: ~500-symbol S&P 500 universe over 5 years, long-only
;; variant of [sp500-2019-2023]. Same period (2019-2023) and universe; only
;; difference is [enable_short_side = false]. Weekly cadence, ≤2 h budget.
;;
;; Long-only counterpart to [sp500-2019-2023.sexp]. Tracking both lets us
;; isolate whether strategy issues are short-side-specific or general:
;;
;;   * If long-only PASSes pins but the with-shorts variant FAILs → issue is
;;     in short-side machinery (e.g., G15 short-side risk control).
;;   * If both FAIL similarly → issue is in shared strategy components
;;     (e.g., G14 screener resistance calc / Position.t entry_price).
;;
;; Pinned ranges intentionally TIGHT — they target the "fully fixed" state,
;; not current behavior. Both variants currently FAIL these pins. The
;; long-only FAIL surfaces G14 explicitly (~6 spurious Per_position
;; force-liqs from the screener / Position.t price-space mismatch — see
;; dev/notes/g14-deep-dive-2026-05-01.md).
;;
;; Pinned values mirror [sp500-2019-2023.sexp] expected ranges: same 5-year
;; period, same universe, and the long-only side is a strict subset of the
;; with-shorts strategy. The "ideal" long-only profile should be ≈ the
;; with-shorts baseline modulo the short-side contribution, which has
;; historically been small (PR #711 measured 4 short trades / 32 total).
;; If long-only diverges meaningfully from this target post-fix, re-pin
;; once empirical data justifies it.
;;
;; Current measured baseline 2026-05-01 (post-G12+G13, pre-G14/G15):
;;   total_return_pct  65.03   total_trades 136   win_rate 37.50
;;   sharpe_ratio       0.62   max_drawdown 31.78  avg_holding_days 69.51
;;   open_positions_value 1,481,963  force_liquidations 6 (all Per_position, G14)
;;
;; (Pre-rename the [unrealized_pnl] field above carried mtm-value semantics —
;; the same quantity now exposed as [Metric_types.OpenPositionsValue]. The
;; corrected [UnrealizedPnl] metric (open positions value minus cost basis)
;; was first emitted in PR feat/metrics-unrealized-pnl-rename; on the
;; long-only baseline measured 2026-04-30 it was +$421,922.)
;;
;; The 31.8% MaxDD vs the pin's 3..9% target reflects the strategy's
;; drawdown profile WITHOUT the (spurious) Portfolio_floor brake. Whether
;; that gap is closed by fixing G14 alone, or whether it requires a real
;; risk control (G15-style for longs), is part of what these pins surface.
((name "sp500-2019-2023-long-only")
 (description "S&P 500 over 2019-2023 — long-only — Cell E config")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 503)
 ;; Cell E rollout 2026-05-11: applies the new standard strategy config
 ;; (max_position_pct_long=0.14, max_long_exposure_pct=0.70, min_cash_pct=0.30,
 ;; stage3 force-exit h=1, laggard rotation h=2). Replaces prior 0.30/0.90/0.10
 ;; default-sized baseline (79.74% / 74 trades / 30.8% DD).
 ;; Measured 2026-05-12 (Cell E, post-#1052 force-liq fix + #1053 metric schema):
 ;;   total_return_pct   66.54  total_trades 248   win_rate 39.11
 ;;   sharpe_ratio       0.68   max_drawdown 24.09 avg_holding_days  41.95
 ;;   open_positions_value 1,401,130
 ;;   sortino_ratio_annualized 0.95   calmar_ratio 0.45   ulcer_index 8.61
 ;; MaxDD cut 6.7pp (31 → 24), trade count 3.4x. Tolerances ±15%.
 (config_overrides
  (((enable_short_side false))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (expected
  ((total_return_pct   ((min  56.5)        (max  76.5)))
   (total_trades       ((min 210)          (max 285)))
   (win_rate           ((min  33.2)        (max  45.0)))
   (sharpe_ratio       ((min   0.58)       (max   0.78)))
   (max_drawdown_pct   ((min  20.5)        (max  27.7)))
   (avg_holding_days   ((min  36.0)        (max  48.0)))
   (open_positions_value ((min 1190000.0)  (max 1611000.0)))
   (sortino_ratio_annualized ((min 0.81)   (max 1.09)))
   (calmar_ratio       ((min   0.38)       (max   0.51)))
   (ulcer_index        ((min   7.32)       (max   9.90))))))
