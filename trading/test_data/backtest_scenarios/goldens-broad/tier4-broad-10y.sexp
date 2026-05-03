;; perf-tier: 4-scale
;; perf-tier-rationale: Tier-4 release-gate SCALE cell at full broad universe
;; (~10,472 symbols from data/sectors.csv) × 10y. Probes whether the
;; snapshot-mode runtime path (default since #802 / Phase F.2) holds the full
;; Friday-cycle universe end-to-end. CSV-mode upper bound
;; (RSS ≈ 67 + 3.94·N + 0.19·N·(T−1)) projects ~28 GB peak — far beyond any
;; single runner — so this cell is reachable ONLY under snapshot mode
;; (Phase E §F3 cache-bounded RSS ~50–200 MB).
;;
;; Universe: `universes/broad.sexp` is the `Full_sector_map` sentinel that
;; resolves at runtime to whatever symbols are in `data/sectors.csv`. Today
;; that's 10,472 entries (verify with `dev/scripts/check_broad_universe_coverage.sh`).
;; No `universe_cap` — let the runtime use the full sentinel. The earlier
;; N=5000 / N=10000 sub-cells (PR #810) are obsoleted by this one cell since
;; the broad sentinel's actual size (10,472) is essentially N=10000 already.
;;
;; STATUS: SCAFFOLDING ONLY — `expected` ranges are intentionally permissive
;; (BASELINE_PENDING_AFTER_FIRST_RUN). The first manual local run on the user's
;; 8 GB box (under snapshot mode + auto-built snapshot corpus) produces the
;; canonical baseline; tighten ranges via follow-up PR after that run lands.
;; Until then this cell SHALL NOT be added to any recurring workflow.
;;
;; Window rationale: 2014-2023 mirrors the canonical `decade-2014-2023.sexp`
;; cell (N=1000 baseline) so this cell can be A/B-compared against that small-
;; universe baseline. Same start/end dates → same trading days → same Friday
;; cycle gates.
;;
;; Run via `dev/scripts/run_tier4_release_gate.sh` (NOT the pre-existing
;; `perf_tier4_release_gate.sh`, which auto-discovers `;; perf-tier: 4` cells
;; only).
;;
;; PINNED_AFTER_FIRST_RUN — leave `expected` ranges wide; first local run
;; populates them.
((name "tier4-broad-10y")
 (description "Tier-4 release-gate SCALE — full broad universe × 10y (snapshot-mode only)")
 (period ((start_date 2014-01-02) (end_date 2023-12-29)))
 (universe_path "universes/broad.sexp")
 (universe_size 10472)
 ;; enable_short_side disabled mirroring the N=1000 tier-4 cells
 ;; (dev/notes/short-side-gaps-2026-04-29.md G1-G4 unresolved). Revert when
 ;; short-side gaps close + the override is dropped from the long-only family.
 (config_overrides (((enable_short_side false))))
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
