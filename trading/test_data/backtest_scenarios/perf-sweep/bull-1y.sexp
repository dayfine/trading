;; perf-tier: 3
;; perf-tier-rationale: Mid-scope perf-sweep cell (1 year / ~252 trading days at N=1000); weekly cadence (≤2 h budget). See dev/plans/perf-scenario-catalog-2026-04-25.md tier 3.
;;
;; Synthetic perf-sweep scenario — vary universe_cap via --override to extract
;; complexity curve. NOT a regression gate.
;;
;; Period: 2018-01-02 .. 2019-01-02 (~252 trading days). Anchor T datapoint
;; for the N-sweep at fixed T = 1y in the (N, T, strategy) sweep matrix
;; driven by dev/scripts/run_perf_sweep.sh. See bull-3m.sexp for the
;; rationale on universe_path / universe_size / expected-range shapes.
((name "bull-1y")
 (description "Perf-sweep cell — 1 year bull regime (2018)")
 (period ((start_date 2018-01-02) (end_date 2019-01-02)))
 (universe_path "universes/broad.sexp")
 (universe_size 1000)
 (config_overrides ())
 (expected
  ((total_return_pct   ((min -100.0) (max 1000.0)))
   (total_trades       ((min 0)      (max 1000)))
   (win_rate           ((min 0.0)    (max 100.0)))
   (sharpe_ratio       ((min -10.0)  (max 10.0)))
   (max_drawdown_pct   ((min 0.0)    (max 100.0)))
   (avg_holding_days   ((min 0.0)    (max 1000.0))))))
