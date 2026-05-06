;; Single-symbol universe pinning SPY (the SPDR S&P 500 ETF).
;;
;; Used by the Buy-and-Hold-SPY benchmark scenario
;; (goldens-sp500/sp500-2019-2023-bah-spy.sexp) — the BAH strategy reads
;; one symbol's bars and never screens, so the screening "universe" reduces
;; to that one symbol. The runner's [_load_deps] loads the symbol's CSV via
;; [Csv_snapshot_builder.build] and passes the result through to the
;; snapshot-backed market data adapter; sector-ETF + global-index symbols
;; the runner pulls in alongside the universe are tolerated NaN when their
;; CSVs are missing (mirroring [data/sectors.csv] degraded mode).
;;
;; The sector below is informational only: BAH ignores sector data. We use
;; [Communication Services] because that's SPY's GICS-broad classification
;; in EODHD's metadata; any string would parse equivalently.
(Pinned (
  ((symbol SPY) (sector "Communication Services"))
))
