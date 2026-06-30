((fold_count 13) (baseline_label baseline) (metric_label Sharpe)
 (stability
  (((variant_label baseline)
    (total_return_pct
     ((mean 17.798052284395609) (stdev 16.716432536380243)
      (min -9.4162241299999749) (max 51.07539437714285)))
    (sharpe_ratio
     ((mean 0.66675175430201794) (stdev 0.54441942672344334)
      (min -0.24247811261864907) (max 1.6092434677920098)))
    (max_drawdown_pct
     ((mean 14.787006436711486) (stdev 6.6439352837303858)
      (min 7.5812024793102433) (max 30.197359267951597)))
    (calmar_ratio
     ((mean 0.850163185930088) (stdev 0.94466490991239527)
      (min -0.16008597323580842) (max 3.0291919944890515)))
    (cagr_pct
     ((mean 8.292776101731361) (stdev 7.6397188158662717)
      (min -4.82771397936379) (max 22.930100319022205)))
    (avg_holding_days
     ((mean 40.181468929617125) (stdev 7.6807528403611958)
      (min 29.089285714285715) (max 55.547945205479451))))
   ((variant_label earliness_ranking)
    (total_return_pct
     ((mean 17.198570440329675) (stdev 14.144166575727148)
      (min 0.54553856000003875) (max 53.807451639999982)))
    (sharpe_ratio
     ((mean 0.64889529334104057) (stdev 0.37377161946421533)
      (min 0.10714595776033671) (max 1.3689279151145934)))
    (max_drawdown_pct
     ((mean 14.981729631407857) (stdev 6.1158279752058338)
      (min 7.0170041118525708) (max 26.539210120126821)))
    (calmar_ratio
     ((mean 0.65682429031240752) (stdev 0.49512473329467366)
      (min 0.010990283496962029) (max 1.5978195945055584)))
    (cagr_pct
     ((mean 8.0945201371676614) (stdev 6.3103350161564977)
      (min 0.27258510411405368) (max 24.037419255714831)))
    (avg_holding_days
     ((mean 40.085346152254779) (stdev 6.2702243930762025)
      (min 29.517241379310345) (max 48.95945945945946))))))
 (sensitivity
  (((variant_label earliness_ranking) (sharpe_wins 9) (calmar_wins 8)
    (total_return_wins 8) (max_drawdown_wins 5))))
 (verdicts
  ((earliness_ranking
    (Fail (wins 9) (n 13) (worst_fold fold-002)
     (worst_gap 1.1177704667487478)
     (reason
      "\206\148-threshold miss: fold fold-002 trails by 1.1178 > \206\148=0.3000"))))))
