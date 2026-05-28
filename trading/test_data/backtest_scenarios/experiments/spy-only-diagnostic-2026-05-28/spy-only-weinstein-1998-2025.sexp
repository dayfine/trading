;; perf-tier: research
;; perf-tier-rationale: One-time diagnostic — Weinstein-on-SPY-only over the
;; 1998-2025 window. Pairs with [bah-spy-1998-2025.sexp] in this same
;; directory. Not in CI rotation; consumer is the writeup at
;; [dev/notes/spy-only-diagnostic-2026-05-28.md].
;;
;; {1 Diagnostic purpose}
;;
;; This scenario is part of a 3-way decomposition of where Weinstein's alpha
;; (or lack thereof) comes from:
;;
;;   1. SPY-only Weinstein vs BAH-SPY = isolated market-timing alpha (this).
;;   2. SPDR sector ETFs Weinstein vs BAH-SPY = market-timing + sector
;;      rotation (sibling scenario, experiment/sector-etf-diagnostic).
;;   3. Stocks Weinstein vs BAH-SPY = market-timing + sector + stock picking
;;      (the established BO sweep result on top-3000).
;;
;; Differences:
;;   (2) - (1) = pure sector-rotation alpha
;;   (3) - (2) = pure stock-picking alpha
;;
;; If SPY-only loses to BAH-SPY, market-timing at the index level is
;; value-neutral or harmful and any Weinstein alpha must come from the
;; cross-section (sector / stock picking).
;;
;; {1 Universe handling on a 1-symbol universe}
;;
;; Universe = {SPY}; Weinstein's screener cascade still runs but with
;; degenerate semantics on a 1-symbol set:
;;
;;   - Macro analysis ([Weinstein_strategy.indices.primary]) reads
;;     [GSPC.INDX] (NOT SPY) per [trading/trading/backtest/lib/runner.ml]'s
;;     hardcoded [index_symbol = "GSPC.INDX"]. So macro state is well-defined
;;     and unaffected by the universe shrink — bullish / neutral / bearish
;;     macro gating fires normally.
;;
;;   - Sector analysis reads the SPDR sector ETFs (XLK / XLF / etc.) per
;;     [Weinstein_strategy.Macro_inputs.spdr_sector_etfs]. SPY's GICS sector
;;     in [universes/spy-only.sexp] is "Communication Services" (informational
;;     only — BAH ignores it, but Weinstein's sector RS step may use it to
;;     map SPY into a sector cohort. With a 1-symbol universe, the cohort
;;     contains only SPY, so sector RS is degenerate but not harmful.
;;
;;   - Relative strength: SPY's RS is computed vs the macro benchmark
;;     [GSPC.INDX], not vs SPY itself. SPY ≈ GSPC.INDX up to TER + tracking
;;     error, so RS will hover near zero (small, time-varying noise from the
;;     ETF tracking error + dividend pass-through timing). This means
;;     entry/exit signal comes almost entirely from SPY's own price/MA
;;     trend, not from cross-section ranking.
;;
;; This is the "isolated market-timing alpha" measurement we want — what
;; happens if you ONLY use Weinstein's stage classifier + stop machine on the
;; market itself?
;;
;; {1 Cell-E config}
;;
;; Identical config_overrides to [sp500-2010-2026.sexp] and
;; [sp500-1998-2026.sexp] — the canonical Cell-E config:
;;   - max_position_pct_long  = 0.14
;;   - max_long_exposure_pct  = 0.70
;;   - min_cash_pct           = 0.30
;;   - enable_stage3_force_exit = true (h=1)
;;   - enable_laggard_rotation  = true (h=2)
;;
;; On a 1-symbol universe, the position-sizing caps are effectively
;; meaningless (you can only ever hold SPY or be in cash). max_position_pct
;; = 0.14 means each entry buys ~14% of NAV worth of SPY — so the strategy
;; is mostly-cash even when holding. This is intentional: the question is
;; "does Weinstein TIMING beat BAH" not "does Weinstein on equal sizing
;; beat BAH" — the cap reflects the same risk discipline used in the full
;; surface.
;;
;; {1 Initial cash}
;;
;; Runner hardcodes [initial_cash = 1_000_000.0] in
;; [trading/trading/backtest/lib/runner.ml] line 13. The diagnostic prompt
;; asks for $100k initial cash; we use the runner's canonical $1M instead.
;; All compared metrics (return %, Sharpe, MaxDD, time-in-market %, CAGR)
;; are scale-invariant, so the diagnostic verdict is unaffected.
;;
;; {1 End date}
;;
;; 2025-12-31 caps the window before the small 2026-01..2026-05 tail.
;; [GSPC.INDX] data extends to 2026-04-10; SPY to 2026-05-01.
;;
;; {1 Expected bands}
;;
;; Intentionally WIDE — research scenario, no prior measurement to pin
;; against. Catch-only sentinels for NaN / crash regressions.
((name "spy-only-weinstein-1998-2025")
 (description
  "SPY-only Weinstein (1-symbol universe) 1998-01-01 to 2025-12-31 — isolated market-timing diagnostic. Cell-E config. Pairs with bah-spy-1998-2025.sexp in same dir.")
 (period ((start_date 1998-01-01) (end_date 2025-12-31)))
 (universe_path "universes/spy-only.sexp")
 (universe_size 1)
 ;; Cell-E config — identical to sp500-2010-2026.sexp.
 (config_overrides
  (((enable_short_side false))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 ;; Research bands — wide, catch only NaN / crash sentinels. The diagnostic
 ;; report (dev/notes/spy-only-diagnostic-2026-05-28.md) carries the
 ;; analysis; this scenario's PASS/FAIL gate isn't load-bearing.
 (expected
  ((total_return_pct  ((min -90.0)   (max 5000.0)))
   (total_trades      ((min   0.0)   (max  10000.0)))
   (win_rate          ((min   0.0)   (max   100.0)))
   (sharpe_ratio      ((min  -2.0)   (max     5.0)))
   (max_drawdown_pct  ((min   0.0)   (max    95.0)))
   (avg_holding_days  ((min   0.0)   (max   365.0)))
   (wall_seconds      ((min   1.0)   (max  3600.0))))))
