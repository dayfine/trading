;; perf-tier: 4-scale
;; perf-tier-rationale: Tier-4 release-gate SCALE mechanic-validation cell at
;; full broad universe (~10,472 symbols from data/sectors.csv) × 1y. Probes
;; the snapshot-mode runtime path (default since #802 / Phase F.2) end-to-end
;; on the full Friday-cycle universe over a short calendar wall, before
;; committing to the multi-hour `tier4-broad-10y` run.
;;
;; Why a 1y mechanic-validation cell ahead of the 10y SCALE cell:
;; per `dev/notes/tier4-release-gate-checklist-2026-04-28.md`, the 10y SCALE
;; cell has never been run locally and brings together several first-time-at-
;; -scale infrastructure pieces (snapshot-corpus auto-build, full-broad
;; universe load, cache-bounded RSS budget ~50-200 MB). Running 10k×1y first
;; surfaces any infrastructure problem in minutes rather than hours: if 1y
;; holds at the cache-bounded RSS budget, high confidence the 10y will too.
;; The runtime path is otherwise identical (same universe, same snapshot
;; mode, same screener/portfolio gates) — only the calendar wall differs.
;;
;; Universe: `universes/broad.sexp` is the `Full_sector_map` sentinel that
;; resolves at runtime to whatever symbols are in `data/sectors.csv` (today
;; 10,472 entries; verify with `dev/scripts/check_broad_universe_coverage.sh`).
;; No `universe_cap` — let the runtime use the full sentinel.
;;
;; Run via `dev/scripts/run_tier4_release_gate.sh` (auto-discovers all
;; `;; perf-tier: 4-scale` cells under `goldens-broad/`). Both this 1y cell
;; and the existing `tier4-broad-10y.sexp` will be discovered; run the 1y
;; cell on its own first via the runner's stage-dir mechanism, or rely on
;; the runner's per-cell timeout to gate them in sequence.
;;
;; Window rationale: 2022-01-03 to 2022-12-30 — a clean trading-calendar
;; year. 2022 sits well inside the local data coverage window (post-2010
;; deep-history gaps avoided) and overlaps multiple existing N=1000
;; baselines, so the cell can be sanity-checked against those if needed.
;;
;; STATUS: SCAFFOLDING ONLY — `expected` ranges are intentionally permissive
;; (BASELINE_PENDING_AFTER_FIRST_RUN). The first manual local run on the
;; user's 8 GB box (under snapshot mode + auto-built snapshot corpus)
;; produces the canonical baseline; tighten ranges via follow-up PR after
;; that run lands. Until then this cell SHALL NOT be added to any recurring
;; workflow.
;;
;; PINNED_AFTER_FIRST_RUN — leave `expected` ranges wide; first local run
;; populates them.
;;
;; VERIFIED 2026-06-24 (#1729 sub-task 2): ran clean at FULL N=3000 in snapshot
;; mode against /tmp/snap_top3000_1998_2026 (PIT top-3000-2022, 3015 syms incl.
;; index+ETFs) — snapshot cache evictions=0 at the 4 GB cap, NO memory ceiling
;; (confirms the snapshot-format-v2 #1631 fix; retires project_panel_runner_memory_ceiling
;; for the broad goldens). Measured: total_return_pct -10.41, total_trades 16,
;; win_rate 6.25, sharpe -0.855, max_drawdown 19.64, avg_holding_days 40.19,
;; calmar -0.536, ulcer 10.37, open_positions_value 865,873 (low trade count =
;; 2022 bear tape, macro gate suppressed entries — expected). Ranges intentionally
;; LEFT WIDE per the SCAFFOLDING/scale-validation purpose of this cell (it probes the
;; runtime path at scale, not a return regression). See
;; dev/backtest/broad-golden-top3000-verify-2026-06-24/FINDINGS.md.
((name "tier4-broad-1y")
 (description "Tier-4 release-gate SCALE — full broad universe × 1y mechanic validation (snapshot-mode only)")
 (period ((start_date 2022-01-03) (end_date 2022-12-30)))
 ;; PIT-clean universe migration 2026-06-06 (dev/plans/goldens-broad-pit-migration-2026-06-05.md):
 ;; replaced the non-reproducible `universes/broad.sexp` sentinel (Full_sector_map →
 ;; "whatever is in the live, growing data/sectors.csv", ~10,472 today) with the frozen
 ;; point-in-time `top-3000-2022` composition snapshot — the largest reproducible PIT
 ;; universe available, survivorship-clean (includes names that failed afterward). The cell
 ;; is now reproducible and no longer drifts when sectors.csv changes. top-3000 (3015 with
 ;; index+ETFs) is a legitimate large-N SCALE target — see the 2026-06-06 N=3000 local
 ;; snapshot proof (peak ~3 GB RSS, bounded). Ranges stay wide (this cell was SCAFFOLDING-
 ;; ONLY / never pinned); a follow-up run pins them.
 (universe_path "../goldens-custom-universe/composition/top-3000-2022.sexp")
 (universe_size 3000)
 ;; enable_short_side disabled mirroring the N=1000 tier-4 cells and the
 ;; tier4-broad-10y cell (dev/notes/short-side-gaps-2026-04-29.md G1-G4
 ;; unresolved). Revert when short-side gaps close + the override is
 ;; dropped from the long-only family.
 (config_overrides (((enable_short_side false))))
 ;; PINNED_AFTER_FIRST_RUN — wide ranges. First local run on the user's 8 GB
 ;; box under snapshot mode produces the canonical baseline; tighten ranges
 ;; via follow-up PR once captured. The wide bounds below confirm "the run
 ;; completed without OOM/crash and produced non-degenerate metrics" — same
 ;; pattern as `tier4-broad-10y.sexp` and `sp500-30y-capacity-1996.sexp`.
 (expected
  ((total_return_pct   ((min -1000.0)        (max 1000000.0)))
   (total_trades       ((min 0)              (max 100000)))
   (win_rate           ((min 0.0)            (max 100.0)))
   (sharpe_ratio       ((min -10.0)          (max 10.0)))
   (max_drawdown_pct   ((min 0.0)            (max 100.0)))
   (avg_holding_days   ((min 0.0)            (max 10000.0)))
   (open_positions_value ((min -1000000000.0) (max 100000000000.0))))))
