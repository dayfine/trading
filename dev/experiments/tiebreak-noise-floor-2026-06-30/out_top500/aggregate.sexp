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
   ((variant_label reverse_alpha)
    (total_return_pct
     ((mean 15.075765591538461) (stdev 11.220172102238651)
      (min 0.93729728000001045) (max 39.97888028000002)))
    (sharpe_ratio
     ((mean 0.60863037821862609) (stdev 0.42337615082840585)
      (min 0.10218177426808452) (max 1.5480728818666398)))
    (max_drawdown_pct
     ((mean 15.235611885013538) (stdev 6.2219405789167377)
      (min 6.37945121209519) (max 26.484015814232798)))
    (calmar_ratio
     ((mean 0.661293331831743) (stdev 0.67822548868667876)
      (min 0.024070556885404892) (max 2.5064629666466871)))
    (cagr_pct
     ((mean 7.16389444256477) (stdev 5.1641581441019255)
      (min 0.46787659037799134) (max 18.326298481591998)))
    (avg_holding_days
     ((mean 39.355666270798523) (stdev 8.6750330106689972)
      (min 25.271186440677965) (max 53.93150684931507))))
   ((variant_label symbol_length)
    (total_return_pct
     ((mean 18.270350691538457) (stdev 15.297734055624929)
      (min -1.25805485000005) (max 45.947475349999969)))
    (sharpe_ratio
     ((mean 0.6816266117614197) (stdev 0.51832099713669189)
      (min 0.02303313482731802) (max 1.514837871177382)))
    (max_drawdown_pct
     ((mean 16.205579413102718) (stdev 4.9730717458113762)
      (min 8.8122564875340625) (max 23.905029990000035)))
    (calmar_ratio
     ((mean 0.67635502407710757) (stdev 0.65656156912037889)
      (min -0.026451028259248166) (max 1.7787965537735557)))
    (cagr_pct
     ((mean 8.5503605046750035) (stdev 7.003488559994608)
      (min -0.63144918265416461) (max 20.824366045777488)))
    (avg_holding_days
     ((mean 41.200143432379328) (stdev 7.7610126952409884)
      (min 30.83969465648855) (max 53.088235294117645))))
   ((variant_label hash_random)
    (total_return_pct
     ((mean 18.270350691538457) (stdev 15.297734055624929)
      (min -1.25805485000005) (max 45.947475349999969)))
    (sharpe_ratio
     ((mean 0.6816266117614197) (stdev 0.51832099713669189)
      (min 0.02303313482731802) (max 1.514837871177382)))
    (max_drawdown_pct
     ((mean 16.205579413102718) (stdev 4.9730717458113762)
      (min 8.8122564875340625) (max 23.905029990000035)))
    (calmar_ratio
     ((mean 0.67635502407710757) (stdev 0.65656156912037889)
      (min -0.026451028259248166) (max 1.7787965537735557)))
    (cagr_pct
     ((mean 8.5503605046750035) (stdev 7.003488559994608)
      (min -0.63144918265416461) (max 20.824366045777488)))
    (avg_holding_days
     ((mean 41.200143432379328) (stdev 7.7610126952409884)
      (min 30.83969465648855) (max 53.088235294117645))))))
 (sensitivity
  (((variant_label reverse_alpha) (sharpe_wins 7) (calmar_wins 7)
    (total_return_wins 7) (max_drawdown_wins 5))
   ((variant_label symbol_length) (sharpe_wins 6) (calmar_wins 5)
    (total_return_wins 6) (max_drawdown_wins 2))
   ((variant_label hash_random) (sharpe_wins 6) (calmar_wins 5)
    (total_return_wins 6) (max_drawdown_wins 2))))
 (verdicts
  ((reverse_alpha
    (Fail (wins 7) (n 13) (worst_fold fold-002)
     (worst_gap 1.3890311886890525)
     (reason
      "\206\148-threshold miss: fold fold-002 trails by 1.3890 > \206\148=0.3000")))
   (symbol_length
    (Fail (wins 6) (n 13) (worst_fold fold-000)
     (worst_gap 0.33864356919277783)
     (reason
      "M-threshold miss: 6 wins < 7 required; worst fold fold-000 trails by 0.3386 > \206\148=0.3000")))
   (hash_random
    (Fail (wins 6) (n 13) (worst_fold fold-000)
     (worst_gap 0.33864356919277783)
     (reason
      "M-threshold miss: 6 wins < 7 required; worst fold fold-000 trails by 0.3386 > \206\148=0.3000"))))))
