((fold_count 13) (baseline_label baseline) (metric_label Sharpe)
 (stability
  (((variant_label baseline)
    (total_return_pct
     ((mean 19.918805991794873) (stdev 20.552697389865784)
      (min -10.199166533333331) (max 71.993923839999979)))
    (sharpe_ratio
     ((mean 0.5968746113084944) (stdev 0.49408679374788878)
      (min -0.4213376555946925) (max 1.2963294973210586)))
    (max_drawdown_pct
     ((mean 15.357873569718073) (stdev 4.7373143310461954)
      (min 8.8999857341691513) (max 24.754721911378184)))
    (calmar_ratio
     ((mean 0.68270632982270452) (stdev 0.59647308213233163)
      (min -0.221983542682911) (max 1.6920034601780185)))
    (cagr_pct
     ((mean 9.1647918270166837) (stdev 9.10521112370989)
      (min -5.2401894300441505) (max 31.170812129033166)))
    (avg_holding_days
     ((mean 44.399331599752557) (stdev 9.32544055982073)
      (min 33.333333333333336) (max 62.584905660377359))))
   ((variant_label cont_add)
    (total_return_pct
     ((mean 19.229263059487181) (stdev 22.485791406612893)
      (min -6.9902005133333267) (max 82.646292839999987)))
    (sharpe_ratio
     ((mean 0.56715789521075977) (stdev 0.45480719374510953)
      (min -0.2509356210321288) (max 1.4132340936701673)))
    (max_drawdown_pct
     ((mean 15.65992422435664) (stdev 4.9867041262423566)
      (min 8.8999857341691513) (max 27.029020324814013)))
    (calmar_ratio
     ((mean 0.61361425968876193) (stdev 0.56483252666162553)
      (min -0.15282338611592175) (max 1.90937766832813)))
    (cagr_pct
     ((mean 8.8021554838435) (stdev 9.68460397092224)
      (min -3.5608050776311906) (max 35.1745783813963)))
    (avg_holding_days
     ((mean 44.555892880872157) (stdev 9.7259749920317269)
      (min 33.333333333333336) (max 62.584905660377359))))
   ((variant_label cont_add_tight)
    (total_return_pct
     ((mean 19.115079434102562) (stdev 20.147324280397218)
      (min -12.29323415333333) (max 71.993923839999979)))
    (sharpe_ratio
     ((mean 0.56647831564507278) (stdev 0.46798648340552412)
      (min -0.50876923848963629) (max 1.2963294973210586)))
    (max_drawdown_pct
     ((mean 15.203580916985509) (stdev 4.2080269122652414)
      (min 8.8999857341691513) (max 23.400835125604797)))
    (calmar_ratio
     ((mean 0.62538249253148936) (stdev 0.52453477669748039)
      (min -0.271817093787862) (max 1.6920034601780185)))
    (cagr_pct
     ((mean 8.81072129293761) (stdev 8.9089787331939476)
      (min -6.3523164515405073) (max 31.170812129033166)))
    (avg_holding_days
     ((mean 44.662094330099066) (stdev 9.6082327312450388)
      (min 33.333333333333336) (max 62.584905660377359))))
   ((variant_label cont_add_vol)
    (total_return_pct
     ((mean 20.231186017179486) (stdev 22.858266083431609)
      (min -9.3261881333333321) (max 82.646292839999987)))
    (sharpe_ratio
     ((mean 0.59454289794177473) (stdev 0.501565404050918)
      (min -0.37781558170051921) (max 1.4132340936701673)))
    (max_drawdown_pct
     ((mean 15.649971351480625) (stdev 4.9702184367787892)
      (min 8.8999857341691513) (max 27.029020324814013)))
    (calmar_ratio
     ((mean 0.6697448353539085) (stdev 0.62929825509556991)
      (min -0.20630834134993423) (max 1.90937766832813)))
    (cagr_pct
     ((mean 9.2437114287960327) (stdev 9.9057257597658275)
      (min -4.7803949508967492) (max 35.1745783813963)))
    (avg_holding_days
     ((mean 44.452835515121293) (stdev 9.2291478937265534)
      (min 33.333333333333336) (max 62.584905660377359))))))
 (sensitivity
  (((variant_label cont_add) (sharpe_wins 4) (calmar_wins 4)
    (total_return_wins 4) (max_drawdown_wins 2))
   ((variant_label cont_add_tight) (sharpe_wins 3) (calmar_wins 2)
    (total_return_wins 3) (max_drawdown_wins 2))
   ((variant_label cont_add_vol) (sharpe_wins 4) (calmar_wins 4)
    (total_return_wins 4) (max_drawdown_wins 2))))
 (verdicts
  ((cont_add
    (Fail (wins 4) (n 13) (worst_fold fold-007)
     (worst_gap 0.49732993450048546)
     (reason
      "M-threshold miss: 4 wins < 7 required; worst fold fold-007 trails by 0.4973 > \206\148=0.3000")))
   (cont_add_tight
    (Fail (wins 3) (n 13) (worst_fold fold-007)
     (worst_gap 0.49732993450048546)
     (reason
      "M-threshold miss: 3 wins < 7 required; worst fold fold-007 trails by 0.4973 > \206\148=0.3000")))
   (cont_add_vol
    (Fail (wins 4) (n 13) (worst_fold fold-009)
     (worst_gap 0.17174494109092825)
     (reason "M-threshold miss: 4 wins < 7 required"))))))
