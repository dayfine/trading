;; Pinned 7-symbol universe for the tiered-loader parity test (smoke/tiered-loader-parity.sexp).
;;
;; Every symbol listed here has committed OHLCV data at
;; [test_data/<first>/<last>/<symbol>/data.csv]. Using a subset of the full
;; small universe (302 symbols from universes/small.sexp) means the Tiered
;; path's bulk Metadata promote does not hit missing-CSV errors — the goal of
;; the parity test is to compare strategy output on a working dataset, not to
;; stress the loader's missing-data handling (that's covered by unit tests in
;; trading/backtest/bar_loader/test/).
;;
;; Stratification: 7 symbols across 6 GICS sectors. This is the full
;; intersection of [universes/small.sexp] with the committed test_data/
;; price CSVs, so expanding to ~30 would require fetching additional symbol
;; data — out of scope for 3g.
(Pinned (
  ((symbol AAPL)   (sector "Information Technology"))
  ((symbol MSFT)   (sector "Information Technology"))
  ((symbol JPM)    (sector Financials))
  ((symbol JNJ)    (sector "Health Care"))
  ((symbol CVX)    (sector Energy))
  ((symbol KO)     (sector "Consumer Staples"))
  ((symbol HD)     (sector "Consumer Discretionary"))
))
