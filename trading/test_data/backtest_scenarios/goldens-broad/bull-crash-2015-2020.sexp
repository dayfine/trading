;; perf-tier: 4
;; perf-tier-rationale: N=1000 × this window. Per dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md (RSS ≈ 67 + 3.94·N + 0.19·N·(T−1) MB), this projects to ~4.8 GB peak RSS — fits the local 7.75 GB Docker ceiling. Run on-demand via `dev/scripts/perf_tier4_release_gate.sh`.
;;
;; PIT-clean universe migration 2026-06-05 (dev/plans/goldens-broad-pit-migration-2026-06-05.md).
;; Replaced the non-reproducible `universes/broad.sexp` sentinel (Full_sector_map +
;; universe_cap=1000 = "first-1000 of the live, growing data/sectors.csv") with the frozen
;; point-in-time composition snapshot `top-1000-2015` (the 1000 largest by historical
;; cap-weight as of the window start, survivorship-clean — it includes names that failed
;; afterward). The universe is now reproducible: it no longer shifts when sectors.csv changes.
;; Numbers differ from the prior top-N pins because that universe was a drifting artifact, not
;; because of a regression — see the migration plan for the diagnosis.
;;
;; enable_short_side stays false (short-side gaps G1-G4, dev/notes/short-side-gaps-2026-04-29.md).
;; Cell E config (max_position_pct_long=0.14, max_long_exposure_pct=0.70, min_cash_pct=0.30,
;; stage3 force-exit h=1, laggard rotation h=2).
;;
;; Measured 2026-06-05 (Cell E, PIT top-1000-2015). Tolerances ±20%
;; (return/DD/sharpe/trades/holding), win_rate ±5pp — first PIT pin.
;;
;; RE-PINNED 2026-06-24 (#1729 decision C): complete-universe warehouse run
;; (top-1000-2015, 1000/1000 symbols loaded; 1015 incl. ^GSPC + sector ETFs).
;; The prior band (49.3-73.9%) was measured against an incomplete
;; (survivor-subset, ~462/1000) test_data store — the runner silently skipped
;; the missing symbols, inflating return. Re-measured against the
;; delisting-complete warehouse snapshot /tmp/snap_top3000_1998_2026 (3015 syms);
;; the complete top-1000-2015 universe drops the return from 49-74% to ~38%.
;; Determinism established on the sibling decade cell (bit-identical across two
;; runs). This cell will (correctly) keep FAILING in GHA perf-tier4 against the
;; incomplete committed test_data — that failure is the intentional missing-data
;; signal; a local snapshot run reproduces the band below.
;;
;; Measured 2026-06-24 (complete-universe warehouse, top-1000-2015):
;;   total_return_pct 37.91   total_trades 259   win_rate 34.75
;;   sharpe_ratio 0.47   max_drawdown 17.44   avg_holding_days 43.80   calmar 0.32
;; Tolerances ±20% (return/DD/sharpe/trades/holding), win_rate ±5pp.
((name "bull-crash-2015-2020")
 (description "Strong bull market through the 2020 crash (PIT top-1000-2015)")
 (period ((start_date 2015-01-02) (end_date 2020-12-31)))
 (universe_path "../goldens-custom-universe/composition/top-1000-2015.sexp")
 (universe_size 1000)
 (config_overrides
  (((enable_short_side false))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (expected
  ((total_return_pct   ((min 30.3) (max 45.5)))
   (total_trades       ((min 207) (max 311)))
   (win_rate           ((min 29.7) (max 39.7)))
   (sharpe_ratio       ((min 0.38) (max 0.57)))
   (max_drawdown_pct   ((min 14.0) (max 20.9)))
   (avg_holding_days   ((min 35.0) (max 52.6))))))
