((date 2026-06-22)
 (slug slow-grind-adlive-wfcv)
 (hypothesis
  "enable_slow_grind_short_gate=true holds the A-D-live deep-screen best-Calmar/best-DD result across rolling OOS folds (now that Build 0 made the decline-character A-D-lead leg live)")
 (base_scenario "goldens-sp500-historical/sp500-2000-2026-longshort.sexp")
 (window_id wfcv-adlive-deep-2000-2026-26fold)
 (baseline_label baseline)
 (variants
  (((label enable_slow_grind_short_gate=true)
    (config_hash slowgrind-true-adlive-deep-2000-2026)
    (aggregate ((sharpe_mean 0.612) (calmar_mean 1.064) (maxdd_mean 10.61) (return_mean 9.18) (pareto_frontier yes) (deflated_sharpe 0.9999))))))
 (verdict Reject)
 (notes
  "NO promote (A-D-live basis). See dev/backtest/slow-grind-adlive-wfcv-2026-06-22/. Across 26 folds true is LOWER on Sharpe (0.612 vs 0.661) AND Calmar (1.064 vs 1.152), only marginally better on raw per-fold MaxDD (10.61 vs 10.93). The single-window deep-screen best-Calmar (0.745) was a CUMULATIVE multi-year-drawdown artifact that washes out per-fold. Per-fold genuinely MIXED (22/26 differ): wins 2020 +5.1/2003 +6.6/2014 +4.9, losses 2002 -10.6/2025 -9.7/2016 -9.1/2009 -7.6 (gated shorts admitted late in a decline get squeezed at the 2002/2009 BOTTOMS). Net -0.94pp return = regime-dependent, same pattern as every short mechanism this session. A-D-live MUCH improved it vs A-D-inert (-108pp tax -> near-wash) but not to promotable. Stays default-off axis. THE REAL Build-0 payoff is BROAD: A-D-live lifts the whole strategy (long-only +92pp, macro entry gate sharper) -> argues for A-D-live as DEFAULT BASIS independent of any short gate. Third time WF-CV corrected a single-window screen (cf arming-speed, neutral-grid).")
 )
