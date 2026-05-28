;; BAH-SPY benchmark for the diagnostic window 1998-12-22 → 2025-12-31.
;;
;; Shared baseline for both diagnostic 1b (SPY-only Weinstein) and 2b
;; (sector-ETF Weinstein). Computed via the existing
;; [Trading_strategy.Bah_benchmark_strategy] (PR #874): day-1 buy of
;; floor(initial_cash/SPY_close), hold to last bar, mark-to-market.
;;
;; Same shape as goldens-sp500/sp500-2019-2023-bah-spy.sexp but extended
;; to the 27-year window. Initial cash is the simulator default
;; ($1,000,000); the CAGR / Sharpe / MaxDD metrics are scale-invariant.
((name "bah-spy-1998-2025")
 (description "BAH SPY 1998-12-22 → 2025-12-31 — benchmark for diagnostics 1b/2b")
 (period ((start_date 1998-12-22) (end_date 2025-12-31)))
 (universe_path "universes/spy-only.sexp")
 (universe_size 1)
 (config_overrides ())
 (strategy (Bah_benchmark (symbol SPY)))
 (expected
  ((total_return_pct       ((min   100.0)     (max  2000.0)))
   (total_trades           ((min     0.0)     (max     0.5)))
   (win_rate               ((min     0.0)     (max   100.0)))
   (sharpe_ratio           ((min    -1.0)     (max     2.0)))
   (max_drawdown_pct       ((min    20.0)     (max    80.0)))
   (avg_holding_days       ((min     0.0)     (max     1.0))))))
