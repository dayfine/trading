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
   ((variant_label quality_ranking)
    (total_return_pct
     ((mean 16.851675122307707) (stdev 16.153714077528981)
      (min -5.316282879999978) (max 47.047540150000017)))
    (sharpe_ratio
     ((mean 0.63553841917549425) (stdev 0.47840050680757967)
      (min -0.053091877833188653) (max 1.5676256330375771)))
    (max_drawdown_pct
     ((mean 15.171222176815844) (stdev 6.2391812342355184)
      (min 8.8553651125857868) (max 29.913231519925642)))
    (calmar_ratio
     ((mean 0.67606621658949306) (stdev 0.6843676899680291)
      (min -0.10995982398966606) (max 2.0869505412166145)))
    (cagr_pct
     ((mean 7.87517311119481) (stdev 7.3177022677791124)
      (min -2.6962619168282353) (max 21.279174019657667)))
    (avg_holding_days
     ((mean 40.405223525105413) (stdev 8.0110032142524634)
      (min 30.728571428571428) (max 54))))))
 (sensitivity
  (((variant_label quality_ranking) (sharpe_wins 9) (calmar_wins 8)
    (total_return_wins 8) (max_drawdown_wins 5))))
 (verdicts
  ((quality_ranking
    (Fail (wins 9) (n 13) (worst_fold fold-006)
     (worst_gap 0.73242517853770261)
     (reason
      "\206\148-threshold miss: fold fold-006 trails by 0.7324 > \206\148=0.3000"))))))
