;; perf-tier: 4
;; perf-tier-rationale: N=1000 × ~5y. Per dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md (RSS ≈ 67 + 3.94·N + 0.19·N·(T−1) MB), this projects to ~4.8 GB peak RSS — fits the local 7.75 GB Docker ceiling. Run on-demand via `dev/scripts/perf_tier4_release_gate.sh`.
;;
;; PIT-clean universe migration 2026-06-05 (dev/plans/goldens-broad-pit-migration-2026-06-05.md).
;; Replaced the non-reproducible `universes/broad.sexp` sentinel (Full_sector_map +
;; universe_cap=1000 = "first-1000 of the live, growing data/sectors.csv") with the frozen
;; point-in-time composition snapshot `top-1000-2020` (the 1000 largest by historical
;; cap-weight as of the window start, survivorship-clean — it includes names that failed
;; afterward, e.g. SIVB/FRC). The universe is now reproducible: it no longer shifts when
;; sectors.csv changes. Numbers are LOWER than the prior top-N pins (294.5% / 38.6% on
;; 2026-05-11) because that universe was a drifting artifact, not because of a regression —
;; see the migration plan for the full diagnosis.
;;
;; enable_short_side stays false (short-side gaps G1-G4, dev/notes/short-side-gaps-2026-04-29.md).
;; Cell E config (max_position_pct_long=0.14, max_long_exposure_pct=0.70, min_cash_pct=0.30,
;; stage3 force-exit h=1, laggard rotation h=2).
;;
;; Measured 2026-06-05 (Cell E, PIT top-1000-2020):
;;   total_return_pct 41.3   total_trades 272   win_rate 33.1
;;   sharpe_ratio 0.46   max_drawdown 36.1   avg_holding_days 38.7   calmar 0.20
;; Tolerances ±20% (return/DD/sharpe/trades/holding), win_rate ±5pp — first PIT pin.
;;
;; RE-PINNED 2026-06-24 (#1729 decision C): complete-universe warehouse run
;; (top-1000-2020, 1000/1000 symbols loaded; 1015 incl. ^GSPC + sector ETFs).
;; The prior band was measured against an incomplete (survivor-subset) test_data
;; store. Re-measured against the delisting-complete warehouse snapshot
;; /tmp/snap_top3000_1998_2026 (3015 syms). The complete-universe number (35.31%)
;; is close to the prior band (which happened to overlap), but the band is now
;; re-centred on the honest warehouse point. Determinism established on the
;; sibling decade cell (bit-identical across two runs). This cell will (correctly)
;; keep FAILING in GHA perf-tier4 against the incomplete committed test_data —
;; that failure is the intentional missing-data signal; a local snapshot run
;; reproduces the band below.
;;
;; Measured 2026-06-24 (complete-universe warehouse, top-1000-2020):
;;   total_return_pct 35.31   total_trades 277   win_rate 35.74
;;   sharpe_ratio 0.47   max_drawdown 29.78   avg_holding_days 39.09   calmar 0.21
;; Tolerances ±20% (return/DD/sharpe/trades/holding), win_rate ±5pp.
((name "covid-recovery-2020-2024")
 (description "COVID crash and recovery through 2024 (PIT top-1000-2020)")
 (period ((start_date 2020-01-02) (end_date 2024-12-31)))
 (universe_path "../goldens-custom-universe/composition/top-1000-2020.sexp")
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
  ((total_return_pct   ((min  28.2)  (max  42.4)))
   (total_trades       ((min 222)    (max 332)))
   (win_rate           ((min  30.7)  (max  40.7)))
   (sharpe_ratio       ((min   0.38) (max   0.56)))
   (max_drawdown_pct   ((min  23.8)  (max  35.7)))
   (avg_holding_days   ((min  31.3)  (max  46.9))))))
