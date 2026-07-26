((date 2026-07-19) (slug virgin-crossing-flag-surface)
 (hypothesis
  "resistance-v2 lever (a): virgin_crossing_readmission (#1997 + #2002 hist-empty fix) re-admits stale Stage-2 names that cross into supply-clear high ground; 28y single-path showed vc-only $88.2M vs baseline $80.1M (+10% terminal, equal Sharpe, lower DD); does the edge survive fold-level WF-CV on the record-convention base (supply weight NOT armed - flag isolated)?")
 (base_scenario
  "staging-record-convention/top3000-2000-2026-record-convention (dedup-v3 sketch warehouse, deep-feed armed, PIT top-3000)")
 (window_id wf-2000-2026-730-730-13fold-top3000-snapshot-dedup-v3-sketch)
 (baseline_label baseline)
 (variants
  (((label baseline) (config_hash "")
    (aggregate
     (((mean_sharpe 0.691) (mean_calmar 0.921) (mean_return_pct 31.74)
       (mean_max_drawdown_pct 16.57)))))
   ((label virgin_crossing_readmission=true) (config_hash "")
    (aggregate
     (((mean_sharpe 0.695) (mean_calmar 0.921) (mean_return_pct 32.25)
       (mean_max_drawdown_pct 16.61)))))))
 (verdict Reject)
 (notes
  "Gate FAIL 2/13 Sharpe wins (need 7); worst fold-011 trails by 0.0343. THE WHY: the lever is INERT at fold granularity - 9/13 folds bit-identical to baseline (zero firings; a 2y fold reset rarely completes the setup: Stage-2 transition >4wk ago THEN a supply-clear crossing THEN capacity to fund). Where it fired: fold-010 2020-22 clearly better (+5.6pp return, Sharpe 1.686->1.730), fold-012 better (+2pp, +0.035), fold-011 slightly worse (-1pp, -0.034), fold-009 noise. The 28y +10% was contiguous-path compounding of rare re-admissions (some spanning fold boundaries) - exactly the evidence class promotion-confirmation.md treats as non-decision-grade. TRANSFERABLE GUIDANCE: (1) fold-reset WF-CV structurally under-powers rare long-memory admission levers; a mechanism whose setup takes >6mo needs contiguous-window or rolling-start evidence, not 2y folds; (2) the lever's real role is as ENABLER under w_overhead_supply arming (supply demotion creates the stale-clear cohort) - tested separately in the floor-axis surface (same date); (3) standalone, keep default-off axis; no promotion path absent a pairing result. Report /tmp/sweeps/vc-flag-broad + .sweep-output/vc-flag-broad/walk_forward_report.md; spec test_data/walk_forward/virgin-crossing-flag-BROAD-2000-2026.sexp (merged #2004)."))
