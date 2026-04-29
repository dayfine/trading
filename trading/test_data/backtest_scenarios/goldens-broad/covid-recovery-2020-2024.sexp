;; perf-tier: 4
;; perf-tier-rationale: Tier-4 release-gate cell at N=1000 × ~5y (2020 COVID crash through 2024 recovery). Run on-demand via `dev/scripts/perf_tier4_release_gate.sh` (see `dev/notes/tier4-release-gate-checklist-2026-04-28.md`) when cutting a release. Per dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md (β=3.94 MB/symbol), N=1000×5y projects to ~4.8 GB peak RSS, fits the 8 GB ceiling. N>=5000 release-gate stays P1 awaiting daily-snapshot streaming (dev/plans/daily-snapshot-streaming-2026-04-27.md).
;;
;; STATUS: long-only baseline pinned 2026-04-29. Expected ranges are tightened
;; to ±~15% around the canonical long-only baseline measured on 2026-04-29
;; (post-#682 — `enable_short_side = false`). See
;; dev/notes/goldens-broad-long-only-baselines-2026-04-29.md for the run output
;; and reasoning. Re-pin once short-side gaps G1-G4
;; (dev/notes/short-side-gaps-2026-04-29.md) close and the override is reverted.
;;
;; Golden (broad-1000): COVID crash and recovery through 2024, run against the
;; full sector-map with universe_cap=1000.
;;
;; See bull-crash-2015-2020.sexp for the rationale on universe_cap=1000.
((name "covid-recovery-2020-2024")
 (description "COVID crash and recovery through 2024 (broad-1000 universe)")
 (period ((start_date 2020-01-02) (end_date 2024-12-31)))
 (universe_path "universes/broad.sexp")
 (universe_size 1000)
 ;; enable_short_side disabled 2026-04-29: short-side gaps (G1-G4 in
 ;; dev/notes/short-side-gaps-2026-04-29.md) produce broken metrics on any
 ;; scenario crossing a Bearish-macro window. Until the gaps close, this
 ;; cell runs long-only — see dev/notes/goldens-broad-long-only-baselines-2026-04-29.md.
 (config_overrides (((universe_cap (1000)) (enable_short_side false))))
 ;; Baseline measured 2026-04-29 (long-only):
 ;;   return +15.12% / 149 trades / win_rate 20.81% / Sharpe 0.238 /
 ;;   MaxDD 75.30% / avg_hold 61.1d / unrealized_pnl $1.12M /
 ;;   peak RSS 1,693 MB / wall 2:50.
 (expected
  ((total_return_pct   ((min 12.5)         (max 17.5)))     ;; ±15% around 15.1
   (total_trades       ((min 139)          (max 159)))      ;; ±10 around 149
   (win_rate           ((min 17.5)         (max 24.0)))     ;; ±15% around 20.8
   (sharpe_ratio       ((min 0.10)         (max 0.40)))     ;; small absolute, wider relative
   (max_drawdown_pct   ((min 67.5)         (max 83.0)))     ;; ±10% around 75.3
   (avg_holding_days   ((min 55.0)         (max 67.5)))     ;; ±10% around 61.1
   (unrealized_pnl     ((min 955000.0)     (max 1295000.0))))))   ;; ±15% around 1.12M
