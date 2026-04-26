;; perf-tier: 1
;; perf-tier-rationale: Smallest perf-sweep cell (3 months / ~63 trading days). Per-PR smoke cadence (≤2 min budget) when run with a small universe_cap override. See dev/plans/perf-scenario-catalog-2026-04-25.md tier 1.
;;
;; Synthetic perf-sweep scenario — vary universe_cap via --override to extract
;; complexity curve. NOT a regression gate.
;;
;; Period: 2018-01-02 .. 2018-04-02 (~63 trading days). Smallest T datapoint in
;; the (N, T, strategy) sweep matrix driven by dev/scripts/run_perf_sweep.sh.
;; Uses the broad universe sentinel so universe_cap overrides actually
;; constrain the loaded universe rather than being a no-op against the small
;; pinned set. universe_size = 1000 is metadata only — the largest cap we
;; intend to test in the sweep — and does not enforce a size.
;;
;; The expected ranges below are intentionally wide ((min ~minus-infinity)
;; (max ~plus-infinity)) — these scenarios are run by the perf sweep harness,
;; never by scenario_runner as a gate. If anyone wires this into a gate they
;; should first re-pin the ranges; that's why universe_size and the wide
;; ranges sit here as structurally valid but uninformative content.
((name "bull-3m")
 (description "Perf-sweep cell — 3 months bull regime (Q1 2018)")
 (period ((start_date 2018-01-02) (end_date 2018-04-02)))
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
