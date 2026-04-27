;; perf-tier: 3
;; perf-tier-rationale: Hybrid-tier Phase 1 Experiment A filter-up arm. Same setup as sp500-default.sexp but candidate caps zeroed so no positions ever open. Weekly cadence (~2:30 expected; comparable to baseline since per-tick work is identical except for fill processing).
;;
;; Hybrid-tier Phase 1 Experiment A — FILTER-UP variant.
;;
;; Identical universe + period to sp500-default.sexp, but with screener
;; candidate caps overridden to zero. The screener cascade still runs in
;; full (compute scoring per stock), so per-tick work load is unchanged —
;; the only behavioural difference is that no candidates emerge, so no
;; positions are ever opened. Active-N drops from ~10–15 concurrent /
;; ~133 round trips (default) to 0.
;;
;; Why max_buy_candidates 0 + max_short_candidates 0 instead of
;; min_grade A_plus? Cleaner upstream cut: cascade still runs the full
;; scoring pipeline (so "did filter shorten work?" is not the variable),
;; but emits an empty result set, which means no Position / Stop_log /
;; trade-history accumulation across the run. That's the active-N
;; component the experiment is trying to isolate from loaded-N.
;;
;; Comparing peak RSS and wall between this variant and sp500-default.sexp
;; decomposes:
;;   * If RSS-default ≈ RSS-no-candidates (within 5%): β scales with
;;     loaded N regardless of activity → 3-tier (Cold/Warm/Hot) is the
;;     right hybrid-tier shape.
;;   * If RSS-no-candidates < 0.7 × RSS-default: β scales with active N →
;;     2-tier (Cold/Hot) suffices and per-position state hygiene is the
;;     bigger wedge.
;;
;; See dev/notes/hybrid-tier-phase1-cost-model-2026-04-26.md for the
;; experiment note.
((name "sp500-no-candidates-hybrid-tier-phase1")
 (description "Hybrid-tier Phase 1 Experiment A filter-up — S&P 500 5y, candidate caps zeroed")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 491)
 (config_overrides
  (((screening_config ((max_buy_candidates 0) (max_short_candidates 0))))))
 (expected
  ((total_return_pct   ((min -1.0)         (max 1.0)))
   (total_trades       ((min 0)            (max 0)))
   (win_rate           ((min 0.0)          (max 0.0)))
   (sharpe_ratio       ((min -1.0)         (max 1.0)))
   (max_drawdown_pct   ((min 0.0)          (max 5.0)))
   (avg_holding_days   ((min 0.0)          (max 1.0))))))
