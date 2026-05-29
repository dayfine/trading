((date 2026-05-14)
 (slug continuation-combined-axis)
 (hypothesis
  "continuation-buy combined axis (enable_continuation_buys=true, weeks=2 + range=0.15) adds risk-adjusted return over the continuation-off Cell-E baseline")
 (base_scenario "goldens-sp500-historical/sp500-2010-2026.sexp")
 (window_id panel-16y-2010-2026)
 (baseline_label cont-off)
 (variants
  (((label cont-combined)
    ;; Nominal hash: keyed on the master switch only. The full nested
    ;; combined-axis blob (continuation_config weeks=2 / range=0.15) field
    ;; names were not recovered from the 2026-05-14 sweep notes, so the hash
    ;; reflects (enable_continuation_buys true) on top of default. Dedup on
    ;; this entry is approximate; the verdict is the load-bearing record.
    (config_hash 82ecc7b99e23175cb8d9d759da56b42e)
    (aggregate ()))))
 (verdict Reject)
 (notes
  "See memory/project_continuation_combined_rejected.md. Wins big on 5y (Sharpe 0.59->0.73) but loses on 16y (0.71->0.68); continuation-off wins on Sharpe+CAGR+total. Single-window 5y overfit; net drag long-horizon."))
