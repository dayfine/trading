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
 (config_overrides (((universe_cap (1000)) (enable_short_side false))))
 ;; Baseline measured 2026-04-29 (long-only):
 ;;   return +148.77% / 91 trades / win_rate 39.56% / Sharpe 0.508 /
 ;;   MaxDD 62.91% / avg_hold 61.0d / open_positions_value $2.39M /
 ;;   peak RSS 1,650 MB / wall 2:33.
 (expected
  ((total_return_pct   ((min 126.0)        (max 172.0)))     ;; ±15% around 148.8
   (total_trades       ((min 81)           (max 101)))       ;; ±10 around 91
   (win_rate           ((min 33.5)         (max 45.5)))      ;; ±15% around 39.6
   (sharpe_ratio       ((min 0.25)         (max 0.75)))      ;; small absolute, wider relative
   (max_drawdown_pct   ((min 56.5)         (max 69.5)))      ;; ±10% around 62.9
   (avg_holding_days   ((min 55.0)         (max 67.5)))      ;; ±10% around 61.0
   (open_positions_value ((min 2030000.0)  (max 2760000.0))))))  ;; ±15% around $2.39M (mtm value, NOT true unrealized P&L; see metric_types.mli)
