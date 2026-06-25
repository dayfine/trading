;; Capacity/concentration surface — BROAD top-3000, DEEP 2000-2026.
;; The SP500-515 surface (capacity-concentration-*) was the WRONG basis: too narrow
;; to exercise the capacity bottleneck (few breakout winners competing for cash), so
;; the concentration signal washed out (knife-edge 0.25 spike, no robust value). The
;; optimal-lens capacity diagnosis (Insufficient_cash, ~280 churned trades) came from
;; the BROAD top-3000 run, where breadth makes the bottleneck WORSE. This re-runs the
;; concentration lever on the broad basis (user correction 2026-06-25).
;; Hypothesis: on broad, the concentration curve STEEPENS monotonically (0.14->0.30->0.50)
;; because there are many more winners to fund, vs the flat/knife-edge SP500 result.
;; Run: walk_forward_runner --snapshot-dir /tmp/snap_top3000_1998_2026 --parallel 1
;; (N=3000 needs fork-per-fold + warehouse mmap). 2-year folds to bound wall-time
;; (~3min/fold at parallel=1); geometry differs from the 1y/26-fold SP500 run, so the
;; comparison is DIRECTIONAL (curve shape), not metric-exact. baseline anchor = 0.14.
((base_scenario "test_data/backtest_scenarios/goldens-sp500-historical/top3000-2000-2026-catstop.sexp")
 (window_spec
  (Rolling ((start_date 2000-01-01) (end_date 2026-04-30) (train_days 0) (test_days 730) (step_days 730))))
 (baseline_label baseline)
 (gate ((metric Sharpe) (m 7) (n 13) (worst_delta 0.0)))
 (axes
  ((axes
    (((key (portfolio_config max_position_pct_long)) (values (0.14 0.30 0.50)))))
   (expansion Cartesian))))
