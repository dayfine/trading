((date 2026-07-10)
 (slug liquidity-overlay-wfcv)
 (hypothesis
  "The liquidity overlay (entry gate 1e6 + hold-degradation exit 5e5 dollar-ADV) that improved the honest-tradeable single path ~3.2x is a fold-robust QUALITY filter (junk-drag removal), decomposable into which sub-knob carries the effect")
 (base_scenario "goldens-sp500-historical/top3000-2000-2026-catstop.sexp")
 (window_id wfcv-deep-top3000-2000-2026-13fold-2y)
 (baseline_label baseline)
 (variants
  (((label min_hold_dollar_adv=5e5-only)
    (config_hash overlay-hold-exit-only-364basis)
    (aggregate
     ((sharpe_mean 0.753) (calmar_mean 1.131) (maxdd_mean 18.03)
      (return_mean 0.0) (pareto_frontier yes) (deflated_sharpe 0.9999))))
   ((label min_entry_dollar_adv=1e6-only)
    (config_hash overlay-entry-gate-only-364basis)
    (aggregate
     ((sharpe_mean 0.634) (calmar_mean 0.821) (maxdd_mean 17.42)
      (return_mean 0.0) (pareto_frontier yes) (deflated_sharpe 1.0000))))
   ((label bundle-1e6-5e5)
    (config_hash overlay-bundle-364basis)
    (aggregate
     ((sharpe_mean 0.609) (calmar_mean 0.802) (maxdd_mean 17.69)
      (return_mean 0.0) (pareto_frontier no) (deflated_sharpe 1.0000))))))
 (verdict Reject)
 (notes
  "Reject(promotion) — gate FAIL all armed variants (worst_delta 0 spec; hold-only 8/13 Sharpe wins but fold-008 2016-18 trails 0.96: that window's monster was a low-ADV name = the tail-tax exhibit). DECOMPOSITION INVERTS the single-path bundle story (3rd path-vs-fold inversion this week after armon + catstop): HOLD-DEGRADATION EXIT ALONE dominates baseline on every aggregate (Sharpe .654->.753, Calmar .917->1.131, MaxDD 23.6->18.0, DSR .9999, 8/13) = strongest fold-level candidate produced yet — recycling capital out of liquidity-dying names is distributed real improvement. ENTRY GATE alone REDUCES Sharpe/Calmar (forgoes more winners than fakes at fold level; estimand caveat: the simulator credits untradeable fake profit as alpha, so part of the gate's measured cost is fake profit foregone — WF metric cannot arbitrate realizability). Bundle worse than hold-only. Parity cell bit-identical 13/13 (nested 2-axis Cartesian validated). FORWARD: hold-exit promotion path = neighbor surface {2.5e5,5e5,1e6} + macro-regime-diverse confirmation grid + fold-008 realizability argument. Honest-tradeable record run KEEPS the bundle as measurement convention (realism), explicitly not an alpha claim. Artifacts: dev/backtest/liquidity-overlay-wfcv-2026-07-10/. 364 basis. Ops: v1 died artifact-less to container contention (runner writes only at end) — long WF runs get a solo container.")
 )
