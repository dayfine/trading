((date 2026-07-19) (slug supply-floor-axis-surface)
 (hypothesis
  "resistance-v2 lever (c) widened: the horizon floors (recent_far 0.4 / stale_mid 0.25 / stale_old 0.1) -- max-based skepticism applied even when the 130w histogram is fully sighted and EMPTY -- are what price redeemed monsters out of the cap-20 race under w_overhead_supply=30 (AXTI Jan-26: hist empty, floor 0.4 -> 18/30 points). Softening/zeroing the floors under the w30+vc pairing should recover the forfeited return while keeping the DD compression.")
 (base_scenario
  "staging-record-convention/top3000-2000-2026-record-convention (dedup-v3 sketch warehouse, deep-feed armed, PIT top-3000)")
 (window_id wf-2000-2026-730-730-13fold-top3000-snapshot-dedup-v3-sketch)
 (baseline_label baseline)
 (variants
  (((label baseline) (config_hash "")
    (aggregate
     (((mean_sharpe 0.691) (mean_calmar 0.921) (mean_return_pct 31.74)
       (mean_max_drawdown_pct 16.57)))))
   ((label "w30+vc floors=0.4/0.25/0.1") (config_hash "")
    (aggregate
     (((mean_sharpe 0.831) (mean_calmar 1.252) (mean_return_pct 30.94)
       (mean_max_drawdown_pct 13.98)))))
   ((label "w30+vc floors=0.2/0.125/0.05") (config_hash "")
    (aggregate
     (((mean_sharpe 0.777) (mean_calmar 1.042) (mean_return_pct 30.82)
       (mean_max_drawdown_pct 14.82)))))
   ((label "w30+vc floors=0/0/0") (config_hash "")
    (aggregate
     (((mean_sharpe 0.827) (mean_calmar 1.309) (mean_return_pct 36.17)
       (mean_max_drawdown_pct 14.05)))))))
 (verdict Inconclusive)
 (notes
  "DIAGNOSIS CONFIRMED at fold level: floors-zero recovers the return deficit (+5.2pp vs floors-full, +4.4pp vs baseline; Sharpe wins 7->10 of 13) while keeping the DD compression (14.05 vs 16.57) -- the horizon-floor staircase WAS the redeemed-cohort tax; trusting measured (sighted-and-empty) histogram mass beats max-based skepticism. Non-monotone middle (floors-half worst of three on Sharpe) = the staircase's harm is threshold-shaped, not linear. Binary gate FAIL on all three via the zero-tolerance worst-fold rule (floors-full worst fold-007 -0.44; floors-zero worst fold-009 -0.36; note the bad fold MOVES with the floor value -- the mechanisms trade different regimes), same technical-FAIL shape every accepted mechanism showed pre-grid. Honest comparison: plain w30 (no vc, floors full; 07-16 surface) still holds best mean Sharpe 0.860 vs bundle's 0.827-0.831 -- the bundle trades ~0.03 Sharpe for +3pp return (the monster cohort) and equal DD. PROMOTION CANDIDATE = the BUNDLE (w30 + virgin_crossing_readmission + floors 0/0/0), NOT bare w30: single home cell only, so per promotion-confirmation.md it needs (a) the bundle confirmation grid (sp500 cell with breadth-adapted weight, 2011-26 period cell) and (b) the bundle rolling-start distribution verifying the recovery-window paths (2000/2008/2010 starts) actually repair -- the motivating question. Lever (f) gate signal: moderate -- zero-floor dominance says measured mass > max skepticism, which age-banding would refine, but defer until the bundle grid. Report /tmp/sweeps/floor-axis + .sweep-output/floor-axis/walk_forward_report.md; spec test_data/walk_forward/supply-floor-axis-BROAD-2000-2026.sexp (merged #2004)."))
