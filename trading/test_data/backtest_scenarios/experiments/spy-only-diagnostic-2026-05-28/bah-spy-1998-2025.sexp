;; perf-tier: research
;; perf-tier-rationale: Companion BAH-SPY baseline for the
;; spy-only-weinstein-1998-2025 diagnostic. Same 1998-01-01 to 2025-12-31
;; window, same universe (universes/spy-only.sexp), same runner ($1M
;; initial cash) — only the strategy differs. Used by
;; [dev/notes/spy-only-diagnostic-2026-05-28.md] as the alpha bar.
;;
;; Day-1 buy SPY with all cash (minus 1% gap buffer), hold to end.
;; Single trade; no parameter sensitivity. Final equity tracks SPY's raw
;; close price-only return tightly (no dividend reinvestment — BAH uses raw
;; close throughout).
;;
;; Differs from goldens-sp500/sp500-2019-2023-bah-spy.sexp only in:
;;   - window (1998-2025 here, vs 2019-2023 there)
;;   - expected bands (intentionally wider since this is a research
;;     diagnostic, not a pinned regression cell)
;;
;; SPY data range: 1993-01-29 to 2026-05-01 — fully covers this window.
((name "bah-spy-1998-2025")
 (description "Buy-and-Hold SPY 1998-01-01 to 2025-12-31 — alpha bar for the SPY-only Weinstein diagnostic.")
 (period ((start_date 1998-01-01) (end_date 2025-12-31)))
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
   (avg_holding_days       ((min   0.0)    (max    1.0)))
   (wall_seconds           ((min   1.0)    (max  3600.0))))))
