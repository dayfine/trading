((date 2026-05-29)
 (slug laggard-disable-retracted)
 (hypothesis
  "disabling laggard rotation (enable_laggard_rotation=false) as the Cell-E default improves risk-adjusted return")
 (base_scenario "goldens-sp500-historical/sp500-2010-2026.sexp")
 (window_id panel-15y-2010-2026)
 (baseline_label laggard-on)
 (variants
  (((label laggard-off)
    ;; Hash is NOMINAL: (enable_laggard_rotation false) applied to the
    ;; canonical default is a no-op (default already false), so it collides
    ;; with the empty-override baseline hash. The experiment was relative to
    ;; Cell-E (which enables laggard rotation), not the bare default; the
    ;; verdict + notes are the load-bearing record, not the dedup hash.
    (config_hash 236ef895264d979eefd83a50eb55663c)
    (aggregate ()))))
 (verdict Reject)
 (notes
  "See dev/notes/p1-laggard-disable-retracted-2026-05-29.md. Laggard rotation HELPS on 500-symbol panels (5y: -0.08 Sharpe, -9pp return when disabled) and only hurt on a 12-symbol diagnostic universe. Not shipping the default flip."))
