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
   ((variant_label earliness_ranking)
    (total_return_pct
     ((mean 15.697237954253383) (stdev 11.217908460401276)
      (min -5.6543780500000462) (max 32.197524880000017)))
    (sharpe_ratio
     ((mean 0.58965349691892144) (stdev 0.36696120819719658)
      (min -0.15493692807869916) (max 0.97354011001282337)))
    (max_drawdown_pct
     ((mean 16.087760058654343) (stdev 5.2949554062835169)
      (min 8.0637685539111068) (max 22.750033400578857)))
    (calmar_ratio
     ((mean 0.5863508674781065) (stdev 0.47366531208237328)
      (min -0.12633571546164604) (max 1.4452621970523536)))
    (cagr_pct
     ((mean 7.4461976610964467) (stdev 5.3305773084244965)
      (min -2.8702616185258933) (max 14.988173827102003)))
    (avg_holding_days
     ((mean 39.53919888155194) (stdev 8.1099665923187629)
      (min 22.671052631578949) (max 51.875))))))
 (sensitivity
  (((variant_label earliness_ranking) (sharpe_wins 6) (calmar_wins 5)
    (total_return_wins 6) (max_drawdown_wins 5))))
 (verdicts
  ((earliness_ranking
    (Fail (wins 6) (n 13) (worst_fold fold-002)
     (worst_gap 0.59765338545539182)
     (reason
      "M-threshold miss: 6 wins < 7 required; worst fold fold-002 trails by 0.5977 > \206\148=0.3000"))))))
