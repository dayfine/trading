;; perf-tier: research
;; perf-tier-rationale: Companion BAH-SPY alpha/risk bar for
;; [spy-only-stage2.sexp]. Same 2009-06-01 .. 2025-12-31 window, same
;; universe (universes/spy-only.sexp), same runner — only the strategy differs
;; ([Bah_benchmark] vs [Spy_only_weinstein]). Used to read the stage-timing
;; vs buy-and-hold gap on risk-adjusted terms (Sharpe / Calmar / MaxDD).
;;
;; Day-1 buy SPY with all cash (minus 1% gap buffer), hold to end. Single
;; trade; final equity tracks SPY's raw close price-only return.
((name "spy-only-stage2-bah")
 (description "Buy-and-Hold SPY 2009-06-01 to 2025-12-31 — alpha/risk bar for the SPY-only Weinstein stage-timing reference.")
 (period ((start_date 2009-06-01) (end_date 2025-12-31)))
 (universe_path "universes/spy-only.sexp")
 (universe_size 1)
 (config_overrides ())
 (strategy (Bah_benchmark (symbol SPY)))
 (expected
  ((total_return_pct       ((min -90.0)    (max 5000.0)))
   (total_trades           ((min   0.0)    (max    0.5)))
   (win_rate               ((min   0.0)    (max  100.0)))
   (sharpe_ratio           ((min  -2.0)    (max    5.0)))
   (max_drawdown_pct       ((min   0.0)    (max   95.0)))
   (avg_holding_days       ((min   0.0)    (max 5000.0)))
   (wall_seconds           ((min   0.5)    (max 3600.0))))))
