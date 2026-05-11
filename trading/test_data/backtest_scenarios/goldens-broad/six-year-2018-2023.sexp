;; perf-tier: 4
;; perf-tier-rationale: Tier-4 release-gate cell at N=1000 × 6y (2018-2023 incl. COVID crash and recovery). Run on-demand via `dev/scripts/perf_tier4_release_gate.sh` (see `dev/notes/tier4-release-gate-checklist-2026-04-28.md`) when cutting a release. Per dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md (β=3.94 MB/symbol), N=1000×6y projects to ~5.0 GB peak RSS, fits the 8 GB ceiling. N>=5000 release-gate stays P1 awaiting daily-snapshot streaming (dev/plans/daily-snapshot-streaming-2026-04-27.md).
;;
;; STATUS: long-only baseline pinned 2026-04-29. Expected ranges are tightened
;; to ±~15% around the canonical long-only baseline measured on 2026-04-29
;; (post-#682 — `enable_short_side = false`). See
;; dev/notes/goldens-broad-long-only-baselines-2026-04-29.md for the run output
;; and reasoning. Re-pin once short-side gaps G1-G4
;; (dev/notes/short-side-gaps-2026-04-29.md) close and the override is reverted.
;;
;; Golden (broad-1000): 6-year run covering COVID crash and recovery, run
;; against the full sector-map with universe_cap=1000.
;;
;; Shares the same name as the small-universe counterpart under goldens-small/
;; for easy A/B; the runner keys by [name + universe_path].
;;
;; See bull-crash-2015-2020.sexp for the rationale on universe_cap=1000.
((name "six-year-2018-2023")
 (description "6-year run covering COVID crash and recovery (broad-1000 universe)")
 (period ((start_date 2018-01-02) (end_date 2023-12-29)))
 (universe_path "universes/broad.sexp")
 (universe_size 1000)
 ;; enable_short_side disabled 2026-04-29: short-side gaps (G1-G4 in
 ;; dev/notes/short-side-gaps-2026-04-29.md) produce broken metrics on any
 ;; scenario crossing a Bearish-macro window. Until the gaps close, this
 ;; cell runs long-only — see dev/notes/goldens-broad-long-only-baselines-2026-04-29.md.
 ;; Cell E rollout 2026-05-11: applies the new standard strategy config
 ;; (max_position_pct_long=0.14, max_long_exposure_pct=0.70, min_cash_pct=0.30,
 ;; stage3 force-exit h=1, laggard rotation h=2). Replaces prior 0.30/0.90/0.10
 ;; default-sized baseline (35.34% / 167 trades / 74.9% DD on N=1000 broad).
 ;; Measured 2026-05-11 (Cell E, N=1000 broad):
 ;;   total_return_pct  207.9   total_trades 360   win_rate 34.4
 ;;   sharpe_ratio       0.64   max_drawdown 44.7  avg_holding_days  36
 ;;   open_positions_value 1,769,145
 ;; Return 6x (35 → 208), MaxDD cut 30pp (75 → 45). Tolerances ±15%.
 (config_overrides
  (((universe_cap (1000)))
   ((enable_short_side false))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (expected
  ((total_return_pct   ((min 176.0)        (max 240.0)))
   (total_trades       ((min 306)          (max 414)))
   (win_rate           ((min  29.2)        (max  39.6)))
   (sharpe_ratio       ((min   0.54)       (max   0.74)))
   (max_drawdown_pct   ((min  38.0)        (max  51.4)))
   (avg_holding_days   ((min  31.0)        (max  41.0)))
   (open_positions_value ((min 1500000.0)  (max 2035000.0))))))
