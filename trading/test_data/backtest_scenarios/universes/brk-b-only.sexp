;; Single-symbol universe pinning BRK-B (Berkshire Hathaway Class B).
;;
;; Used by the Buy-and-Hold-BRK-B benchmark scenarios under
;; [goldens-sp500/] — BRK-B serves as the "smart money" / active-value
;; baseline alongside [universes/spy-only.sexp] (passive market). Every
;; Weinstein backtest can be paired with a BAH-SPY and BAH-BRK-B run on
;; the same window to position the active strategy against both
;; references.
;;
;; The BAH strategy reads one symbol's bars and never screens, so the
;; screening "universe" reduces to that one symbol. The runner's
;; [_load_deps] loads the symbol's CSV via [Csv_snapshot_builder.build]
;; and passes the result through to the snapshot-backed market data
;; adapter; sector-ETF + global-index symbols the runner pulls in
;; alongside the universe are tolerated NaN when their CSVs are missing
;; (mirroring [data/sectors.csv] degraded mode).
;;
;; The sector below is informational only: BAH ignores sector data. We use
;; [Financial Services] because that's BRK's GICS-broad classification
;; in EODHD's metadata; any string would parse equivalently.
;;
;; Symbol convention: bare [BRK-B] (with a dash, NOT a dot) matches the
;; on-disk layout under [data/B/B/BRK-B/]. EODHD's convention encodes
;; share class with a hyphen; the period suffix (e.g. [BRK-B.US]) belongs
;; only to the API-call resolver. The runner reads the canonical ticker.
(Pinned (
  ((symbol BRK-B) (sector "Financial Services"))
))
