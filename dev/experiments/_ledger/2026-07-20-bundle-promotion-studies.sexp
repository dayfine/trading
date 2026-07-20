((date 2026-07-20) (slug bundle-promotion-studies)
 (hypothesis
  "Promotion memo 2026-07-19 option B: the BUNDLE (w_overhead_supply=30 + virgin_crossing_readmission + floors 0/0/0) generalizes across a confirmation grid (sp500 cell, broad 2011-26 cell) AND repairs bare-w30's recovery-window left tail (2000/2008/2010 rolling starts, -5.8..-8.5 pp/yr forfeits) -- the motivating design goal of the vc + floors-zero levers.")
 (base_scenario
  "sp500 cell: catstop-golden base, 26x1y 2000-2026, snap_sp500_2000_2026_v3_sketch; 2011 cell: record convention, 7x2y 2011-2026, dedup-v3 sketch; rolling-start: staging-rolling-start/top3000-2000-2026-rc-bundle.sexp, stride-730, n=12 counted starts, paired vs .sweep-output/rolling-start-promo/{baseline,w30}.md")
 (window_id bundle-grid-sp500-26x1y+broad-2011-7x2y+rolling-start-730)
 (baseline_label baseline)
 (variants
  (((label "sp500 bundle-w15") (config_hash "")
    (aggregate
     (((mean_sharpe 0.737) (mean_calmar 1.539) (mean_return_pct 13.89)
       (mean_max_drawdown_pct 9.99)))))
   ((label "sp500 bundle-w30") (config_hash "")
    (aggregate
     (((mean_sharpe 0.570) (mean_calmar 1.211) (mean_return_pct 9.73)
       (mean_max_drawdown_pct 9.70)))))
   ((label "sp500 baseline") (config_hash "")
    (aggregate
     (((mean_sharpe 0.396) (mean_calmar 0.938) (mean_return_pct 6.32)
       (mean_max_drawdown_pct 10.57)))))
   ((label "2011 bundle-w30") (config_hash "")
    (aggregate
     (((mean_sharpe 0.599) (mean_calmar 0.773) (mean_return_pct 20.91)
       (mean_max_drawdown_pct 17.95)))))
   ((label "2011 baseline") (config_hash "")
    (aggregate
     (((mean_sharpe 0.619) (mean_calmar 0.845) (mean_return_pct 23.69)
       (mean_max_drawdown_pct 16.56)))))))
 (verdict Inconclusive)
 (notes
  "GRID SPLIT + TAIL REPAIR. Cell 1 sp500 CONFIRM: bundle-w15 Sharpe .737 (19/26 wins) / bundle-w30 .570 (16/26, best MaxDD) vs .396 -- BOTH beat the 07-17 w-only cell (.623/.552), so vc+floors-zero add on narrow breadth. Cell 2 broad-2011 REGRESS-to-wash: bundle-w30 .599 +/- .674 (4/7) vs baseline .619 -- and far below w-only's .825 +/- .223 on the same cell; adding vc+floors-zero destroyed that cell's alpha AND stability (sigma .223 -> .674). The floor staircase is regime-dependent: value on bull-era broad (suppresses the re-admitted stale cohort), tax across 2000-2026 (prices out the redeemed monsters). Cell 3 rolling-start = THE DECISIVE READ and answers the motivating question YES: recovery-window starts repair from w30's -5.84/-6.68/-8.54 pp/yr to +0.41/+0.16/-1.92 vs baseline; bundle beats baseline 9/12 starts, median +2.08 pp/yr, worst -1.92; worst-start realized edge vs index +7.79% (baseline +6.35%, bare w30 -1.27% incl one index loss); MaxDD median 28.76 / worst 30.99 vs baseline 32.2/40.5 -- DD compression kept, worst path better than bare w30 (33.9). Cost vs bare w30: mid-bull give-back (2016 -2.91, 2022 -2.53 pp/yr) -- the 2011-cell effect path-wise. Verdict recorded Inconclusive because promotion-confirmation.md's unanimous-grid standard is not met (2011 cell); the human gate (R3) decides among: (A) promote the BUNDLE as one unit -- recommended on the rolling-start dominance + best-of-all edge floor; (B) keep axes, wait for lever (f) age-banded surfaces (v4 rebuild) to resolve the floors' regime-dependence; (C) bare w30 -- not recommended (known 6-9pp recovery forfeits, negative edge floor). Full note dev/notes/bundle-studies-results-2026-07-20.md."))
