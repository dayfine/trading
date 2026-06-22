((date 2026-06-22)
 (slug arming-speed-wfcv)
 (hypothesis
  "fast_v_arm_on_rate_alone=true (arm the Fast_v catastrophic stop on rate-of-decline alone, dropping the falling-MA precondition) improves risk-adjusted return by catching fast-V crashes before the structural gap-down, without taxing normal regimes")
 (base_scenario "goldens-sp500-historical/sp500-2000-2026-catstop.sexp")
 (window_id wfcv-deep-2000-2026-26fold)
 (baseline_label baseline)
 (variants
  (((label fast_v_arm_on_rate_alone=true)
    (config_hash arm-on-rate-true-catstop10-deep-2000-2026)
    (aggregate
     ((sharpe_mean 0.699) (calmar_mean 1.348) (maxdd_mean 10.60)
      (return_mean 11.52) (pareto_frontier yes) (deflated_sharpe 1.0000))))))
 (verdict Accept)
 (notes
  "Single-cell ACCEPT (weak, frontier-dominant), NOT a default flip. See dev/backtest/arming-speed-wfcv-2026-06-22/. true is the sole Pareto-frontier member (dominates baseline Sharpe/Calmar/MaxDD) but the aggregate edge is small (+0.004 Sharpe); it differs in only 4/26 folds: WINS the fast-V crashes (2020 fold-020 +3.0pp/MaxDD 18.6->16.3; 2018-Q4 fold-018 +1.2pp), WHIPSAWS choppy corrections (2010 -0.77pp, 2011 -1.2pp), and is INERT in the 2008 slow cascade (fold-008 byte-identical) + 2022 grind. KEY why: the knob is fast-V-specific insurance, NOT a slow-bear tool (2008 was a cascade) -> confirms the Decline_character Fast_v/Slow_grind split is real. The 2-window screen (build2-arming-speed-screen) OVER-CLAIMED 'dormant-or-helpful'; WF-CV reveals the whipsaw cost in chop. NEXT: expose fast_v_min_rate_pct as a strategy config field, run a {0.08,0.12,0.16} SURFACE to suppress the 2010/2011 whipsaw, then confirmation grid. Built #1708. Tail-RISK insurance, not winner-touching (inert 24/26).")
 )
