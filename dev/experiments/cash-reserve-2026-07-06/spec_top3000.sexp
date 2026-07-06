;; Cash-reserve WF-CV surface — BROAD-ONLY (top-3000 decisive cell).
;; Mechanism #1867 (`cash_reserve_pct`, default 0.0 = no reserve): the WORKING
;; replacement for the dead Portfolio_risk.min_cash_pct (envelope-knobs-dead
;; finding, #1861). Backtests have always run ~0% reserve (89-99% deployed);
;; this is the first real test of holding cash back.
;;
;; Hypothesis (user-directed 2026-07-06): does a 10-30% reserve buy enough
;; DD/dispersion relief to justify the return cost? Prior expectation from
;; project_edge_is_the_fat_tail: reserve = breadth tax (fewer funded entries)
;; -> likely REJECT; but bear folds may gain, and either way this prices the
;; marginal value of the last-funded entries directly.
;;
;; Run: walk_forward_runner --spec <this> --out-dir /tmp/sweeps/cash-reserve-v1
;;   --snapshot-dir /workspaces/trading-1/dev/data/snapshots/wfcv-top3000-1998
;;   --parallel 1, with TRADING_DATA_DIR=/workspaces/trading-1/trading/test_data
;;   passed via docker exec -e (universe_path resolution gotcha, see
;;   early-stage2-window writeup Ops notes).
((base_scenario "/workspaces/trading-1/dev/experiments/continuation-add-v2-2026-07-05/base_top3000.sexp")
 (window_spec
  (Rolling
   ((start_date 2000-01-01)(end_date 2026-04-30)(train_days 0)(test_days 730)(step_days 730))))
 (variants
  (((label "baseline") (overrides ()))
   ((label "r10")
    (overrides (((cash_reserve_pct 0.10)))))
   ((label "r20")
    (overrides (((cash_reserve_pct 0.20)))))
   ((label "r30")
    (overrides (((cash_reserve_pct 0.30)))))))
 (baseline_label "baseline")
 (gate ((metric Sharpe)(m 7)(n 13)(worst_delta 0.30))))
