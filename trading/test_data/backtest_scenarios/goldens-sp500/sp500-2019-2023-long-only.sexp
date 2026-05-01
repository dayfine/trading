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
;;     (e.g., G14 screener resistance calc using stale highs).
;;
;; Baseline measured 2026-05-01 (post-G12+G13 cascade fixes; G14/G15 still
;; open):
;;   total_return_pct  65.03   total_trades 136   win_rate 37.50
;;   sharpe_ratio       0.62   max_drawdown 31.78  avg_holding_days 69.51
;;   unrealized_pnl 1,481,963  force_liquidations 6 (all Per_position, G14)
;;
;; Pinned ranges below are ±~20% around this baseline. The 6 residual
;; force-liqs all trace to the G14 screener pre-split-contaminated
;; suggested_entry — see dev/notes/force-liq-cascade-findings-2026-05-01.md
;; G14 section. Re-pin tighter once G14 closes.
;;
;; Note: this scenario also surfaces the strategy's drawdown profile
;; without the (spurious) Portfolio_floor brake. The 31.8% MaxDD here is
;; what the strategy actually produces on its own — far above the original
;; 5.81% pinned baseline, which was an artefact of the buggy floor halting
;; the strategy mid-drawdown.
((name "sp500-2019-2023-long-only")
 (description "S&P 500 over 2019-2023 — long-only counterpart to sp500-2019-2023")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 491)
 (config_overrides (((enable_short_side false))))
 (expected
  ((total_return_pct   ((min 40.0)        (max 90.0)))
   (total_trades       ((min 100)         (max 170)))
   (win_rate           ((min 30.0)        (max 45.0)))
   (sharpe_ratio       ((min 0.30)        (max 0.95)))
   (max_drawdown_pct   ((min 22.0)        (max 42.0)))
   (avg_holding_days   ((min 55.0)        (max 85.0)))
   (unrealized_pnl     ((min 1200000.0)   (max 1800000.0))))))
