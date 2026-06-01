;; 11 SPDR sector ETFs + SPY (the RS-ranking benchmark).
;;
;; Identical to [spdr-sectors-11.sexp] plus an SPY row. The sector-rotation
;; Weinstein strategy
;; ([trading/trading/weinstein/strategy/lib/sector_rotation_weinstein_strategy.mli])
;; ranks the 11 sector ETFs by relative strength vs SPY and holds the top-K
;; Stage-2 names. SPY is in the universe so the runner loads its bars (the RS
;; computation needs them), but SPY is the [benchmark_symbol] — it is NEVER
;; traded, only used for ranking.
;;
;; The 9 December-1998 ETFs (XLK / XLF / XLI / XLV / XLE / XLP / XLY / XLU /
;; XLB) span the full 1998-2025 window; [Daily_price.active_through] (PR #1023)
;; handles the staggered inception of XLRE (2015-10-08) and XLC (2018-06-19) by
;; skipping classification on dates before each symbol's first bar. SPY spans
;; the full window.
;;
;; Total: 12 symbols (11 tradable sectors + 1 benchmark).
(Pinned (
  ((symbol XLK)  (sector "Information Technology"))
  ((symbol XLF)  (sector "Financials"))
  ((symbol XLI)  (sector "Industrials"))
  ((symbol XLV)  (sector "Health Care"))
  ((symbol XLE)  (sector "Energy"))
  ((symbol XLP)  (sector "Consumer Staples"))
  ((symbol XLY)  (sector "Consumer Discretionary"))
  ((symbol XLU)  (sector "Utilities"))
  ((symbol XLB)  (sector "Materials"))
  ((symbol XLRE) (sector "Real Estate"))
  ((symbol XLC)  (sector "Communication Services"))
  ((symbol SPY)  (sector "Benchmark"))
))
