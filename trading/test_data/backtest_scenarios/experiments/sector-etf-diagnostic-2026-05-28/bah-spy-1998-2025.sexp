;; perf-tier: research
;; perf-tier-rationale: Buy-and-Hold SPY benchmark for the sector-ETF
;; diagnostic over the same window as `spdr-sector-etfs-1998-2025.sexp`.
;; Single-symbol, single-trade — runs fast. One-off; not in the
;; postsubmit rotation.
;;
;; **Purpose**: provides the comparison baseline for the sector-ETF
;; diagnostic. The diagnostic's verdict is:
;;
;;   verdict = sign_with_threshold(
;;     spdr_sector_etfs.cagr - bah_spy.cagr,
;;     beat_threshold_pp = 1.0,
;;     tie_threshold_pp = 1.0
;;   )
;;
;; **Window**: 1998-12-22 -> 2026-04-14. Same as the SPDR scenario for
;; an apples-to-apples comparison (SPY itself goes back to 1993, but we
;; cannot start before the SPDRs exist or the comparison is unfair).
;;
;; **Strategy**: `Bah_benchmark` (PR #874, #882) — day-1 entry at
;; `floor(initial_cash / SPY_close * 0.99)` shares, gap-buffered (1%
;; headroom for next-day-open fills). Holds until end_date - 1 trading
;; day. Per-share commission $0.01 (Backtest.Runner default).
;;
;; **Initial cash**: $1,000,000 (Backtest.Runner default; matches the
;; SPDR diagnostic scenario for a clean comparison).
;;
;; **Expected**: open_positions_value tightly pinned would require
;; running the scenario first. Per the BAH-SPY methodology in
;; `goldens-sp500/sp500-2019-2023-bah-spy.sexp`, the deterministic
;; behaviour means we can pin tight bands after the first run. Until
;; then, ranges are wide research bands.
;;
;; **Universe**: `universes/spy-only.sexp` — single-symbol SPY universe.
;; The runner's tolerance for missing sector-ETF / index CSVs (NaN
;; carry-through) means SPY is the only symbol that needs valid bars.
((name "bah-spy-1998-2025")
 (description
   "Buy-and-Hold SPY benchmark over the sector-ETF diagnostic window (1998-12-22 to 2026-04-14). Comparison baseline for `spdr-sector-etfs-1998-2025.sexp`.")
 (period ((start_date 1998-12-22) (end_date 2026-04-14)))
 (universe_path "universes/spy-only.sexp")
 (universe_size 1)
 (config_overrides ())
 (strategy (Bah_benchmark (symbol SPY)))
 (expected
  ((total_return_pct       ((min -50.0)        (max  3000.0)))
   (total_trades           ((min   0.0)        (max     0.5)))
   (win_rate               ((min   0.0)        (max   100.0)))
   (sharpe_ratio           ((min  -2.0)        (max     5.0)))
   (max_drawdown_pct       ((min   0.0)        (max    95.0)))
   (avg_holding_days       ((min   0.0)        (max     1.0))))))
