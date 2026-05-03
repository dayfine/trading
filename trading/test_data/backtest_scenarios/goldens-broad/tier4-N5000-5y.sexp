;; perf-tier: 4-scale
;; perf-tier-rationale: Tier-4 release-gate SCALE cell at N=5000 × 5y (2019-2023). Probes whether the snapshot-mode runtime path (default since #802 / Phase F.2) can hold the full Friday-cycle universe at 5x the production size. CSV-mode upper bound (RSS ≈ 67 + 3.94·N + 0.19·N·(T−1)) projects ~23.6 GB peak — far beyond any single runner — so this cell is reachable ONLY under snapshot mode (Phase E §F3 cache-bounded RSS ~50–200 MB). Run on-demand via `dev/scripts/run_tier4_release_gate.sh` (NOT the pre-existing `perf_tier4_release_gate.sh`, which auto-discovers `;; perf-tier: 4` cells only). Local-only: needs the 5000-symbol snapshot corpus pre-built; ops-data agent in flight on the prerequisite 15y sp500 historical fetch.
;;
;; STATUS: SCAFFOLDING ONLY — `expected` ranges are intentionally
;; permissive (BASELINE_PENDING_AFTER_FIRST_RUN). The first manual local run
;; on the user's 8 GB box (under snapshot mode + auto-built snapshot corpus)
;; produces the canonical baseline; tighten ranges via follow-up PR after
;; that run lands. Until then this cell SHALL NOT be added to any recurring
;; workflow.
;;
;; Why a separate sub-tier (`perf-tier: 4-scale`) vs the existing `perf-tier: 4`:
;;   1. The existing tier-4 cells (`bull-crash-2015-2020`, `covid-recovery-2020-2024`,
;;      `decade-2014-2023`, `six-year-2018-2023`) are pinned at N=1000 and
;;      validated to fit 8 GB under CSV mode. They run today via
;;      `dev/scripts/perf_tier4_release_gate.sh` at every release cut.
;;   2. The N=5000 / N=10000 scale cells require snapshot-mode runtime + a
;;      pre-built snapshot corpus that does not yet exist. Tagging them with
;;      a distinct sub-tier (`4-scale`) keeps them OFF the standard tier-4
;;      runner until both prereqs land.
;;
;; Window rationale: 2019-2023 mirrors the canonical sp500-2019-2023 cell so
;; this cell can be A/B-compared against the small-universe sp500 baseline once
;; the snapshot corpus is wide enough to contain both.
;;
;; PINNED_AFTER_FIRST_RUN — leave `expected` ranges wide; first local run
;; populates them.
((name "tier4-N5000-5y")
 (description "Tier-4 release-gate SCALE — 5y × N=5000 (snapshot-mode only)")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/broad.sexp")
 (universe_size 5000)
 ;; enable_short_side disabled mirroring the N=1000 tier-4 cells
 ;; (dev/notes/short-side-gaps-2026-04-29.md G1-G4 unresolved). Revert when
 ;; short-side gaps close + the override is dropped from the long-only family.
 (config_overrides (((universe_cap (5000)) (enable_short_side false))))
 ;; PINNED_AFTER_FIRST_RUN — wide ranges. First local run on the user's 8 GB
 ;; box under snapshot mode produces the canonical baseline; tighten ranges
 ;; via follow-up PR once captured. The wide bounds below confirm "the run
 ;; completed without OOM/crash and produced non-degenerate metrics" — same
 ;; pattern as `goldens-broad/sp500-30y-capacity-1996.sexp`.
 (expected
  ((total_return_pct   ((min -1000.0)        (max 1000000.0)))
   (total_trades       ((min 0)              (max 100000)))
   (win_rate           ((min 0.0)            (max 100.0)))
   (sharpe_ratio       ((min -10.0)          (max 10.0)))
   (max_drawdown_pct   ((min 0.0)            (max 100.0)))
   (avg_holding_days   ((min 0.0)            (max 10000.0)))
   (open_positions_value ((min -1000000000.0) (max 100000000000.0))))))
