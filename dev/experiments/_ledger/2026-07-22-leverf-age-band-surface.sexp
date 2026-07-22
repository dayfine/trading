((date 2026-07-22) (slug leverf-age-band-surface)
 (hypothesis
  "Lever (f), age-banded overhead supply (sketch v5, #2015/#2026-#2038): supply should decay with AGE (old bag-holders capitulate), so weighting the measured 130-520w band above 0 -- and/or decaying the within-130w bands -- should improve the BUNDLE (w_overhead_supply=30 + virgin_crossing_readmission + floors 0/0/0) on the home broad grid, and resolve the floors' regime-dependence seen in the 2011 grid cell.")
 (base_scenario
  "broad: staging-record-convention/top3000-2000-2026-record-convention on /tmp/snap_top3000_dedup_v5thin (13-col + weekly side-tables, v5 read path); sp500: goldens-sp500-historical/sp500-2000-2026-catstop on snap_sp500_2000_2026_v4_sketch (w15 basis)")
 (window_id leverf-broad-13x2y-2000-2026+sp500-26x1y)
 (baseline_label baseline)
 (variants
  (((label "bundle ref (bands 1/1/1/0)") (config_hash "")
    (aggregate
     (((mean_sharpe 0.827) (mean_calmar 1.309) (mean_return_pct 36.17)
       (mean_max_drawdown_pct 14.05)))))
   ((label "old-band 0.25") (config_hash "")
    (aggregate
     (((mean_sharpe 0.766) (mean_calmar 1.092) (mean_return_pct 34.63)
       (mean_max_drawdown_pct 16.22)))))
   ((label "old-band 0.5") (config_hash "")
    (aggregate
     (((mean_sharpe 0.708) (mean_calmar 1.104) (mean_return_pct 28.89)
       (mean_max_drawdown_pct 14.55)))))
   ((label "age-decay 1/.7/.5/.25") (config_hash "")
    (aggregate
     (((mean_sharpe 0.755) (mean_calmar 1.080) (mean_return_pct 32.04)
       (mean_max_drawdown_pct 14.49)))))
   ((label baseline) (config_hash "")
    (aggregate
     (((mean_sharpe 0.691) (mean_calmar 0.921) (mean_return_pct 31.74)
       (mean_max_drawdown_pct 16.57)))))))
 (verdict Reject)
 (notes
  "REJECT the age lever; KEEP default band weights 1/1/1/0 (bit-identical to the age-blind <=130w semantics). Broad home grid (13x2y, the decision basis): ANY weight on the measured 130-520w band harms MONOTONICALLY (Sharpe .827 -> .766 @0.25 -> .708 @0.5; Sharpe wins 10/13 -> 8 -> 7), and within-recent age decay also loses (.755). sp500 cell (26x1y, w15): U-SHAPED (.737 -> .658 @0.25 -> .774 @0.5 -> .677 decay) -- the 0.5 'peak' does not transfer to broad (opposite sign), confirming it as noise (floors-half precedent; breadth-dependence lesson). WHY, decomposed: the floors-zero result already showed trust-measured-EMPTY beats max-based skepticism; (f) now shows measured-OLD mass carries no pricing power -- 2.5-10y bag-holders do not suppress broad breakouts, so weighting them only demotes otherwise-good candidates (same cohort-tax shape as the floors, weaker). Forward guidance: the age axis is closed; the bundle's 2011-cell regression will NOT be rescued by age-banding -- remaining option space for that cell is the regime-softener (lever b) or accepting the bull-era wash. CRITICAL INFRA BYPRODUCT (the lasting win): the bands-1/1/1/0 row reproduces the 07-19 dense-era floor-axis bundle row TO EVERY PRINTED DECIMAL (.827/36.17/14.05) ON THE SPARSE v5thin WAREHOUSE -- full-scale production cert of the v5 storage chain (#2026/#2027/#2032/#2038; 1.3G vs 8.4G, 11min/fold vs thrash-unrunnable). Reports /tmp/sweeps/leverf-broad-final + /tmp/sweeps/leverf-sp500; specs test_data/walk_forward/leverf-band-weight-{BROAD,SP500}-2000-2026.sexp."))
