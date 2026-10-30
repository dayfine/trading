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
  ;; Re-pinned 2026-07-11 for the realism-defaults flip (entry gate $1M ADV +
  ;; stale-exit 5d default-on; ledger 2026-07-10-realism-defaults-flip), ±20%
  ;; around flip actuals vs the same 364 warehouse: ret 36.86  trades 416
  ;; win 35.10  sharpe 0.27  maxDD 32.71  hold 49.99. Big move (90→37%) is the
  ;; flip biting hard on delisted-heavy top-1000 PIT: stale-exit force-exits
  ;; ghosts and recycles the cash (trades 324→416), the ADV gate drops the
  ;; illiquid tail of the prior entry set. Some prior "return" here was
  ;; unrealizable ghost/illiquid MTM the flip exists to remove; the rest is
  ;; path divergence on a 10y compounding window. Covid twin BIT-IDENTICAL.
  ;; RE-PINNED 2026-09-03 for the D1/D2 exit-basis default flip (PR #2648: sim_exit_fill_next_open + stop_skip_entry_bar on). ±15% around the NEW-arm actual at pinned build 398f57111 (total_return_pct: at least ±5pp); paired old arm (both knobs pinned false, run directly) + dissection in dev/experiments/exit-basis-flip-2026-09-03/. NOTE: the prior pin was already stale — it predates the 2026-08-24 (#2530) and 2026-08-26 (#2569) default flips; tier 4 is a local release gate with no CI consumer. Correctness re-pin: no return claim attaches to the delta.
  ;; RE-PINNED 2026-10-29 for the Seeded tiebreak default (#3425), ±15% around the new-arm actual (dev/experiments/tier4-seeded-repin-2026-10-29/). The prior pin was already stale: the Alphabetical arm fails it too. Single seed-0 draw; the cross-arm move is path noise (#3419), see the README.
  ;; SEED-BAND RE-PIN 2026-10-29 (#3404 follow-up): each metric is the min..max over tiebreak seeds 0-4, widened 15% each side (total_return_pct: at least 5pp); seeds and per-seed actuals in dev/experiments/tier4-seed-band-2026-10-29/. Seed-to-seed spread is path noise (#3419), so a single-seed ±15% pin fails on any path-perturbing change; this band fails only on moves outside that noise.
  ((total_return_pct ((min 272.3260) (max 847.6117)))
   (total_trades ((min 233.7500) (max 335.8000)))
   (win_rate ((min 28.3333) (max 45.4270)))
   (sharpe_ratio ((min 0.4403) (max 0.6944)))
   (max_drawdown_pct ((min 50.2428) (max 88.5314)))
   (avg_holding_days ((min 54.9909) (max 83.7085))))))
