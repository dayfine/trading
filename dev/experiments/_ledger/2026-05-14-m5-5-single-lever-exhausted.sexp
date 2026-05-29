((date 2026-05-14)
 (slug m5-5-single-lever-exhausted)
 (hypothesis
  "single-lever Cell-E tuning (stop floor, min-correction, score floor, Q5 soft-penalty) moves risk-adjusted metrics on long horizons")
 (base_scenario "goldens-sp500-historical/sp500-2010-2026.sexp")
 (window_id multi-horizon-5y-10y-16y)
 (baseline_label cell-e)
 (variants
  (((label single-lever-axes)
    ;; Nominal hash (empty-override placeholder). This entry records a
    ;; CONCLUSION across the four M5.5 axes, not one config: the deep nested
    ;; override paths (stops_config.min_correction_pct,
    ;; screening_config.candidate_params.installed_stop_min_pct, score floor,
    ;; Q5 penalty) were not reconstructed into a single canonical blob. The
    ;; verdict + notes are the load-bearing record; dedup hash is nominal.
    (config_hash 236ef895264d979eefd83a50eb55663c)
    (aggregate ()))))
 (verdict Reject)
 (notes
  "See memory/project_m5-5-tuning-exhausted.md. 3 of 4 axes rejected/neutral; axis-2 (min_correction_pct=0.10) catastrophic on 16y (MaxDD 19.9%->60.1%); single-lever Cell-E tuning exhausted, bottleneck is elsewhere."))
