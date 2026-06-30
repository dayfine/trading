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
   ((variant_label hash_random)
    (total_return_pct
     ((mean 9.61209355515837) (stdev 14.000877611124743)
      (min -13.652075800000027) (max 38.46428646)))
    (sharpe_ratio
     ((mean 0.38788176481280251) (stdev 0.45008914384709331)
      (min -0.38014056386556266) (max 1.1112228335831289)))
    (max_drawdown_pct
     ((mean 17.218215123867665) (stdev 6.6116829444454819)
      (min 8.5813811393002979) (max 31.221897460000029)))
    (calmar_ratio
     ((mean 0.40484064330378366) (stdev 0.56575305893730343)
      (min -0.22709855886651079) (max 1.5588614238786835)))
    (cagr_pct
     ((mean 4.5057290901437659) (stdev 6.6243739748452466)
      (min -7.0810872899034987) (max 17.683964231225445)))
    (avg_holding_days
     ((mean 39.418509587554077) (stdev 6.8125904554396808)
      (min 26.323076923076922) (max 47.860465116279073))))))
 (sensitivity
  (((variant_label hash_random) (sharpe_wins 3) (calmar_wins 4)
    (total_return_wins 3) (max_drawdown_wins 8))))
 (verdicts
  ((hash_random
    (Fail (wins 3) (n 13) (worst_fold fold-002)
     (worst_gap 0.9895535342977948)
     (reason
      "M-threshold miss: 3 wins < 7 required; worst fold fold-002 trails by 0.9896 > \206\148=0.3000"))))))
