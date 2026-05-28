;; SPDR sector ETF universe — 11 funds, one per GICS sector.
;;
;; Used by the sector-rotation diagnostic
;; (`spdr-sector-etfs-1998-2025.sexp`) in this experiment directory and by
;; the companion BAH-SPY benchmark (`bah-spy-1998-2025.sexp`).
;;
;; **Inception dates** (verified against
;; `data/<L>/<last-letter>/<sym>/data.csv` first-bar dates):
;;
;;   XLB,XLE,XLF,XLI,XLK,XLP,XLU,XLV,XLY  - 1998-12-22  (Select Sector launch)
;;   XLRE                                  - 2015-10-08  (Real Estate split-out)
;;   XLC                                   - 2018-06-19  (Comm Services split-out)
;;
;; For dates before each ETF's inception, the runner's
;; `Csv_snapshot_builder._read_one_symbol` tolerates the empty bar list and
;; the panel reader carries NaN through the per-symbol slot. The Weinstein
;; screener cannot trade a symbol on a NaN bar, so XLRE/XLC effectively
;; enter the tradable universe at their respective inception dates without
;; requiring per-fold pruning. The opt-in `?active_through_for` filter (PR
;; #1318) is NOT used here — the brute-force NaN-tolerance path is
;; sufficient at this 12-symbol scale.
;;
;; Sectors below match `data/sectors.csv` exactly (GICS taxonomy as of
;; 2025; XLC was reclassified from "Telecommunication Services" in 2018).
(Pinned (
  ((symbol XLB)  (sector Materials))
  ((symbol XLC)  (sector "Communication Services"))
  ((symbol XLE)  (sector Energy))
  ((symbol XLF)  (sector Financials))
  ((symbol XLI)  (sector Industrials))
  ((symbol XLK)  (sector "Information Technology"))
  ((symbol XLP)  (sector "Consumer Staples"))
  ((symbol XLRE) (sector "Real Estate"))
  ((symbol XLU)  (sector Utilities))
  ((symbol XLV)  (sector "Health Care"))
  ((symbol XLY)  (sector "Consumer Discretionary"))
))
