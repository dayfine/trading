;; 11 SPDR sector ETFs (the full GICS sector taxonomy as of 2018).
;;
;; Used by the sector-ETF diagnostic
;; ([experiments/sector-etf-diagnostic-2026-05-28/]) — the runner loads
;; each symbol's CSV via [Csv_snapshot_builder.build] and the simulator
;; only "sees" each ETF on dates where bars exist. [Daily_price.active_through]
;; (PR #1023) handles the staggered inception of XLRE (2015-10-08) and
;; XLC (2018-06-19) by skipping screening on dates before the symbol's
;; first bar. The 9 December-1998 ETFs (XLK / XLF / XLI / XLV / XLE / XLP /
;; XLY / XLU / XLB) span the full 1998-2025 window.
;;
;; Sector strings match [data/sectors.csv] for the ETFs themselves; the
;; runner classifies each ETF under its own GICS sector for the
;; Weinstein screener's sector-rotation logic (the diagnostic that this
;; universe is built to test).
;;
;; Total: 11 symbols. For the sector-ETF diagnostic the recommended
;; portfolio config sizes positions at ~1/11 (max_position_pct_long=0.10)
;; with full investment allowed (max_long_exposure_pct=1.0, min_cash_pct=0.0)
;; so the Weinstein selection signal is tested without portfolio-config throttle.
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
))
