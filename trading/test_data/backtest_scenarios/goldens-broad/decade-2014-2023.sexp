;; perf-tier: 4
;; perf-tier-rationale: N=1000 × this window. Per dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md (RSS ≈ 67 + 3.94·N + 0.19·N·(T−1) MB), this projects to ~5.7 GB peak RSS — fits the local 7.75 GB Docker ceiling. Run on-demand via `dev/scripts/perf_tier4_release_gate.sh`.
;;
;; PIT-clean universe migration 2026-06-05 (dev/plans/goldens-broad-pit-migration-2026-06-05.md).
;; Replaced the non-reproducible `universes/broad.sexp` sentinel (Full_sector_map +
;; universe_cap=1000 = "first-1000 of the live, growing data/sectors.csv") with the frozen
;; point-in-time composition snapshot `top-1000-2014` (the 1000 largest by historical
;; cap-weight as of the window start, survivorship-clean — it includes names that failed
;; afterward). The universe is now reproducible: it no longer shifts when sectors.csv changes.
;; Numbers differ from the prior top-N pins because that universe was a drifting artifact, not
;; because of a regression — see the migration plan for the diagnosis.
;;
;; enable_short_side stays false (short-side gaps G1-G4, dev/notes/short-side-gaps-2026-04-29.md).
;; Cell E config (max_position_pct_long=0.30, max_long_exposure_pct=0.70, min_cash_pct=0.30,
;; stage3 force-exit h=1, laggard rotation h=2).
;;
;; Measured 2026-06-05 (Cell E, PIT top-1000-2014). Tolerances ±20%
;; (return/DD/sharpe/trades/holding), win_rate ±5pp — first PIT pin.
;;
;; RE-PINNED 2026-06-24 (#1729 decision C): complete-universe warehouse run
;; (top-1000-2014, 1000/1000 symbols loaded; 1015 incl. ^GSPC + sector ETFs).
;; The prior band (105.3-157.9%) was measured against an incomplete
;; (survivor-subset, ~462/1000) test_data store — the runner silently skipped
;; the missing symbols, inflating return. Re-measured against the
;; delisting-complete warehouse snapshot /tmp/snap_top3000_1998_2026 (3015 syms).
;; Deterministic: two independent warehouse runs produced bit-identical metrics.
;; This cell will (correctly) keep FAILING in GHA perf-tier4 against the
;; incomplete committed test_data — that failure is the intentional missing-data
;; signal; a local snapshot run reproduces the band below.
;;
;; Measured 2026-06-24 (complete-universe warehouse, top-1000-2014):
;;   total_return_pct 95.28   total_trades 462   win_rate 32.25
;;   sharpe_ratio 0.50   max_drawdown 37.07   avg_holding_days 45.20   calmar 0.19
;; Tolerances ±20% (return/DD/sharpe/trades/holding), win_rate ±5pp.
((name "decade-2014-2023")
 (description "10-year decade run spanning multiple regimes (PIT top-1000-2014)")
 (period ((start_date 2014-01-02) (end_date 2023-12-29)))
 (universe_path "../goldens-custom-universe/composition/top-1000-2014.sexp")
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
  ;; re-measure, ±20% around 0.30 actuals (ret 133.77 sharpe 0.565 maxDD 38.76).
  ;; 0.30 lifts this 10y window's return (95->134%) at a modest DD rise (37->39%).
  ;; Re-pinned 2026-07-08 for the warmup 210→364 fix (RS present from the first
  ;; screen; dev/notes/warmup-364-repin-2026-07-08.md), ±20% around 364 actuals
  ;; vs rebuilt warehouse: ret 89.64  trades 324  win 36.73  sharpe 0.52
  ;; maxDD 26.37  hold 52.90 (return down 134→90, DD down 39→26 on this window).
  ((total_return_pct   ((min 71.7) (max 107.6)))
   (total_trades       ((min 259) (max 389)))
   (win_rate           ((min 29.4) (max 44.1)))
   (sharpe_ratio       ((min 0.42) (max 0.63)))
   (max_drawdown_pct   ((min 21.1) (max 31.6)))
   (avg_holding_days   ((min 42.3) (max 63.5))))))
