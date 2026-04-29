;; perf-tier: 4
;; perf-tier-rationale: Tier-4 release-gate cell at N=1000 × ~5y (2020 COVID crash through 2024 recovery). Run on-demand via `dev/scripts/perf_tier4_release_gate.sh` (see `dev/notes/tier4-release-gate-checklist-2026-04-28.md`) when cutting a release. Per dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md (β=3.94 MB/symbol), N=1000×5y projects to ~4.8 GB peak RSS, fits the 8 GB ceiling. N>=5000 release-gate stays P1 awaiting daily-snapshot streaming (dev/plans/daily-snapshot-streaming-2026-04-27.md).
;;
;; STATUS: BASELINE_PENDING — expected ranges are intentionally wide because no
;; fresh N=1000 baseline run has been recorded yet. The first manual dispatch
;; of `dev/scripts/perf_tier4_release_gate.sh` produces the canonical baseline; tighten ranges
;; via a follow-up PR after that run lands. Until ranges are tightened, this
;; cell catches catastrophic regressions only (sign flips, wholesale wipeouts,
;; OOM); fine-grained perf gating happens in tier-1/tier-2/tier-3.
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
 (config_overrides (((universe_cap (1000)))))
 (expected
  ((total_return_pct   ((min -100.0)  (max 1000.0)))
   (total_trades       ((min 0)       (max 1000)))
   (win_rate           ((min 0.0)     (max 100.0)))
   (sharpe_ratio       ((min -10.0)   (max 10.0)))
   (max_drawdown_pct   ((min 0.0)     (max 100.0)))
   (avg_holding_days   ((min 0.0)     (max 1000.0))))))
