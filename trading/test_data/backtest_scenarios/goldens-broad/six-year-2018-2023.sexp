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
 (config_overrides (((universe_cap (1000)) (enable_short_side false))))
 ;; Baseline measured 2026-04-29 (long-only):
 ;;   return +35.34% / 167 trades / win_rate 37.13% / Sharpe 0.301 /
 ;;   MaxDD 74.86% / avg_hold 72.6d / open_positions_value $1.18M /
 ;;   peak RSS 1,722 MB / wall 3:00.
 (expected
  ((total_return_pct   ((min 30.0)         (max 41.0)))     ;; ±15% around 35.3
   (total_trades       ((min 157)          (max 177)))      ;; ±10 around 167
   (win_rate           ((min 31.5)         (max 42.7)))     ;; ±15% around 37.1
   (sharpe_ratio       ((min 0.15)         (max 0.45)))     ;; small absolute, wider relative
   (max_drawdown_pct   ((min 67.5)         (max 82.5)))     ;; ±10% around 74.9
   (avg_holding_days   ((min 65.0)         (max 80.0)))     ;; ±10% around 72.6
   (open_positions_value ((min 999000.0)   (max 1352000.0))))))  ;; ±15% around $1.18M (mtm value, NOT true unrealized P&L; see metric_types.mli)
