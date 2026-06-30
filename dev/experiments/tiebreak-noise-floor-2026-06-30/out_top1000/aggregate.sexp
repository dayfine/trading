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
   ((variant_label reverse_alpha)
    (total_return_pct
     ((mean 15.487031563880958) (stdev 12.724616085715454)
      (min -4.7992380100000185) (max 41.851533220000007)))
    (sharpe_ratio
     ((mean 0.58861133429564494) (stdev 0.43822974271738413)
      (min -0.084541472369672091) (max 1.5470024144171746)))
    (max_drawdown_pct
     ((mean 16.070373670998375) (stdev 5.8131127612109577)
      (min 9.56113506359906) (max 28.641123182327405)))
    (calmar_ratio
     ((mean 0.57352954867477379) (stdev 0.56648694937635513)
      (min -0.084984762205048983) (max 2.0023028141659456)))
    (cagr_pct
     ((mean 7.3211570403472308) (stdev 5.8929377841002291)
      (min -2.430765572954019) (max 19.115702145487589)))
    (avg_holding_days
     ((mean 40.572643876519479) (stdev 6.9010945693335835)
      (min 26.166666666666668) (max 51.628205128205131))))
   ((variant_label symbol_length)
    (total_return_pct
     ((mean 11.438343110058169) (stdev 17.793895722699165)
      (min -13.138448660000051) (max 51.778454650000015)))
    (sharpe_ratio
     ((mean 0.4223232223346936) (stdev 0.52384127900834265)
      (min -0.4561655908524106) (max 1.1581986637596966)))
    (max_drawdown_pct
     ((mean 17.825416733472004) (stdev 7.475155368541361)
      (min 7.6293512553192482) (max 28.951641420000033)))
    (calmar_ratio
     ((mean 0.47823610998552468) (stdev 0.6310208898573596)
      (min -0.23535660615478252) (max 1.7166509661640703)))
    (cagr_pct
     ((mean 5.2693702174292119) (stdev 8.2684401442401239)
      (min -6.8049509336815639) (max 23.216004415204281)))
    (avg_holding_days
     ((mean 38.017217730502807) (stdev 8.27832417619733)
      (min 22.972222222222221) (max 53.930555555555557))))
   ((variant_label hash_random)
    (total_return_pct
     ((mean 11.438343110058169) (stdev 17.793895722699165)
      (min -13.138448660000051) (max 51.778454650000015)))
    (sharpe_ratio
     ((mean 0.4223232223346936) (stdev 0.52384127900834265)
      (min -0.4561655908524106) (max 1.1581986637596966)))
    (max_drawdown_pct
     ((mean 17.825416733472004) (stdev 7.475155368541361)
      (min 7.6293512553192482) (max 28.951641420000033)))
    (calmar_ratio
     ((mean 0.47823610998552468) (stdev 0.6310208898573596)
      (min -0.23535660615478252) (max 1.7166509661640703)))
    (cagr_pct
     ((mean 5.2693702174292119) (stdev 8.2684401442401239)
      (min -6.8049509336815639) (max 23.216004415204281)))
    (avg_holding_days
     ((mean 38.017217730502807) (stdev 8.27832417619733)
      (min 22.972222222222221) (max 53.930555555555557))))))
 (sensitivity
  (((variant_label reverse_alpha) (sharpe_wins 5) (calmar_wins 6)
    (total_return_wins 4) (max_drawdown_wins 9))
   ((variant_label symbol_length) (sharpe_wins 4) (calmar_wins 3)
    (total_return_wins 2) (max_drawdown_wins 4))
   ((variant_label hash_random) (sharpe_wins 4) (calmar_wins 3)
    (total_return_wins 2) (max_drawdown_wins 4))))
 (verdicts
  ((reverse_alpha
    (Fail (wins 5) (n 13) (worst_fold fold-007)
     (worst_gap 0.8234262922458645)
     (reason
      "M-threshold miss: 5 wins < 7 required; worst fold fold-007 trails by 0.8234 > \206\148=0.3000")))
   (symbol_length
    (Fail (wins 4) (n 13) (worst_fold fold-000)
     (worst_gap 1.0268229283135026)
     (reason
      "M-threshold miss: 4 wins < 7 required; worst fold fold-000 trails by 1.0268 > \206\148=0.3000")))
   (hash_random
    (Fail (wins 4) (n 13) (worst_fold fold-000)
     (worst_gap 1.0268229283135026)
     (reason
      "M-threshold miss: 4 wins < 7 required; worst fold fold-000 trails by 1.0268 > \206\148=0.3000"))))))
