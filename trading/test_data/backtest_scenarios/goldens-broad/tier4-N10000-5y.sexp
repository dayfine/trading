;; perf-tier: 4-scale
;; perf-tier-rationale: Tier-4 release-gate SCALE cell at N=10000 × 5y (2019-2023). The widest universe cell in the catalog — exercises the snapshot-mode runtime at the 10x-of-production scale ceiling. CSV-mode upper bound (RSS ≈ 67 + 3.94·N + 0.19·N·(T−1)) projects ~47 GB peak — well beyond any single runner — so this cell is reachable ONLY under snapshot mode (Phase E §F3 cache-bounded RSS ~50–200 MB). Run on-demand via `dev/scripts/run_tier4_release_gate.sh` (NOT the pre-existing `perf_tier4_release_gate.sh`, which auto-discovers `;; perf-tier: 4` cells only). Local-only: needs the 10000-symbol snapshot corpus pre-built; ops-data agent in flight on the prerequisite 15y sp500 historical fetch.
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
;; Window rationale: 2019-2023 (5y) at N=10000 — chose 5y over 10y because
;; (a) the snapshot-mode RSS ceiling is independent of T (cache-bounded), but
;; the per-day snapshot file size scales with N, so seek + LRU pressure is
;; what 10000 universe-cap probes; (b) keeping T at 5y limits the absolute
;; wall budget — at the largest cell the wall is dominated by per-Friday
;; screener work, which scales with N × Fridays. 5y × 10000 ≈ 260 × 10000 =
;; 2.6M screener-cycles, comparable to 10y × 5000.
;;
;; This cell is the canonical "can the streaming runtime hold the full
;; Friday-cycle universe at production scale" certification. If this passes
;; cleanly under snapshot mode, the streaming pivot is validated end-to-end.
;;
;; PINNED_AFTER_FIRST_RUN — leave `expected` ranges wide; first local run
;; populates them.
((name "tier4-N10000-5y")
 (description "Tier-4 release-gate SCALE — 5y × N=10000 (snapshot-mode only)")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/broad.sexp")
 (universe_size 10000)
 ;; enable_short_side disabled — see `tier4-N5000-5y.sexp` for rationale.
 (config_overrides (((universe_cap (10000)) (enable_short_side false))))
 ;; PINNED_AFTER_FIRST_RUN — wide ranges; first local run populates them.
 (expected
  ((total_return_pct   ((min -1000.0)        (max 1000000.0)))
   (total_trades       ((min 0)              (max 100000)))
   (win_rate           ((min 0.0)            (max 100.0)))
   (sharpe_ratio       ((min -10.0)          (max 10.0)))
   (max_drawdown_pct   ((min 0.0)            (max 100.0)))
   (avg_holding_days   ((min 0.0)            (max 10000.0)))
   (open_positions_value ((min -1000000000.0) (max 100000000000.0))))))
