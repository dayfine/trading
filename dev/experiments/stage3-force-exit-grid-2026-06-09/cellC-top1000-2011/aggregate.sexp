((fold_count 15) (baseline_label baseline) (metric_label Sharpe)
 (stability
  (((variant_label force_exit_off)
    (total_return_pct
     ((mean 10.027909100488893) (stdev 23.382841526873079)
      (min -26.728796810000006) (max 56.14341739)))
    (sharpe_ratio
     ((mean 0.39447715529364852) (stdev 0.7999511883308289)
      (min -1.6990176635178871) (max 1.7005382692916065)))
    (max_drawdown_pct
     ((mean 18.260186253431485) (stdev 14.298264989302618)
      (min 6.689225863250198) (max 60.451865990954815)))
    (calmar_ratio
     ((mean 0.71075311628189286) (stdev 1.1500332586421396)
      (min -0.91999618334122424) (max 4.0426810406361806)))
    (cagr_pct
     ((mean 10.036712453036108) (stdev 23.400339812860821)
      (min -26.744403044050415) (max 56.191080996928555)))
    (avg_holding_days
     ((mean 34.570019007661308) (stdev 11.604103395711469) (min 11.8)
      (max 53.365384615384613))))
   ((variant_label baseline)
    (total_return_pct
     ((mean 10.044878216488893) (stdev 23.324641884910776)
      (min -26.728796810000006) (max 56.14341739)))
    (sharpe_ratio
     ((mean 0.41761141111846156) (stdev 0.80741243419979913)
      (min -1.6990176635178871) (max 1.7005382692916065)))
    (max_drawdown_pct
     ((mean 18.684713386767182) (stdev 14.099762338603014)
      (min 6.689225863250198) (max 60.451865990954815)))
    (calmar_ratio
     ((mean 0.72190172239545525) (stdev 1.1498591534010032)
      (min -0.91999618334122424) (max 4.0426810406361806)))
    (cagr_pct
     ((mean 10.053685673915494) (stdev 23.342105576282151)
      (min -26.744403044050415) (max 56.191080996928555)))
    (avg_holding_days
     ((mean 34.668114245756541) (stdev 10.978923520612817) (min 11.8)
      (max 53.365384615384613))))))
 (sensitivity
  (((variant_label force_exit_off) (sharpe_wins 0) (calmar_wins 0)
    (total_return_wins 1) (max_drawdown_wins 1))))
 (verdicts
  ((force_exit_off
    (Fail (wins 0) (n 15) (worst_fold fold-007)
     (worst_gap 0.31346433454524714)
     (reason
      "M-threshold miss: 0 wins < 8 required; worst fold fold-007 trails by 0.3135 > \206\148=0.3000"))))))
