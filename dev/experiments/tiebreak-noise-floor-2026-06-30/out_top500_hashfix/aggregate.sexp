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
   ((variant_label hash_random)
    (total_return_pct
     ((mean 16.3318803732967) (stdev 13.072564823368207)
      (min -2.7065191000000106) (max 40.027798200000056)))
    (sharpe_ratio
     ((mean 0.63977643524544148) (stdev 0.46955186578506619)
      (min 0.00782214098699721) (max 1.6382599091487775)))
    (max_drawdown_pct
     ((mean 14.517049526120205) (stdev 6.44605525490343)
      (min 7.0400834058705026) (max 30.59909802000001)))
    (calmar_ratio
     ((mean 0.76164732492983844) (stdev 0.82556124323839086)
      (min -0.044619828753247652) (max 2.6099599985795714)))
    (cagr_pct
     ((mean 7.7084893071050136) (stdev 6.00811093422186)
      (min -1.3634690123024762) (max 18.34698637161798)))
    (avg_holding_days
     ((mean 40.363213047752183) (stdev 7.16808120192223)
      (min 29.9618320610687) (max 53.61038961038961))))))
 (sensitivity
  (((variant_label hash_random) (sharpe_wins 7) (calmar_wins 8)
    (total_return_wins 8) (max_drawdown_wins 9))))
 (verdicts
  ((hash_random
    (Fail (wins 7) (n 13) (worst_fold fold-002)
     (worst_gap 1.3479673244415808)
     (reason
      "\206\148-threshold miss: fold fold-002 trails by 1.3480 > \206\148=0.3000"))))))
