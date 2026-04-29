;; perf-tier: 4
;; perf-tier-rationale: Tier-4 release-gate cell — full decade (2014-2023, ~10y) at N=1000. The flagship "can we run a decade-long backtest at scale?" cell. Per dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md (RSS ≈ 67 + 3.94·N + 0.19·N·(T−1)), projects to ~5.7 GB peak at N=1000×10y — fits the 8 GB ceiling. Run on-demand via `dev/scripts/perf_tier4_release_gate.sh` (see `dev/notes/tier4-release-gate-checklist-2026-04-28.md`) when cutting a release. N>=5000 release-gate stays P1 awaiting daily-snapshot streaming (dev/plans/daily-snapshot-streaming-2026-04-27.md).
;;
;; STATUS: BASELINE_PENDING — expected ranges are intentionally wide because no
;; fresh baseline run has been recorded yet. The first manual dispatch of
;; `dev/scripts/perf_tier4_release_gate.sh` produces the canonical baseline; tighten ranges via
;; a follow-up PR after that run lands. Until ranges are tightened, this cell
;; catches catastrophic regressions only (sign flips, wholesale wipeouts, OOM);
;; fine-grained perf gating happens in tier-1/tier-2/tier-3.
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
 (config_overrides (((universe_cap (1000)))))
 (expected
  ((total_return_pct   ((min -100.0)  (max 2000.0)))
   (total_trades       ((min 0)       (max 2000)))
   (win_rate           ((min 0.0)     (max 100.0)))
   (sharpe_ratio       ((min -10.0)   (max 10.0)))
   (max_drawdown_pct   ((min 0.0)     (max 100.0)))
   (avg_holding_days   ((min 0.0)     (max 1000.0))))))
