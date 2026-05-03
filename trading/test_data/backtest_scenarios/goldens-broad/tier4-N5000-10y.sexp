;; perf-tier: 4-scale
;; perf-tier-rationale: Tier-4 release-gate SCALE cell at N=5000 × 10y (2014-2023). The flagship "long-horizon × wide-universe" certification — exercises the snapshot-mode runtime over the same decade window as `decade-2014-2023.sexp` but at 5x universe size. CSV-mode upper bound (RSS ≈ 67 + 3.94·N + 0.19·N·(T−1)) projects ~28.3 GB peak — far beyond any single runner — so this cell is reachable ONLY under snapshot mode (Phase E §F3 cache-bounded RSS ~50–200 MB). Run on-demand via `dev/scripts/run_tier4_release_gate.sh` (NOT the pre-existing `perf_tier4_release_gate.sh`, which auto-discovers `;; perf-tier: 4` cells only). Local-only: needs the 5000-symbol snapshot corpus pre-built; ops-data agent in flight on the prerequisite 15y sp500 historical fetch.
;;
;; STATUS: SCAFFOLDING ONLY — `expected` ranges are intentionally
;; permissive (BASELINE_PENDING_AFTER_FIRST_RUN). The first manual local run
;; on the user's 8 GB box (under snapshot mode + auto-built snapshot corpus)
;; produces the canonical baseline; tighten ranges via follow-up PR after
;; that run lands. Until then this cell SHALL NOT be added to any recurring
;; workflow.
;;
;; Why a separate sub-tier (`perf-tier: 4-scale`) vs the existing `perf-tier: 4`:
;;   See `tier4-N5000-5y.sexp` for the rationale. Distinct sub-tier keeps these
;;   off `dev/scripts/perf_tier4_release_gate.sh` until the snapshot corpus +
;;   wide-universe data plumbing land.
;;
;; Window rationale: 2014-2023 mirrors `decade-2014-2023.sexp` (canonical
;; decade cell) so the wide-universe variant can be A/B-compared against the
;; N=1000 reference once the snapshot corpus contains both.
;;
;; Determinism caveat: `decade-2014-2023.sexp` (the N=1000 sibling) is the only
;; tier-4 cell that drifts across reruns (G6 finding —
;; `dev/notes/g6-decade-nondeterminism-investigation-2026-04-30.md`). The
;; multiplicative factor 520 Fridays × N=5000 puts this cell deeper into the
;; non-deterministic regime; expect drift across reruns until the
;; create_order.ml time-prefixed-IDs root cause is fixed (out of this PR's
;; scope; flagged for `feat-weinstein` / orders-owner follow-up).
;;
;; PINNED_AFTER_FIRST_RUN — leave `expected` ranges wide; first local run
;; populates them. First runs SHOULD be done as a pair (run-1 + run-2) so
;; the determinism drift can be measured from the start.
((name "tier4-N5000-10y")
 (description "Tier-4 release-gate SCALE — 10y × N=5000 (snapshot-mode only)")
 (period ((start_date 2014-01-02) (end_date 2023-12-29)))
 (universe_path "universes/broad.sexp")
 (universe_size 5000)
 ;; enable_short_side disabled — see `tier4-N5000-5y.sexp` for rationale.
 (config_overrides (((universe_cap (5000)) (enable_short_side false))))
 ;; PINNED_AFTER_FIRST_RUN — wide ranges; first local run populates them.
 (expected
  ((total_return_pct   ((min -1000.0)        (max 1000000.0)))
   (total_trades       ((min 0)              (max 100000)))
   (win_rate           ((min 0.0)            (max 100.0)))
   (sharpe_ratio       ((min -10.0)          (max 10.0)))
   (max_drawdown_pct   ((min 0.0)            (max 100.0)))
   (avg_holding_days   ((min 0.0)            (max 10000.0)))
   (open_positions_value ((min -1000000000.0) (max 100000000000.0))))))
