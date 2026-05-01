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
;;   unrealized_pnl 1,481,963  force_liquidations 6 (all Per_position, G14)
;;
;; The 31.8% MaxDD vs the pin's 3..9% target reflects the strategy's
;; drawdown profile WITHOUT the (spurious) Portfolio_floor brake. Whether
;; that gap is closed by fixing G14 alone, or whether it requires a real
;; risk control (G15-style for longs), is part of what these pins surface.
((name "sp500-2019-2023-long-only")
 (description "S&P 500 over 2019-2023 — long-only counterpart to sp500-2019-2023")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 491)
 (config_overrides (((enable_short_side false))))
 (expected
  ((total_return_pct   ((min -15.0)       (max  15.0)))
   (total_trades       ((min 27)          (max  37)))
   (win_rate           ((min 31.0)        (max  44.0)))
   (sharpe_ratio       ((min -0.5)        (max  0.5)))
   (max_drawdown_pct   ((min 3.0)         (max  9.0)))
   (avg_holding_days   ((min 37.0)        (max  50.0)))
   (unrealized_pnl     ((min 330000.0)    (max  450000.0))))))
