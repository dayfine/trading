;; perf-tier: 4
;; perf-tier-rationale: N=1000 × this window. Per dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md (RSS ≈ 67 + 3.94·N + 0.19·N·(T−1) MB), this projects to ~5.0 GB peak RSS — fits the local 7.75 GB Docker ceiling. Run on-demand via `dev/scripts/perf_tier4_release_gate.sh`.
;;
;; PIT-clean universe migration 2026-06-05 (dev/plans/goldens-broad-pit-migration-2026-06-05.md).
;; Replaced the non-reproducible `universes/broad.sexp` sentinel (Full_sector_map +
;; universe_cap=1000 = "first-1000 of the live, growing data/sectors.csv") with the frozen
;; point-in-time composition snapshot `top-1000-2018` (the 1000 largest by historical
;; cap-weight as of the window start, survivorship-clean — it includes names that failed
;; afterward). The universe is now reproducible: it no longer shifts when sectors.csv changes.
;; Numbers differ from the prior top-N pins because that universe was a drifting artifact, not
;; because of a regression — see the migration plan for the diagnosis.
;;
;; enable_short_side stays false (short-side gaps G1-G4, dev/notes/short-side-gaps-2026-04-29.md).
;; Cell E config (max_position_pct_long=0.30, max_long_exposure_pct=0.70, min_cash_pct=0.30,
;; stage3 force-exit h=1, laggard rotation h=2).
;;
;; Measured 2026-06-05 (Cell E, PIT top-1000-2018). Tolerances ±20%
;; (return/DD/sharpe/trades/holding), win_rate ±5pp — first PIT pin.
;;
;; RE-PINNED 2026-06-24 (#1729 decision C): complete-universe warehouse run
;; (top-1000-2018, 1000/1000 symbols loaded; 1015 incl. ^GSPC + sector ETFs).
;; The prior band (70.9-106.3%) was measured against an incomplete
;; (survivor-subset, ~462/1000) test_data store — the runner silently skipped
;; the missing symbols, badly inflating return. Re-measured against the
;; delisting-complete warehouse snapshot /tmp/snap_top3000_1998_2026 (3015 syms);
;; the complete top-1000-2018 universe (with COVID-era delistings) collapses the
;; return from the survivor-inflated 70-106% to ~19%, and the MaxDD falls too
;; (less concentrated). Determinism established on the sibling decade cell
;; (bit-identical across two runs). This cell will (correctly) keep FAILING in
;; GHA perf-tier4 against the incomplete committed test_data — that failure is
;; the intentional missing-data signal; a local snapshot run reproduces the band.
;;
;; Measured 2026-06-24 (complete-universe warehouse, top-1000-2018):
;;   total_return_pct 19.45   total_trades 280   win_rate 35.71
;;   sharpe_ratio 0.28   max_drawdown 21.79   avg_holding_days 39.68   calmar 0.14
;; Tolerances ±20% (return/DD/sharpe/trades/holding), win_rate ±5pp.
((name "six-year-2018-2023")
 (description "6-year run covering COVID crash and recovery (PIT top-1000-2018)")
 (period ((start_date 2018-01-02) (end_date 2023-12-29)))
 (universe_path "../goldens-custom-universe/composition/top-1000-2018.sexp")
 (universe_size 1000)
 (config_overrides
  (((enable_short_side false))
   ((portfolio_config ((max_position_pct_long 0.30))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (expected
  ;; Concentration=0.30 promotion 2026-06-25 (max_position_pct_long 0.14 -> 0.30, the
  ;; production default; ledger 2026-06-25-capacity-concentration-broad). Warehouse
  ;; re-measure. ⚠ 0.30 HURTS this 6y window: ret 19.45 -> 4.02, sharpe 0.28 -> 0.115
  ;; (concentration is regime-dependent — helps the long/aggregate windows, hurts
  ;; some short ones; the ACCEPT is a broad-aggregate verdict, not per-window).
  ;; Wide bands around the near-zero 0.30 actuals (ret 4.02 sharpe 0.115 maxDD 24.70).
  ((total_return_pct   ((min -8.0)  (max 16.0)))
   (total_trades       ((min 176)   (max 238)))
   (win_rate           ((min 33.2)  (max 43.2)))
   (sharpe_ratio       ((min -0.10) (max 0.33)))
   (max_drawdown_pct   ((min 19.8)  (max 29.6)))
   (avg_holding_days   ((min 35.8)  (max 53.7))))))
