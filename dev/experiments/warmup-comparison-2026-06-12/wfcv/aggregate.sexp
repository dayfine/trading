((fold_count 22) (baseline_label baseline) (metric_label Sharpe)
 (stability
  (((variant_label baseline)
    (total_return_pct
     ((mean 16.775908814090897) (stdev 24.811052307661463)
      (min -25.906155109999968) (max 54.866047510000037)))
    (sharpe_ratio
     ((mean 0.37205665626330442) (stdev 1.0653872123458774)
      (min -2.3899174745290237) (max 2.0509390557819764)))
    (max_drawdown_pct
     ((mean 16.490182077862809) (stdev 6.5321707936732638)
      (min 5.1351647760413659) (max 29.586596910466351)))
    (calmar_ratio
     ((mean 0.95471759159391667) (stdev 1.803275327679112)
      (min -0.83387791576770909) (max 6.7579496002986117)))
    (cagr_pct
     ((mean 16.790094509624645) (stdev 24.829991735307317)
      (min -25.921370074781713) (max 54.912449607103639)))
    (avg_holding_days
     ((mean 34.648680371691505) (stdev 10.568894322924569)
      (min 22.196078431372548) (max 58.05))))
   ((variant_label suppress_warmup_trading=true)
    (total_return_pct
     ((mean 6.8227468186363645) (stdev 17.138426863755278)
      (min -16.131358339999988) (max 45.293553110000026)))
    (sharpe_ratio
     ((mean 0.25239768116598182) (stdev 1.0064454101137863)
      (min -1.8682718678019994) (max 2.3175350006842557)))
    (max_drawdown_pct
     ((mean 16.014389721465264) (stdev 4.7091834757337381)
      (min 8.7237896912551989) (max 25.110763287731942)))
    (calmar_ratio
     ((mean 0.63988890527818121) (stdev 1.3506650943235121)
      (min -0.98429425592197828) (max 4.387105312212495)))
    (cagr_pct
     ((mean 6.8284505818859023) (stdev 17.151481799605421)
      (min -16.141463236226173) (max 45.330735702145034)))
    (avg_holding_days
     ((mean 33.119498784754292) (stdev 8.50402474101724)
      (min 19.349206349206348) (max 50.25))))))
 (sensitivity
  (((variant_label suppress_warmup_trading=true) (sharpe_wins 9)
    (calmar_wins 9) (total_return_wins 7) (max_drawdown_wins 13))))
 (verdicts
  ((suppress_warmup_trading=true
    (Fail (wins 9) (n 22) (worst_fold fold-002)
     (worst_gap 1.4414661702552294)
     (reason
      "M-threshold miss: 9 wins < 11 required; worst fold fold-002 trails by 1.4415 > \206\148=0.3000"))))))
