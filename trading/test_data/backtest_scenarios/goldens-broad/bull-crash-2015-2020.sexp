;; perf-tier: 4
;; perf-tier-rationale: Tier-4 release-gate cell at N=1000 × ~6y (2015-2020 incl. 2020 crash). Run on-demand via `dev/scripts/perf_tier4_release_gate.sh` (see `dev/notes/tier4-release-gate-checklist-2026-04-28.md`) when cutting a release. Per dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md (β=3.94 MB/symbol), N=1000×6y projects to ~5.0 GB peak RSS, fits the 8 GB ceiling. N>=5000 release-gate stays P1 awaiting daily-snapshot streaming (dev/plans/daily-snapshot-streaming-2026-04-27.md).
;;
;; STATUS: long-only baseline pinned 2026-04-29. Expected ranges are tightened
;; to ±~15% around the canonical long-only baseline measured on 2026-04-29
;; (post-#682 — `enable_short_side = false`). See
;; dev/notes/goldens-broad-long-only-baselines-2026-04-29.md for the run output
;; and reasoning. Re-pin once short-side gaps G1-G4
;; (dev/notes/short-side-gaps-2026-04-29.md) close and the override is reverted.
;;
;; Golden (broad-1000): strong bull market through 2020 crash, run against the
;; full sector-map with universe_cap=1000.
;;
;; Why universe_cap=1000 here (vs Full_sector_map):
;;   1. RSS/wall budget: at β=3.94 MB/symbol, the full sector map (~10,472
;;      symbols today) projects to ~42 GB at 6y — does not fit any single
;;      runner. N=1000 is the largest cell that fits 8 GB at decade-length.
;;   2. Self-contained: previously the cap came from `--override` at the CLI;
;;      baking it into the scenario makes the release-gate cell reproducible
;;      from the .sexp alone.
((name "bull-crash-2015-2020")
 (description "Strong bull market through the 2020 crash (broad-1000 universe)")
 (period ((start_date 2015-01-02) (end_date 2020-12-31)))
 (universe_path "universes/broad.sexp")
 (universe_size 1000)
 ;; enable_short_side disabled 2026-04-29: short-side gaps (G1-G4 in
 ;; dev/notes/short-side-gaps-2026-04-29.md) produce broken metrics on any
 ;; scenario crossing a Bearish-macro window. Until the gaps close, this
 ;; cell runs long-only — see dev/notes/goldens-broad-long-only-baselines-2026-04-29.md.
 ;; Cell E rollout 2026-05-11: applies the new standard strategy config
 ;; (max_position_pct_long=0.14, max_long_exposure_pct=0.70, min_cash_pct=0.30,
 ;; stage3 force-exit h=1, laggard rotation h=2). Replaces prior 0.30/0.90/0.10
 ;; default-sized baseline (148.77% / 91 trades / 62.9% DD on N=1000 broad).
 ;; Measured 2026-05-11 (Cell E, N=1000 broad):
 ;;   total_return_pct  139.6   total_trades 308   win_rate 39.9
 ;;   sharpe_ratio       0.79   max_drawdown 31.6  avg_holding_days  46
 ;;   open_positions_value 2,252,200
 ;; MaxDD cut by half (63 → 32), trade count 3.4x. Tolerances ±15%.
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
  ((total_return_pct   ((min 118.0)        (max 161.0)))
   (total_trades       ((min 262)          (max 354)))
   (win_rate           ((min  33.9)        (max  45.9)))
   (sharpe_ratio       ((min   0.67)       (max   0.91)))
   (max_drawdown_pct   ((min  26.9)        (max  36.3)))
   (avg_holding_days   ((min  39.0)        (max  53.0)))
   (open_positions_value ((min 1915000.0)  (max 2590000.0))))))
