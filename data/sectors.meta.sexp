;; Metadata for data/sectors.csv — the committed sector-map snapshot.
;;
;; The CSV lists (symbol, GICS sector) pairs for the equity universe the
;; strategy screens. Kept in version control so broad-universe goldens
;; and scenario-runner checks are reproducible on any checkout, and so
;; that refreshes are intentional operations (a data-refresh PR) rather
;; than silent drift across machines.
;;
;; Refresh protocol: ops-data agent runs Finviz fetch + universe_filter,
;; commits the resulting CSV + bumps this file. Cadence: quarterly at
;; minimum, or whenever the universe composition meaningfully changes
;; (major IPOs, sector reclassifications).

((source           finviz-screener)
 (fetched_date     2026-04-14)
 (symbol_count     10472)
 (filter_version   "universe_filter v1 (#368)")
 (columns          (symbol sector))
 (consumers
  ((data/universe.sexp   "bootstrap_universe.exe regenerates from this")
   (universes/broad.sexp "scenario runner; Full_sector_map sentinel resolves here")
   (pick_small_universe  "pick.ml stratified sample produces universes/small.sexp"))))
