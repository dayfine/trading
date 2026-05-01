;; perf-tier: 4
;; perf-tier-rationale: Tier-4 release-gate cell — full decade (2014-2023, ~10y) at N=1000. The flagship "can we run a decade-long backtest at scale?" cell. Per dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md (RSS ≈ 67 + 3.94·N + 0.19·N·(T−1)), projects to ~5.7 GB peak at N=1000×10y — fits the 8 GB ceiling. Run on-demand via `dev/scripts/perf_tier4_release_gate.sh` (see `dev/notes/tier4-release-gate-checklist-2026-04-28.md`) when cutting a release. N>=5000 release-gate stays P1 awaiting daily-snapshot streaming (dev/plans/daily-snapshot-streaming-2026-04-27.md).
;;
;; STATUS: long-only baseline pinned 2026-04-29. Expected ranges are tightened
;; to ±~15% around the canonical long-only baseline measured on 2026-04-29
;; (post-#682 — `enable_short_side = false`). See
;; dev/notes/goldens-broad-long-only-baselines-2026-04-29.md for the run output
;; and reasoning. Re-pin once short-side gaps G1-G4
;; (dev/notes/short-side-gaps-2026-04-29.md) close and the override is reverted.
;;
;; Golden (broad-1000): full 10-year run spanning the post-2014 bull, 2018
;; correction, 2020 COVID crash, 2021 reflation rally, and 2022 bear. Run
;; against the full sector-map with universe_cap=1000. This is the single most
;; demanding cell in the catalog and the canonical "release-shippable"
;; certification: a regression here means the system can't reliably run the
;; longest-window scenario we care about.
;;
;; See bull-crash-2015-2020.sexp for the rationale on universe_cap=1000.
((name "decade-2014-2023")
 (description "10-year decade run spanning multiple regimes (broad-1000 universe)")
 (period ((start_date 2014-01-02) (end_date 2023-12-29)))
 (universe_path "universes/broad.sexp")
 (universe_size 1000)
 ;; enable_short_side disabled 2026-04-29: short-side gaps (G1-G4 in
 ;; dev/notes/short-side-gaps-2026-04-29.md) produce broken metrics on any
 ;; scenario crossing a Bearish-macro window. Until the gaps close, this
 ;; cell runs long-only — see dev/notes/goldens-broad-long-only-baselines-2026-04-29.md.
 (config_overrides (((universe_cap (1000)) (enable_short_side false))))
 ;; Baseline measured 2026-04-29 (long-only) — TWO independent runs landed:
 ;;   run-1: return +1582.85% / 145 trades / win_rate 40.69% / Sharpe 0.960 /
 ;;          MaxDD 94.31% / avg_hold 103.3d / open_positions_value $15.91M /
 ;;          peak RSS 1,956 MB / wall 4:31.
 ;;   run-2: return +1627.09% / 135 trades / win_rate 40.00% / Sharpe 0.960 /
 ;;          MaxDD 94.84% / avg_hold 98.0d  / open_positions_value $16.66M.
 ;; The decade cell is the ONLY one of the four goldens-broad cells that is
 ;; non-deterministic across reruns (3/4 are bit-identical). Source of the
 ;; variance is unknown — likely Hashtbl iteration order divergence accumulating
 ;; over the 10y horizon (see dev/notes/goldens-broad-long-only-baselines-2026-04-29.md
 ;; "Determinism" section). Ranges are widened to encompass both observed runs +
 ;; ~10% headroom; if subsequent reruns drift outside these ranges, prioritise
 ;; nailing down the source of non-determinism over re-pinning.
 (expected
  ((total_return_pct   ((min 1300.0)       (max 1900.0)))   ;; encompass 1582.9 + 1627.1, ±10% headroom
   (total_trades       ((min 125)          (max 160)))      ;; encompass 135 + 145, ±10 headroom
   (win_rate           ((min 34.0)         (max 47.0)))     ;; encompass 40.0 + 40.7, ±15% headroom
   (sharpe_ratio       ((min 0.65)         (max 1.30)))     ;; small absolute, wider relative
   (max_drawdown_pct   ((min 84.0)         (max 100.0)))    ;; encompass 94.3 + 94.8 (capped at 100)
   (avg_holding_days   ((min 88.0)         (max 115.0)))    ;; encompass 98.0 + 103.3, ±10% headroom
   (open_positions_value ((min 13500000.0) (max 19000000.0))))))  ;; encompass 15.9 + 16.7M (mtm value, NOT true unrealized P&L; see metric_types.mli)
