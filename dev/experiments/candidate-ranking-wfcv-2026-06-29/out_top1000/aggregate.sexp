((fold_count 13) (baseline_label baseline) (metric_label Sharpe)
 (stability
  (((variant_label baseline)
    (total_return_pct
     ((mean 18.680197139009994) (stdev 15.498365883847747)
      (min -10.566911530000018) (max 44.891070100000015)))
    (sharpe_ratio
     ((mean 0.65991737303695186) (stdev 0.46152919196105263)
      (min -0.28120514732215168) (max 1.3387646578306376)))
    (max_drawdown_pct
     ((mean 17.285633572098536) (stdev 6.8868665426161462)
      (min 7.1104389779935664) (max 33.09186315996385)))
    (calmar_ratio
     ((mean 0.68981005350821922) (stdev 0.60032165053786979)
      (min -0.1644451333118771) (max 1.7467068933356698)))
    (cagr_pct
     ((mean 8.7298776132178624) (stdev 7.1575792245641647)
      (min -5.4345476686662675) (max 20.385993508371246)))
    (avg_holding_days
     ((mean 39.331304896261251) (stdev 7.2721806235739876)
      (min 24.555555555555557) (max 49.860759493670884))))
   ((variant_label quality_ranking)
    (total_return_pct
     ((mean 17.709006756251302) (stdev 10.213864732302973)
      (min 4.2313274800000018) (max 41.786329)))
    (sharpe_ratio
     ((mean 0.66607496708821212) (stdev 0.3504337454112661)
      (min 0.22682903676335076) (max 1.4783773631049646)))
    (max_drawdown_pct
     ((mean 15.165352070814064) (stdev 5.0122749966501265)
      (min 7.8284100365386546) (max 23.0854316464154)))
    (calmar_ratio
     ((mean 0.66853446055865484) (stdev 0.52857440911128117)
      (min 0.093082655832856867) (max 2.0530747023850884)))
    (cagr_pct
     ((mean 8.4082558550527189) (stdev 4.6422564970024123)
      (min 2.0951938927804115) (max 19.088303573291654)))
    (avg_holding_days
     ((mean 39.821584279934605) (stdev 7.4677765149186746)
      (min 28.896551724137932) (max 51.532467532467535))))))
 (sensitivity
  (((variant_label quality_ranking) (sharpe_wins 6) (calmar_wins 6)
    (total_return_wins 5) (max_drawdown_wins 7))))
 (verdicts
  ((quality_ranking
    (Fail (wins 6) (n 13) (worst_fold fold-010)
     (worst_gap 0.66815673884378213)
     (reason
      "M-threshold miss: 6 wins < 7 required; worst fold fold-010 trails by 0.6682 > \206\148=0.3000"))))))
